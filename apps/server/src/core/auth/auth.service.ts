import {
  Injectable,
  UnauthorizedException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { OAuth2Client, LoginTicket } from 'google-auth-library';
import { createVerify } from 'crypto';
import { v4 as uuid } from 'uuid';
import { PrismaService } from '../prisma/prisma.service';
import { JwtPayload, TokenPair } from './types';
import { GoogleAuthDto, RefreshTokenDto } from './dto/auth.dto';

// Shape of the Firebase ID token payload we care about.
interface FirebaseTokenPayload {
  iss: string;
  aud: string;
  sub: string;
  user_id: string;
  email?: string;
  name?: string;
  picture?: string;
  exp: number;
  iat: number;
  auth_time: number;
  firebase?: {
    identities?: { 'google.com'?: string[] };
    sign_in_provider?: string;
  };
}

const FIREBASE_CERT_URL =
  'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly googleClient: OAuth2Client;

  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private config: ConfigService,
  ) {
    this.googleClient = new OAuth2Client(
      config.getOrThrow<string>('GOOGLE_CLIENT_ID'),
    );
  }

  /**
   * Authenticate with a Google or Firebase ID token.
   *
   * Mobile (Android/iOS) sends a raw Google ID token verified by google-auth-library.
   * Web sends a Firebase ID token (iss: securetoken.google.com) verified by
   * a manual RSA-SHA256 check against Google's public certs — bypassing the
   * Firebase Admin SDK which has known cert-cache issues on some cloud hosts.
   *
   * Token type is auto-detected by the `iss` claim — no extra fields needed.
   */
  async googleAuth(dto: GoogleAuthDto): Promise<{
    tokens: TokenPair;
    user: { id: string; email: string; displayName: string; isNewUser: boolean };
  }> {
    let email: string;
    let name: string | undefined;
    let picture: string | undefined;
    let googleId: string;

    // Decode issuer from the JWT payload (no crypto needed — we verify next).
    const rawPayload = dto.idToken.split('.')[1];
    const jwtPayload = JSON.parse(
      Buffer.from(rawPayload, 'base64').toString('utf8'),
    );
    const isFirebaseToken = (jwtPayload.iss as string | undefined)
      ?.startsWith('https://securetoken.google.com/');

    if (isFirebaseToken) {
      // ── Web path: Firebase ID token ──────────────────────────────────────
      // Use manual RSA-SHA256 verification instead of firebase-admin.verifyIdToken,
      // which has a known "No pem found" cert-cache failure on some hosting envs.
      const projectId = this.config.getOrThrow<string>('FIREBASE_PROJECT_ID');
      const decoded = await this.verifyFirebaseIdToken(dto.idToken, projectId);

      if (!decoded.email) throw new UnauthorizedException('Firebase token has no email claim');

      const googleIds = decoded.firebase?.identities?.['google.com'] ?? [];
      googleId = googleIds[0] ?? decoded.sub;
      email    = decoded.email;
      name     = decoded.name;
      picture  = decoded.picture;
    } else {
      // ── Mobile path: raw Google ID token ─────────────────────────────────
      let ticket: LoginTicket;
      try {
        ticket = await this.googleClient.verifyIdToken({
          idToken: dto.idToken,
          audience: this.config.getOrThrow<string>('GOOGLE_CLIENT_ID'),
        });
      } catch (err) {
        this.logger.error(`Google verifyIdToken failed: ${(err as Error).message}`);
        throw new UnauthorizedException(
          `Google token verification failed: ${(err as Error).message}`,
        );
      }
      const payload = ticket.getPayload();
      if (!payload?.email) {
        throw new UnauthorizedException('Google token has no email payload');
      }
      email    = payload.email;
      name     = payload.name;
      picture  = payload.picture;
      googleId = payload.sub;
    }

    // Find or create user
    let isNewUser = false;
    let user = await this.prisma.user.findUnique({ where: { googleId } });

    if (!user) {
      isNewUser = true;
      user = await this.prisma.user.create({
        data: {
          email,
          displayName: name || email.split('@')[0],
          avatarUrl: picture,
          googleId,
          profile: {
            create: {
              username: email.split('@')[0] + '_' + uuid().slice(0, 4),
            },
          },
          streak: { create: {} },
        },
      });
      this.logger.log(`New user created: ${user.id}`);
    }

    const tokens = await this.createSession(user.id, user.email);

    return {
      tokens,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        isNewUser,
      },
    };
  }

  /**
   * Verify a Firebase ID token using manual RSA-SHA256 verification.
   *
   * Fetches Google's public certs directly — same approach Firebase Admin uses
   * internally, but without the SDK's cert-cache layer that fails on some hosts.
   */
  private async verifyFirebaseIdToken(
    idToken: string,
    projectId: string,
  ): Promise<FirebaseTokenPayload> {
    const parts = idToken.split('.');
    if (parts.length !== 3) {
      throw new UnauthorizedException('Malformed Firebase ID token');
    }

    // Decode header to get the key ID.
    let header: { alg: string; kid: string };
    let payload: FirebaseTokenPayload;
    try {
      header  = JSON.parse(Buffer.from(parts[0], 'base64url').toString('utf8'));
      payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
    } catch {
      throw new UnauthorizedException('Firebase token is not valid JSON');
    }

    if (header.alg !== 'RS256') {
      throw new UnauthorizedException(`Unsupported Firebase token algorithm: ${header.alg}`);
    }

    // Fetch Google's current Firebase signing certs.
    let certs: Record<string, string>;
    try {
      const res = await fetch(FIREBASE_CERT_URL, {
        headers: { Accept: 'application/json' },
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      certs = (await res.json()) as Record<string, string>;
    } catch (err) {
      this.logger.error(`Failed to fetch Firebase certs: ${(err as Error).message}`);
      throw new UnauthorizedException('Could not fetch Firebase public certs');
    }

    const cert = certs[header.kid];
    if (!cert) {
      const availableKids = Object.keys(certs).join(', ');
      this.logger.error(
        `Firebase cert not found for kid=${header.kid}. Available kids: ${availableKids}`,
      );
      throw new UnauthorizedException(
        `Firebase token key ID not found in Google's current cert set`,
      );
    }

    // Verify the JWT signature.
    const signingInput = `${parts[0]}.${parts[1]}`;
    const signature    = Buffer.from(parts[2], 'base64url');
    const verifier     = createVerify('RSA-SHA256');
    verifier.update(signingInput);
    const sigValid = verifier.verify(cert, signature);
    if (!sigValid) {
      throw new UnauthorizedException('Firebase token signature is invalid');
    }

    // Verify standard JWT claims.
    const now = Math.floor(Date.now() / 1000);
    if (!payload.exp || payload.exp <= now) {
      throw new UnauthorizedException('Firebase token has expired');
    }
    if (!payload.iat || payload.iat > now + 300) {
      throw new UnauthorizedException('Firebase token iat is in the future');
    }
    if (payload.aud !== projectId) {
      throw new UnauthorizedException(
        `Firebase token audience mismatch: expected ${projectId}, got ${payload.aud}`,
      );
    }
    if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
      throw new UnauthorizedException(
        `Firebase token issuer mismatch: ${payload.iss}`,
      );
    }
    if (!payload.sub) {
      throw new UnauthorizedException('Firebase token missing sub claim');
    }

    return payload;
  }

  /**
   * Refresh access token using a valid refresh token.
   */
  async refresh(dto: RefreshTokenDto): Promise<TokenPair> {
    const session = await this.prisma.userSession.findUnique({
      where: { refreshToken: dto.refreshToken },
      include: { user: true },
    });

    if (!session || session.expiresAt < new Date()) {
      if (session) {
        await this.prisma.userSession.delete({ where: { id: session.id } });
      }
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    await this.prisma.userSession.delete({ where: { id: session.id } });
    return this.createSession(session.userId, session.user.email);
  }

  /**
   * Logout — invalidate session.
   */
  async logout(refreshToken: string): Promise<void> {
    await this.prisma.userSession.deleteMany({ where: { refreshToken } });
  }

  /**
   * Logout from all devices.
   */
  async logoutAll(userId: string): Promise<void> {
    await this.prisma.userSession.deleteMany({ where: { userId } });
  }

  /**
   * Dev login — bypass Google OAuth in development.
   */
  async devLogin(username: string): Promise<{
    tokens: TokenPair;
    user: { id: string; email: string; displayName: string; isNewUser: boolean };
  }> {
    if (this.config.get<string>('NODE_ENV') === 'production') {
      throw new UnauthorizedException('Dev login not allowed in production');
    }

    const cleanUsername = username.trim().toLowerCase();
    const googleId = `google-${cleanUsername}`;

    let isNewUser = false;
    let user = await this.prisma.user.findUnique({ where: { googleId } });

    if (!user) {
      isNewUser = true;
      user = await this.prisma.user.create({
        data: {
          email: `${cleanUsername}@example.com`,
          displayName: cleanUsername,
          googleId,
          profile: { create: { username: cleanUsername } },
          streak:  { create: {} },
        },
      });
      this.logger.log(`New dev user created: ${user.id}`);
    }

    const tokens = await this.createSession(user.id, user.email);

    return {
      tokens,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        isNewUser,
      },
    };
  }

  // ── Private helpers ────────────────────────────────────────────────

  private async createSession(userId: string, email: string): Promise<TokenPair> {
    const sessionId = uuid();

    const refreshExpiresIn = this.config.get<string>('JWT_REFRESH_EXPIRES_IN', '30d');
    const dayMatch = refreshExpiresIn.match(/^(\d+)d$/);
    const refreshExpDays = dayMatch
      ? parseInt(dayMatch[1], 10)
      : (parseInt(refreshExpiresIn, 10) || 30);

    const session = await this.prisma.userSession.create({
      data: {
        id: sessionId,
        refreshToken: uuid(),
        userId,
        expiresAt: new Date(Date.now() + refreshExpDays * 24 * 60 * 60 * 1000),
      },
    });

    const jwtPayload: JwtPayload = { sub: userId, email, sessionId };

    const accessToken = await this.jwtService.signAsync(jwtPayload);

    return { accessToken, refreshToken: session.refreshToken };
  }
}
