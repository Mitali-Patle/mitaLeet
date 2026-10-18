import { createTestApp, login, resetDb, TestContext } from './helpers';

describe('App baseline (e2e)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
    await resetDb(ctx.prisma);
  });

  afterAll(async () => {
    await ctx.app.close();
  });

  it('GET /health returns ok', async () => {
    const res = await ctx.http().get('/health').expect(200);
    expect(res.body.status).toBe('ok');
  });

  it('rejects unauthenticated requests to protected routes', async () => {
    const res = await ctx.http().get('/api/v1/users/me').expect(401);
    expect(res.body.success).toBe(false);
  });

  it('returns the current user for a valid access token', async () => {
    const alice = await login(ctx, 'alice');
    const res = await ctx.http().get('/api/v1/users/me').set(alice.auth).expect(200);
    expect(res.body.data.id).toBe(alice.id);
  });
});
