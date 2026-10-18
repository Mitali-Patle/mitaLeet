import {
  Injectable,
  UnauthorizedException,
  NotFoundException,
  Logger,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { createHash, createPublicKey, createVerify, randomBytes } from 'crypto';
import { v4 as uuid } from 'uuid';
import { PrismaService } from '../prisma/prisma.service';
import { JwtPayload, TokenPair } from './types';
import { GoogleAuthDto, RefreshTokenDto } from './dto/auth.dto';

// ── Cert URLs ─────────────────────────────────────────────────────────────────
// Fetched directly (not via google-auth-library / firebase-admin, whose caches
// returned empty results on some hosts) and cached per Cache-Control max-age.
const CERT_FETCH_TIMEOUT_MS = 5_000;
const CERT_DEFAULT_TTL_MS = 60 * 60_000;
const FIREBASE_CERT_URL =
  'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
const GOOGLE_CERT_URL =
  'https://www.googleapis.com/oauth2/v3/certs';

interface FirebasePayload {
  iss: string; aud: string; sub: string; user_id: string;
  email?: string; email_verified?: boolean; name?: string; picture?: string;
  exp: number; iat: number; auth_time: number;
  firebase?: { identities?: { 'google.com'?: string[] }; sign_in_provider?: string };
}

interface GooglePayload {
  iss: string; aud: string; sub: string;
  email?: string; email_verified?: boolean | string; name?: string; picture?: string;
  exp: number; iat: number;
}

interface JwkKey { kty: string; kid: string; n: string; e: string; alg: string; use: string }

@Injectable()
export class AuthService implements OnModuleInit {
  private readonly logger = new Logger(AuthService.name);
  private readonly certCache = new Map<string, { body: unknown; expiresAt: number }>();

  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private config: ConfigService,
  ) {}

  onModuleInit() {
    // This log line proves v3 of auth.service is deployed.
    this.logger.log('AuthService v3 — manual cert verification active (no firebase-admin / google-auth-library for token checks)');
  }

  /**
   * Authenticate with a Google or Firebase ID token.
   *
   * Web  → Firebase ID token  (iss: securetoken.google.com)  → verifyFirebaseIdToken()
   * Mobile → Google ID token  (iss: accounts.google.com)      → verifyGoogleIdToken()
   *
   * Both paths do a fresh HTTPS fetch to Google's public cert endpoints on every
   * request — this bypasses the cert-cache in firebase-admin and google-auth-library
   * that returns empty results on some cloud hosts.
   */
  async googleAuth(dto: GoogleAuthDto): Promise<{
    tokens: TokenPair;
    user: { id: string; email: string; displayName: string; isNewUser: boolean };
  }> {
    let email: string;
    let name: string | undefined;
    let picture: string | undefined;
    let googleId: string;

    // Decode issuer (no crypto — full verification happens in the helpers below).
    let rawIss: string | undefined;
    try {
      const rawPayload = dto.idToken.split('.')[1];
      const jwtPayload = JSON.parse(Buffer.from(rawPayload, 'base64').toString('utf8'));
      rawIss = jwtPayload.iss as string | undefined;
    } catch {
      throw new UnauthorizedException('Malformed ID token');
    }

    const isFirebaseToken = rawIss?.startsWith('https://securetoken.google.com/');
    this.logger.log(`[googleAuth] iss=${rawIss} → path=${isFirebaseToken ? 'firebase' : 'google'}`);

    if (isFirebaseToken) {
      // ── Web path ──────────────────────────────────────────────────────────
      const projectId = this.config.getOrThrow<string>('FIREBASE_PROJECT_ID');
      const decoded = await this.verifyFirebaseIdToken(dto.idToken, projectId);

      if (!decoded.email) throw new UnauthorizedException('Firebase token has no email claim');
      if (decoded.email_verified !== true) throw new UnauthorizedException('Email address is not verified');
      if (decoded.firebase?.sign_in_provider !== 'google.com') {
        throw new UnauthorizedException('Only Google sign-in is supported');
      }

      const googleIds = decoded.firebase?.identities?.['google.com'] ?? [];
      googleId = googleIds[0] ?? decoded.sub;
      email    = decoded.email;
      name     = decoded.name;
      picture  = decoded.picture;
    } else {
      // ── Mobile path ───────────────────────────────────────────────────────
      const clientId = this.config.getOrThrow<string>('GOOGLE_CLIENT_ID');
      const decoded  = await this.verifyGoogleIdToken(dto.idToken, clientId);

      if (!decoded.email) throw new UnauthorizedException('Google token has no email claim');
      if (decoded.email_verified !== true && decoded.email_verified !== 'true') {
        throw new UnauthorizedException('Email address is not verified');
      }

      email    = decoded.email;
      name     = decoded.name;
      picture  = decoded.picture;
      googleId = decoded.sub;
    }

    // ── Find or create user ──────────────────────────────────────────────────
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
          profile: { create: { username: email.split('@')[0] + '_' + uuid().slice(0, 4) } },
          streak:  { create: {} },
        },
      });
      this.logger.log(`New user created: ${user.id}`);
    }

    const tokens = await this.createSession(user.id, user.email);
    return {
      tokens,
      user: { id: user.id, email: user.email, displayName: user.displayName, isNewUser },
    };
  }

  // ── Token verifiers ────────────────────────────────────────────────────────

  /**
   * Verify a Firebase ID token.
   * Fetches PEM certs from Google, verifies RSA-SHA256 signature, checks claims.
   */
  private async verifyFirebaseIdToken(
    idToken: string,
    projectId: string,
  ): Promise<FirebasePayload> {
    const { header, payload, signingInput, signature } = this.decodeJwt<FirebasePayload>(idToken);

    // PEM certs (map of kid → PEM string); refetch once if the kid is new (key rotation).
    let certs = await this.fetchCerts<Record<string, string>>(FIREBASE_CERT_URL, 'Firebase');
    if (!certs[header.kid]) {
      certs = await this.fetchCerts<Record<string, string>>(FIREBASE_CERT_URL, 'Firebase', true);
    }

    const cert = certs[header.kid];
    if (!cert) {
      this.logger.error(`Firebase: no cert for kid=${header.kid}, available=${Object.keys(certs).join(',')}`);
      throw new UnauthorizedException('Firebase token key not found in Google cert set');
    }

    // Verify RSA-SHA256 signature.
    const verifier = createVerify('RSA-SHA256');
    verifier.update(signingInput);
    if (!verifier.verify(cert, signature)) {
      throw new UnauthorizedException('Firebase token signature invalid');
    }

    // Verify standard claims.
    const now = Math.floor(Date.now() / 1000);
    if (!payload.exp || payload.exp <= now)   throw new UnauthorizedException('Firebase token expired');
    if (!payload.iat || payload.iat > now + 300) throw new UnauthorizedException('Firebase token iat in future');
    if (payload.aud !== projectId)             throw new UnauthorizedException(`Firebase token aud mismatch: ${payload.aud}`);
    if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
      throw new UnauthorizedException(`Firebase token iss mismatch: ${payload.iss}`);
    }
    if (!payload.sub) throw new UnauthorizedException('Firebase token missing sub');

    return payload;
  }

  /**
   * Verify a Google ID token (mobile / native).
   * Fetches JWK certs from Google, imports RSA public key, verifies signature & claims.
   */
  private async verifyGoogleIdToken(
    idToken: string,
    clientId: string,
  ): Promise<GooglePayload> {
    const { header, payload, signingInput, signature } = this.decodeJwt<GooglePayload>(idToken);

    // JWK set; refetch once if the kid is new (key rotation).
    let jwks = await this.fetchCerts<{ keys: JwkKey[] }>(GOOGLE_CERT_URL, 'Google');
    if (!jwks.keys?.some((k) => k.kid === header.kid)) {
      jwks = await this.fetchCerts<{ keys: JwkKey[] }>(GOOGLE_CERT_URL, 'Google', true);
    }

    const jwk = jwks.keys?.find(k => k.kid === header.kid);
    if (!jwk) {
      this.logger.error(`Google: no JWK for kid=${header.kid}, available=${jwks.keys?.map(k => k.kid).join(',')}`);
      throw new UnauthorizedException('Google token key not found in Google cert set');
    }

    // Import JWK → RSA public key, then verify.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const publicKey = createPublicKey({ key: jwk as any, format: 'jwk' });
    const verifier  = createVerify('RSA-SHA256');
    verifier.update(signingInput);
    if (!verifier.verify(publicKey, signature)) {
      throw new UnauthorizedException('Google token signature invalid');
    }

    // Verify claims.
    const now = Math.floor(Date.now() / 1000);
    if (!payload.exp || payload.exp <= now) throw new UnauthorizedException('Google token expired');
    if (payload.aud !== clientId)           throw new UnauthorizedException(`Google token aud mismatch: ${payload.aud}`);
    const validIssuers = ['accounts.google.com', 'https://accounts.google.com'];
    if (!validIssuers.includes(payload.iss)) {
      throw new UnauthorizedException(`Google token iss invalid: ${payload.iss}`);
    }
    if (!payload.sub) throw new UnauthorizedException('Google token missing sub');

    return payload;
  }

  /** Decode and split a JWT into its parts without verifying. */
  private decodeJwt<P>(idToken: string): {
    header: { alg: string; kid: string };
    payload: P;
    signingInput: string;
    signature: Buffer;
  } {
    const parts = idToken.split('.');
    if (parts.length !== 3) throw new UnauthorizedException('Malformed JWT — expected 3 parts');

    let header: { alg: string; kid: string };
    try {
      header = JSON.parse(Buffer.from(parts[0], 'base64url').toString('utf8'));
    } catch {
      throw new UnauthorizedException('JWT parts are not valid base64url JSON');
    }
    // Only RS256 is valid for Google/Firebase ID tokens; reject anything else up front.
    if (header?.alg !== 'RS256' || typeof header.kid !== 'string') {
      throw new UnauthorizedException('Unsupported ID token algorithm');
    }

    try {
      return {
        header,
        payload:      JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8')) as P,
        signingInput: `${parts[0]}.${parts[1]}`,
        signature:    Buffer.from(parts[2], 'base64url'),
      };
    } catch {
      throw new UnauthorizedException('JWT parts are not valid base64url JSON');
    }
  }

  /** Fetch a Google cert document, cached for its Cache-Control max-age. */
  private async fetchCerts<T>(url: string, label: string, force = false): Promise<T> {
    const cached = this.certCache.get(url);
    if (!force && cached && cached.expiresAt > Date.now()) return cached.body as T;

    try {
      const res = await fetch(url, {
        headers: { Accept: 'application/json' },
        signal: AbortSignal.timeout(CERT_FETCH_TIMEOUT_MS),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const body = await res.json();
      if (!body || Object.keys(body).length === 0) throw new Error('empty cert response');

      const maxAge = /max-age=(\d+)/.exec(res.headers.get('cache-control') ?? '');
      const ttl = maxAge ? Number(maxAge[1]) * 1000 : CERT_DEFAULT_TTL_MS;
      this.certCache.set(url, { body, expiresAt: Date.now() + ttl });
      return body as T;
    } catch (err) {
      this.logger.error(`${label} cert fetch failed: ${(err as Error).message}`);
      if (cached) return cached.body as T; // stale but still Google's keys
      throw new UnauthorizedException(`Could not fetch ${label} public certs`);
    }
  }

  // ── Public auth methods ────────────────────────────────────────────────────

  /**
   * Rotate a refresh token. The old token is consumed atomically, so concurrent
   * refreshes with the same token yield one new pair and 401s (not 500s).
   */
  async refresh(dto: RefreshTokenDto): Promise<TokenPair> {
    const session = await this.findSessionByRefreshToken(dto.refreshToken);
    if (!session) throw new UnauthorizedException('Invalid or expired refresh token');

    const consumed = await this.prisma.userSession.deleteMany({ where: { id: session.id } });
    if (consumed.count === 0 || session.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }
    return this.createSession(session.userId, session.user.email);
  }

  /** End the current session: its access token and refresh token stop working. */
  async logout(userId: string, sessionId: string, refreshToken: string): Promise<void> {
    await this.prisma.userSession.deleteMany({
      where: {
        userId,
        OR: [
          { id: sessionId },
          { refreshToken: this.hashToken(refreshToken) },
          { refreshToken }, // legacy plaintext rows
        ],
      },
    });
  }

  /** True while the session behind an access token has not been logged out or rotated away. */
  async isSessionActive(sessionId: string | undefined): Promise<boolean> {
    if (!sessionId) return false;
    const session = await this.prisma.userSession.findUnique({
      where: { id: sessionId },
      select: { expiresAt: true },
    });
    return !!session && session.expiresAt > new Date();
  }

  async logoutAll(userId: string): Promise<void> {
    await this.prisma.userSession.deleteMany({ where: { userId } });
  }

  /** Dev login is off unless explicitly enabled, and never available in production. */
  isDevLoginEnabled(): boolean {
    return (
      this.config.get<string>('ENABLE_DEV_LOGIN') === 'true' &&
      this.config.get<string>('NODE_ENV') !== 'production'
    );
  }

  async devLogin(username: string): Promise<{
    tokens: TokenPair;
    user: { id: string; email: string; displayName: string; isNewUser: boolean };
  }> {
    if (!this.isDevLoginEnabled()) {
      throw new NotFoundException();
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
      user: { id: user.id, email: user.email, displayName: user.displayName, isNewUser },
    };
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  private async createSession(userId: string, email: string): Promise<TokenPair> {
    const sessionId = uuid();

    const refreshExpiresIn = this.config.get<string>('JWT_REFRESH_EXPIRES_IN', '30d');
    const dayMatch         = refreshExpiresIn.match(/^(\d+)d$/);
    const refreshExpDays   = dayMatch ? parseInt(dayMatch[1], 10) : (parseInt(refreshExpiresIn, 10) || 30);

    // Only a SHA-256 hash is stored, so a database leak does not leak usable tokens.
    const refreshToken = randomBytes(32).toString('base64url');
    await this.prisma.userSession.create({
      data: {
        id: sessionId,
        refreshToken: this.hashToken(refreshToken),
        userId,
        expiresAt: new Date(Date.now() + refreshExpDays * 24 * 60 * 60 * 1000),
      },
    });

    const accessToken = await this.jwtService.signAsync({ sub: userId, email, sessionId } as JwtPayload);
    return { accessToken, refreshToken };
  }

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  /** Looks up by hash; falls back to legacy plaintext rows (rotating one stores a hash). */
  private async findSessionByRefreshToken(refreshToken: string) {
    const hashed = await this.prisma.userSession.findUnique({
      where: { refreshToken: this.hashToken(refreshToken) },
      include: { user: true },
    });
    if (hashed) return hashed;
    return this.prisma.userSession.findUnique({
      where: { refreshToken },
      include: { user: true },
    });
  }
}
