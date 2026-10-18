import { createTestApp, login, resetDb, TestContext, TestUser } from './helpers';

describe('Input validation and pagination (e2e)', () => {
  let ctx: TestContext;
  let u: TestUser;

  beforeAll(async () => {
    ctx = await createTestApp();
    await resetDb(ctx.prisma);
    u = await login(ctx, 'validator');
    await login(ctx, 'alpha_user');
    await login(ctx, 'alpine_user');
  });

  afterAll(async () => {
    await ctx.app.close();
  });

  it.each([
    '/api/v1/leetcode/solves?limit=100000000',
    '/api/v1/leetcode/solves?limit=abc',
    '/api/v1/leetcode/heatmap?days=5000',
    '/api/v1/notifications?limit=0',
    '/api/v1/gamification/leaderboard/global?limit=1000',
    '/api/v1/gamification/leaderboard/global?period=forever',
    '/api/v1/activities/feed?cursor=not-a-uuid',
  ])('rejects out-of-range query: %s', async (path) => {
    await ctx.http().get(path).set(u.auth).expect(400);
  });

  it('user search needs at least 2 characters and is bounded', async () => {
    await ctx.http().get('/api/v1/friends/search').set(u.auth).expect(400);
    await ctx.http().get('/api/v1/friends/search?q=a').set(u.auth).expect(400);
    await ctx.http().get('/api/v1/friends/search?q=al&limit=500').set(u.auth).expect(400);
    const res = await ctx.http().get('/api/v1/friends/search?q=alp').set(u.auth).expect(200);
    expect(res.body.data.map((r: { username: string }) => r.username).sort()).toEqual(['alpha_user', 'alpine_user']);
  });

  it('profile fields are length- and scheme-checked', async () => {
    await ctx.http().put('/api/v1/users/me/profile').set(u.auth).send({ displayName: 'x'.repeat(51) }).expect(400);
    await ctx.http().put('/api/v1/users/me/profile').set(u.auth).send({ avatarUrl: 'javascript:alert(1)' }).expect(400);
    await ctx.http().put('/api/v1/users/me/profile').set(u.auth).send({ avatarUrl: 'http://insecure.example.com/a.png' }).expect(400);
    await ctx.http().put('/api/v1/users/me/profile').set(u.auth)
      .send({ displayName: 'Valid Name', avatarUrl: 'https://cdn.example.com/a.png' }).expect(200);
  });

  it('malformed JSON is a 400, not a 500', async () => {
    await ctx.http().put('/api/v1/users/me/profile').set(u.auth)
      .set('Content-Type', 'application/json').send('{"displayName": ').expect(400);
  });

  it('activity feed pages by cursor without gaps or repeats', async () => {
    const g = await ctx.http().post('/api/v1/groups').set(u.auth).send({ name: 'Feed Squad' }).expect(201);
    expect(g.body.data.id).toBeDefined();
    const base = Date.now();
    await ctx.prisma.activity.createMany({
      data: Array.from({ length: 25 }, (_, i) => ({
        userId: u.id, type: 'SOLVE' as const, data: { n: i },
        createdAt: new Date(base - (i % 5) * 1000), // many share a timestamp
      })),
    });

    const seen: string[] = [];
    let cursor: string | undefined;
    for (let page = 0; page < 10; page++) {
      const res = await ctx.http().get('/api/v1/activities/feed')
        .query({ limit: 7, ...(cursor && { cursor }) }).set(u.auth).expect(200);
      const items = res.body.data as { id: string }[];
      if (items.length === 0) break;
      seen.push(...items.map((i) => i.id));
      cursor = items[items.length - 1].id;
    }
    expect(seen).toHaveLength(25);
    expect(new Set(seen).size).toBe(25);
  });
});
