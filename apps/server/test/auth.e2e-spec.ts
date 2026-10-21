import { createSign, generateKeyPairSync, KeyObject } from 'crypto';
import { AddressInfo } from 'net';
import { io } from 'socket.io-client';
import { createTestApp, login, resetDb, TestContext } from './helpers';

/** Build a Google-style RS256 ID token signed with a locally generated key. */
function signIdToken(privateKey: KeyObject, kid: string, claims: Record<string, unknown>): string {
  const enc = (o: unknown) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const head = enc({ alg: 'RS256', kid, typ: 'JWT' });
  const body = enc(claims);
  const sig = createSign('RSA-SHA256').update(`${head}.${body}`).sign(privateKey).toString('base64url');
  return `${head}.${body}.${sig}`;
}

describe('Authentication lifecycle (e2e)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
    await resetDb(ctx.prisma);
  });

  afterAll(async () => {
    await ctx.app.close();
  });

  describe('sessions', () => {
    it('logout revokes the access token immediately', async () => {
      const u = await login(ctx, 'logout_user');
      await ctx.http().get('/api/v1/users/me').set(u.auth).expect(200);
      await ctx.http().post('/api/v1/auth/logout').set(u.auth).send({ refreshToken: u.refreshToken }).expect(200);
      await ctx.http().get('/api/v1/users/me').set(u.auth).expect(401);
      await ctx.http().post('/api/v1/auth/refresh').send({ refreshToken: u.refreshToken }).expect(401);
    });

    it('logout-all revokes every session of the user', async () => {
      const a = await login(ctx, 'many_devices');
      const b = await login(ctx, 'many_devices');
      await ctx.http().post('/api/v1/auth/logout-all').set(a.auth).expect(200);
      await ctx.http().get('/api/v1/users/me').set(a.auth).expect(401);
      await ctx.http().get('/api/v1/users/me').set(b.auth).expect(401);
    });

    it('refresh rotates: the new pair works, the old refresh token does not', async () => {
      const u = await login(ctx, 'rotator');
      const res = await ctx.http().post('/api/v1/auth/refresh').send({ refreshToken: u.refreshToken }).expect(200);
      const { accessToken, refreshToken } = res.body.data;
      await ctx.http().get('/api/v1/users/me').set({ Authorization: `Bearer ${accessToken}` }).expect(200);
      await ctx.http().post('/api/v1/auth/refresh').send({ refreshToken: u.refreshToken }).expect(401);
      // The access token of the rotated-away session is dead too.
      await ctx.http().get('/api/v1/users/me').set(u.auth).expect(401);
      expect(refreshToken).not.toBe(u.refreshToken);
    });

    it('concurrent refreshes with one token give exactly one new pair and no server errors', async () => {
      const u = await login(ctx, 'racer');
      const results = await Promise.all(
        [1, 2, 3, 4].map(() => ctx.http().post('/api/v1/auth/refresh').send({ refreshToken: u.refreshToken })),
      );
      const statuses = results.map((r) => r.status).sort();
      expect(statuses).toEqual([200, 401, 401, 401]);
    });

    it('refresh tokens are not stored in plaintext', async () => {
      const u = await login(ctx, 'hashed');
      const rows = await ctx.prisma.userSession.findMany({ where: { userId: u.id } });
      expect(rows.length).toBeGreaterThan(0);
      expect(rows.some((r) => r.refreshToken === u.refreshToken)).toBe(false);
    });

    it('legacy plaintext refresh tokens still work once, then come back hashed', async () => {
      const u = await login(ctx, 'legacy');
      await ctx.prisma.userSession.updateMany({ where: { userId: u.id }, data: { refreshToken: 'legacy-plain-token' } });
      const res = await ctx.http().post('/api/v1/auth/refresh').send({ refreshToken: 'legacy-plain-token' }).expect(200);
      const rows = await ctx.prisma.userSession.findMany({ where: { userId: u.id } });
      expect(rows.some((r) => r.refreshToken === res.body.data.refreshToken)).toBe(false);
    });

    it('a logged-out token cannot open a socket', async () => {
      const u = await login(ctx, 'socket_user');
      await ctx.http().post('/api/v1/auth/logout').set(u.auth).send({ refreshToken: u.refreshToken }).expect(200);
      await ctx.app.listen(0);
      const { port } = ctx.app.getHttpServer().address() as AddressInfo;
      const s = io(`http://127.0.0.1:${port}`, { transports: ['websocket'], auth: { token: u.accessToken }, forceNew: true, reconnection: false });
      const outcome = await new Promise<string>((resolve) => {
        s.on('disconnect', () => resolve('disconnected'));
        s.on('connect_error', () => resolve('rejected'));
        setTimeout(() => resolve('still-connected'), 2000);
      });
      s.disconnect();
      expect(outcome).not.toBe('still-connected');
    });
  });

  describe('dev login', () => {
    afterEach(() => { process.env.ENABLE_DEV_LOGIN = 'true'; process.env.NODE_ENV = 'test'; });

    it('is unavailable unless ENABLE_DEV_LOGIN=true', async () => {
      delete process.env.ENABLE_DEV_LOGIN;
      await ctx.http().post('/api/v1/auth/dev-login').send({ username: 'sneaky' }).expect(404);
    });

    it('is unavailable in production even if the flag is set', async () => {
      process.env.NODE_ENV = 'production';
      await ctx.http().post('/api/v1/auth/dev-login').send({ username: 'sneaky' }).expect(404);
    });

    it('validates the username', async () => {
      await ctx.http().post('/api/v1/auth/dev-login').send({ username: 'a b' }).expect(400);
      await ctx.http().post('/api/v1/auth/dev-login').send({}).expect(400);
    });
  });

  describe('Google ID token verification', () => {
    const kid = 'test-kid-1';
    const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
    const jwk = { ...publicKey.export({ format: 'jwk' }), kid, alg: 'RS256', use: 'sig' };
    let fetchSpy: jest.SpyInstance;
    const realFetch = global.fetch;

    beforeAll(() => {
      fetchSpy = jest.spyOn(global, 'fetch').mockImplementation(async (input, init) => {
        if (String(input).startsWith('https://www.googleapis.com/oauth2/v3/certs')) {
          return new Response(JSON.stringify({ keys: [jwk] }), {
            headers: { 'content-type': 'application/json', 'cache-control': 'public, max-age=3600' },
          });
        }
        return realFetch(input, init);
      });
    });
    afterAll(() => fetchSpy.mockRestore());

    const now = () => Math.floor(Date.now() / 1000);
    const claims = (over: Record<string, unknown> = {}) => ({
      iss: 'https://accounts.google.com', aud: process.env.GOOGLE_CLIENT_ID, sub: 'google-sub-123',
      email: 'real.user@gmail.com', email_verified: true, name: 'Real User',
      iat: now(), exp: now() + 3600, ...over,
    });
    const google = (token: string) => ctx.http().post('/api/v1/auth/google').send({ idToken: token });

    it('accepts a valid, verified Google token and creates the user', async () => {
      const res = await google(signIdToken(privateKey, kid, claims())).expect(200);
      expect(res.body.data.user.email).toBe('real.user@gmail.com');
      expect(res.body.data.tokens.accessToken).toBeDefined();
    });

    it.each([
      ['unverified email', { email_verified: false }],
      ['wrong audience', { aud: 'someone-elses-client-id' }],
      ['wrong issuer', { iss: 'https://evil.example.com' }],
      ['expired token', { exp: now() - 10 }],
    ])('rejects a token with %s', async (_label, over) => {
      await google(signIdToken(privateKey, kid, claims(over))).expect(401);
    });

    it('rejects a token signed by a different key', async () => {
      const other = generateKeyPairSync('rsa', { modulusLength: 2048 }).privateKey;
      await google(signIdToken(other, kid, claims())).expect(401);
    });

    it('rejects alg=none style tokens', async () => {
      const enc = (o: unknown) => Buffer.from(JSON.stringify(o)).toString('base64url');
      await google(`${enc({ alg: 'none', kid })}.${enc(claims())}.`).expect(401);
    });
  });
});
