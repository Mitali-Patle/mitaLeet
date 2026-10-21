import { createTestApp, linkLeetCode, login, resetDb, seedProblem, TestContext, TestUser } from './helpers';

describe('Browser-extension tokens (e2e)', () => {
  let ctx: TestContext;
  let u: TestUser;
  let token: string;
  const ext = () => ({ Authorization: `Bearer ${token}` });

  beforeAll(async () => {
    ctx = await createTestApp();
    await resetDb(ctx.prisma);
    await seedProblem(ctx.prisma, 'two-sum');
    u = await login(ctx, 'ext_user');
    await linkLeetCode(ctx, u, 'ext_lc');
    const res = await ctx.http().post('/api/v1/auth/extension-token').set(u.auth).expect(201);
    token = res.body.data.token;
    const days = (new Date(res.body.data.expiresAt).getTime() - Date.now()) / 86_400_000;
    expect(days).toBeGreaterThan(89);
  });

  afterAll(async () => {
    await ctx.app.close();
  });

  it('can do what the extension needs', async () => {
    await ctx.http().get('/api/v1/users/me').set(ext()).expect(200);
    await ctx.http().post('/api/v1/leetcode/sessions').set(ext())
      .send({ problemSlug: 'two-sum', language: 'python3', startedAt: new Date().toISOString() }).expect(201);
    ctx.leetcode.addSubmission('ext_lc', 'two-sum');
    const r = await ctx.http().post('/api/v1/leetcode/extension-solve').set(ext())
      .send({ problemSlug: 'two-sum', language: 'python3', durationMs: 1000, solvedAt: new Date().toISOString() }).expect(201);
    expect(r.body.data.verified).toBe(true);
  });

  it.each([
    ['PUT', '/api/v1/users/me/profile', { displayName: 'pwned' }],
    ['POST', '/api/v1/groups', { name: 'by extension' }],
    ['DELETE', '/api/v1/users/me', { confirm: 'DELETE' }],
    ['POST', '/api/v1/auth/extension-token', {}],
    ['GET', '/api/v1/friends', undefined],
  ])('cannot %s %s', async (method, path, body) => {
    const req = ctx.http()[method.toLowerCase() as 'get'](path).set(ext());
    await (body ? req.send(body) : req).expect(403);
  });

  it('issuing a new token revokes the previous one; revoke ends it', async () => {
    const old = token;
    token = (await ctx.http().post('/api/v1/auth/extension-token').set(u.auth).expect(201)).body.data.token;
    await ctx.http().get('/api/v1/users/me').set({ Authorization: `Bearer ${old}` }).expect(401);
    await ctx.http().get('/api/v1/users/me').set(ext()).expect(200);

    await ctx.http().delete('/api/v1/auth/extension-token').set(u.auth).expect(204);
    await ctx.http().get('/api/v1/users/me').set(ext()).expect(401);
  });

  it('logout-all also ends the extension token', async () => {
    token = (await ctx.http().post('/api/v1/auth/extension-token').set(u.auth).expect(201)).body.data.token;
    await ctx.http().post('/api/v1/auth/logout-all').set(u.auth).expect(200);
    await ctx.http().get('/api/v1/users/me').set(ext()).expect(401);
  });
});
