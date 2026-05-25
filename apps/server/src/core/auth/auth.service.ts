import {
  Injectable,
  UnauthorizedException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { OAuth2Client } from 'google-auth-library';
import { v4 as uuid } from 'uuid';
import { PrismaService } from '../prisma/prisma.service';
import { JwtPayload, TokenPair } from './types';
import { GoogleAuthDto, RefreshTokenDto } from './dto/auth.dto';

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
   * Authenticate with Google ID token.
   * Creates user if first login, otherwise returns existing user.
   */
  async googleAuth(dto: GoogleAuthDto): Promise<{
    tokens: TokenPair;
    user: { id: string; email: string; displayName: string; isNewUser: boolean };
  }> {
    // Verify Google token
    const ticket = await this.googleClient.verifyIdToken({
      idToken: dto.idToken,
      audience: this.config.getOrThrow<string>('GOOGLE_CLIENT_ID'),
    });
    const payload = ticket.getPayload();
    if (!payload || !payload.email) {
      throw new UnauthorizedException('Invalid Google token');
    }

    const { email, name, picture, sub: googleId } = payload;

    // Find or create user
    let isNewUser = false;
    let user = await this.prisma.user.findUnique({
      where: { googleId },
    });

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
          streak: {
            create: {},
          },
        },
      });
      this.logger.log(`New user created: ${user.id}`);
    }

    // Create session + tokens
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

    // Rotate refresh token
    await this.prisma.userSession.delete({ where: { id: session.id } });
    return this.createSession(session.userId, session.user.email);
  }

  /**
   * Logout — invalidate session.
   */
  async logout(refreshToken: string): Promise<void> {
    await this.prisma.userSession.deleteMany({
      where: { refreshToken },
    });
  }

  /**
   * Logout from all devices.
   */
  async logoutAll(userId: string): Promise<void> {
    await this.prisma.userSession.deleteMany({
      where: { userId },
    });
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
    let user = await this.prisma.user.findUnique({
      where: { googleId },
    });

    if (!user) {
      isNewUser = true;
      user = await this.prisma.user.create({
        data: {
          email: `${cleanUsername}@example.com`,
          displayName: cleanUsername,
          googleId,
          profile: {
            create: {
              username: cleanUsername,
            },
          },
          streak: {
            create: {},
          },
        },
      });
      this.logger.log(`New dev user created: ${user.id}`);
    }

    // Create session + tokens
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

  private async createSession(
    userId: string,
    email: string,
  ): Promise<TokenPair> {
    const sessionId = uuid();

    // Read refresh token TTL from config (e.g. "30d", "7d").
    // Parse the numeric day suffix; fall back to 30 days if missing or unparseable.
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
        expiresAt: new Date(
          Date.now() + refreshExpDays * 24 * 60 * 60 * 1000,
        ),
      },
    });

    const jwtPayload: JwtPayload = {
      sub: userId,
      email,
      sessionId,
    };

    // Let JwtModule.registerAsync (configured in auth.module.ts) handle expiry —
    // do not pass options here to avoid two sources of truth.
    const accessToken = await this.jwtService.signAsync(jwtPayload);

    return {
      accessToken,
      refreshToken: session.refreshToken,
    };
  }
}
