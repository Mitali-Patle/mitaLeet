import { localDateKey } from '../src/common/time/user-day';
import { createTestApp, linkLeetCode, login, resetDb, seedProblem, TestContext, TestUser } from './helpers';

describe("Days follow the user's timezone (e2e)", () => {
  let ctx: TestContext;
  let u: TestUser;
  // A zone whose calendar date differs from UTC's right now, whatever "now" is.
  const tz = new Date().getUTCHours() < 12 ? 'Etc/GMT+12' : 'Etc/GMT-14';

  beforeAll(async () => {
    ctx = await createTestApp();
    await resetDb(ctx.prisma);
    await seedProblem(ctx.prisma, 'two-sum');
    u = await login(ctx, 'traveller');
    await linkLeetCode(ctx, u, 'traveller_lc');
  });

  afterAll(async () => {
    await ctx.app.close();
  });

  it('only accepts real IANA timezones', async () => {
    await ctx.http().put('/api/v1/users/me/profile').set(u.auth).send({ timezone: 'Mars/Olympus' }).expect(400);
    await ctx.http().put('/api/v1/users/me/profile').set(u.auth).send({ timezone: tz }).expect(200);
  });

  it("a solve counts on the user's local day, not the UTC day", async () => {
    const now = new Date();
    expect(localDateKey(now, tz)).not.toBe(localDateKey(now, 'UTC')); // premise of the test

    ctx.leetcode.addSubmission('traveller_lc', 'two-sum', now);
    await ctx.http().post('/api/v1/leetcode/extension-solve').set(u.auth).send({ problemSlug: 'two-sum' }).expect(201);

    const heat = await ctx.http().get('/api/v1/leetcode/heatmap?days=3').set(u.auth).expect(200);
    expect(heat.body.data.map((d: { date: string }) => d.date.slice(0, 10))).toEqual([localDateKey(now, tz)]);

    const streak = await ctx.http().get('/api/v1/leetcode/streak').set(u.auth).expect(200);
    expect(streak.body.data).toMatchObject({ isSolvedToday: true, currentStreak: 1 });

    const stats = await ctx.http().get('/api/v1/leetcode/stats').set(u.auth).expect(200);
    expect(stats.body.data.today.solveCount).toBe(1);
  });
});
