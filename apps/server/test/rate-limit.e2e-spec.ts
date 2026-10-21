import { createTestApp, linkLeetCode, login, resetDb, TestContext } from './helpers';

describe('Rate limiting (e2e)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
    await resetDb(ctx.prisma);
  });

  beforeEach(() => { process.env.THROTTLE_DISABLED = 'false'; });
  afterEach(() => { process.env.THROTTLE_DISABLED = 'true'; });

  afterAll(async () => {
    await ctx.app.close();
  });

  it('limits refresh-token guessing per IP', async () => {
    const statuses: number[] = [];
    for (let i = 0; i < 35; i++) {
      statuses.push((await ctx.http().post('/api/v1/auth/refresh').send({ refreshToken: `guess-${i}` })).status);
    }
    expect(statuses.filter((s) => s === 401).length).toBe(30);
    expect(statuses.slice(30).every((s) => s === 429)).toBe(true);
  });

  it('limits squad invite-code guessing per user', async () => {
    process.env.THROTTLE_DISABLED = 'true';
    const u = await login(ctx, 'code_guesser');
    process.env.THROTTLE_DISABLED = 'false';
    const statuses: number[] = [];
    for (let i = 0; i < 12; i++) {
      statuses.push((await ctx.http().post('/api/v1/groups/join').set(u.auth).send({ code: `ABC-${1000 + i}` })).status);
    }
    expect(statuses.slice(0, 10).every((s) => s === 404)).toBe(true);
    expect(statuses.slice(10).every((s) => s === 429)).toBe(true);
  });

  it('a manual LeetCode sync cannot be repeated within two minutes', async () => {
    process.env.THROTTLE_DISABLED = 'true';
    const u = await login(ctx, 'eager_syncer');
    await linkLeetCode(ctx, u, 'eager_lc');
    await ctx.http().post('/api/v1/leetcode/sync').set(u.auth).expect(201);
    await ctx.http().post('/api/v1/leetcode/sync').set(u.auth).expect(429);
  });
});

describe('Rate limiting behind Cloudflare (CLIENT_IP_HEADER)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    process.env.CLIENT_IP_HEADER = 'cf-connecting-ip';
    ctx = await createTestApp();
    process.env.THROTTLE_DISABLED = 'false';
  });

  afterAll(async () => {
    process.env.THROTTLE_DISABLED = 'true';
    delete process.env.CLIENT_IP_HEADER;
    await ctx.app.close();
  });

  const refresh = (cfIp: string, xff: string) =>
    ctx.http().post('/api/v1/auth/refresh')
      .set('CF-Connecting-IP', cfIp).set('X-Forwarded-For', xff)
      .send({ refreshToken: 'guess' });

  it('limits by the Cloudflare client IP even when X-Forwarded-For varies', async () => {
    const statuses: number[] = [];
    for (let i = 0; i < 33; i++) statuses.push((await refresh('203.0.113.7', `10.0.0.${i}`)).status);
    expect(statuses.slice(0, 30).every((s) => s === 401)).toBe(true);
    expect(statuses.slice(30).every((s) => s === 429)).toBe(true);
  });

  it('a different real client IP has its own budget', async () => {
    expect((await refresh('198.51.100.9', '10.9.9.9')).status).toBe(401);
  });
});
