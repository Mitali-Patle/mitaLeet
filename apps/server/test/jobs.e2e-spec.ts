import { runExclusive } from '../src/common/jobs/run-exclusive';
import { SyncService } from '../src/modules/leetcode/sync.service';
import { createTestApp, linkLeetCode, login, resetDb, TestContext } from './helpers';

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

describe('Background jobs (e2e)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
    await resetDb(ctx.prisma);
  });

  afterAll(async () => {
    await ctx.app.close();
  });

  it('a scheduled job runs once even if two instances fire it together', async () => {
    let runs = 0;
    const job = async () => { runs++; await sleep(300); };
    const results = await Promise.all([
      runExclusive(ctx.prisma, 'test-job', job),
      runExclusive(ctx.prisma, 'test-job', job),
    ]);
    expect(runs).toBe(1);
    expect(results.sort()).toEqual([false, true]);
    // and the lock is released afterwards
    expect(await runExclusive(ctx.prisma, 'test-job', job)).toBe(true);
  });

  it('the scheduled LeetCode sync never runs more than 5 users at once', async () => {
    for (let i = 0; i < 12; i++) {
      const u = await login(ctx, `bulk_${i}`);
      await linkLeetCode(ctx, u, `bulk_lc_${i}`);
    }
    let inFlight = 0;
    let peak = 0;
    const original = ctx.leetcode.fetchUserProfile.bind(ctx.leetcode);
    ctx.leetcode.fetchUserProfile = async (username: string) => {
      inFlight++; peak = Math.max(peak, inFlight);
      await sleep(150);
      inFlight--;
      return original(username);
    };

    await ctx.app.get(SyncService).scheduledSync();
    for (let i = 0; i < 50; i++) {
      const pending = await ctx.prisma.syncJob.count({ where: { status: { in: ['PENDING', 'RUNNING'] } } });
      if (pending === 0) break;
      await sleep(100);
    }
    expect(await ctx.prisma.syncJob.count({ where: { status: 'COMPLETED' } })).toBe(12);
    expect(peak).toBeGreaterThan(1);
    expect(peak).toBeLessThanOrEqual(5);
  });
});
