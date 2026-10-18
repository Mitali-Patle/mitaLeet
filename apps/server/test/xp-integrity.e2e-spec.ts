import {
  createTestApp, getXp, linkLeetCode, login, resetDb, seedProblem, TestContext, TestUser,
} from './helpers';

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

describe('XP integrity: only verified solves earn XP (e2e)', () => {
  let ctx: TestContext;
  let alice: TestUser;
  let bob: TestUser;
  let mallory: TestUser;
  let groupId: string;

  beforeAll(async () => {
    ctx = await createTestApp();
    await resetDb(ctx.prisma);
    await seedProblem(ctx.prisma, 'two-sum', 'EASY');
    await seedProblem(ctx.prisma, 'lru-cache', 'MEDIUM');
    await seedProblem(ctx.prisma, 'n-queens', 'HARD');
    alice = await login(ctx, 'alice');
    bob = await login(ctx, 'bob');
    mallory = await login(ctx, 'mallory');
    await linkLeetCode(ctx, alice, 'alice_lc');
    await linkLeetCode(ctx, bob, 'bob_lc');

    const g = await ctx.http().post('/api/v1/groups').set(alice.auth).send({ name: 'Grinders' }).expect(201);
    groupId = g.body.data.id;
    await ctx.http().post('/api/v1/groups/join').set(bob.auth).send({ code: g.body.data.code }).expect(201);
  });

  afterAll(async () => {
    await ctx.app.close();
  });

  describe('extension-solve', () => {
    it('requires a verified LeetCode link', async () => {
      await ctx.http().post('/api/v1/leetcode/extension-solve').set(mallory.auth)
        .send({ problemSlug: 'two-sum' }).expect(400);
    });

    it('rejects malformed input instead of erroring', async () => {
      await ctx.http().post('/api/v1/leetcode/extension-solve').set(alice.auth)
        .send({ problemSlug: 'two-sum', solvedAt: 'garbage' }).expect(400);
      await ctx.http().post('/api/v1/leetcode/extension-solve').set(alice.auth)
        .send({ problemSlug: '../../etc' }).expect(400);
    });

    it('a claimed solve that LeetCode does not show earns nothing', async () => {
      const before = await getXp(ctx, alice);
      const res = await ctx.http().post('/api/v1/leetcode/extension-solve').set(alice.auth)
        .send({ problemSlug: 'n-queens', solvedAt: new Date(Date.now() + 10 * 86_400_000).toISOString() })
        .expect(201);
      expect(res.body.data).toEqual({ created: false, verified: false });
      expect(await getXp(ctx, alice)).toBe(before);
      expect(await ctx.prisma.solve.count({ where: { userId: alice.id } })).toBe(0);
    });

    it('a solve LeetCode confirms is recorded once and earns XP once', async () => {
      ctx.leetcode.addSubmission('alice_lc', 'two-sum');
      const before = await getXp(ctx, alice);
      const res = await ctx.http().post('/api/v1/leetcode/extension-solve').set(alice.auth)
        .send({ problemSlug: 'two-sum' }).expect(201);
      expect(res.body.data).toEqual({ created: true, verified: true });
      const after = await getXp(ctx, alice);
      expect(after).toBeGreaterThan(before);

      // Repeating the claim does not duplicate the solve or the XP.
      const again = await ctx.http().post('/api/v1/leetcode/extension-solve').set(alice.auth)
        .send({ problemSlug: 'two-sum' }).expect(201);
      expect(again.body.data).toEqual({ created: false, verified: true });
      expect(await getXp(ctx, alice)).toBe(after);
      expect(await ctx.prisma.solve.count({ where: { userId: alice.id } })).toBe(1);
    });
  });

  describe('squad challenges', () => {
    const create = (body: Record<string, unknown>) =>
      ctx.http().post(`/api/v1/gamification/challenges/group/${groupId}`).set(alice.auth).send({
        title: 'LRU', problemSlug: 'lru-cache',
        startsAt: new Date(Date.now() - 60_000).toISOString(),
        endsAt: new Date(Date.now() + 86_400_000).toISOString(),
        ...body,
      });

    it('rejects out-of-range xpReward, bad dates and unknown fields', async () => {
      await create({ xpReward: 1_000_000 }).expect(400);
      await create({ endsAt: new Date(Date.now() - 120_000).toISOString() }).expect(400);
      await create({ id: 'chosen-id' }).expect(400);
      await create({ problemSlug: 'Not A Slug' }).expect(400);
    });

    it('completing without a verified solve fails and awards nothing', async () => {
      const ch = await create({ xpReward: 100 }).expect(201);
      await ctx.http().post(`/api/v1/gamification/challenges/${ch.body.data.id}/join`).set(bob.auth).expect(201);
      const before = await getXp(ctx, bob);
      await ctx.http().post(`/api/v1/gamification/challenges/${ch.body.data.id}/complete`).set(bob.auth).expect(409);
      expect(await getXp(ctx, bob)).toBe(before);
    });

    it('a verified solve in the window completes it once, even with concurrent requests', async () => {
      const ch = await create({ xpReward: 100 }).expect(201);
      const id = ch.body.data.id;
      await ctx.http().post(`/api/v1/gamification/challenges/${id}/join`).set(alice.auth).expect(201);
      ctx.leetcode.addSubmission('alice_lc', 'lru-cache');

      const before = await getXp(ctx, alice);
      const results = await Promise.all(
        [1, 2, 3].map(() => ctx.http().post(`/api/v1/gamification/challenges/${id}/complete`).set(alice.auth)),
      );
      expect(results.every((r) => r.status === 201)).toBe(true);

      const p = await ctx.prisma.challengeParticipant.findUniqueOrThrow({
        where: { userId_challengeId: { userId: alice.id, challengeId: id } },
      });
      expect(p.rank).toBe(1);
      expect(p.xpAwarded).toBe(200); // 100 × 2 for first place
      // Solve XP for lru-cache (MEDIUM) + challenge XP, exactly once each.
      expect(await getXp(ctx, alice)).toBe(before + 25 + 200);
    });
  });

  describe('races', () => {
    let roomId: string;

    beforeAll(async () => {
      const room = await ctx.http().post('/api/v1/races').set(alice.auth).send({ problemSlug: 'n-queens' }).expect(201);
      roomId = room.body.data.id;
      await ctx.http().post('/api/v1/races/join').set(bob.auth).send({ code: room.body.data.code }).expect(201);
      await ctx.http().post(`/api/v1/races/${roomId}/start`).set(alice.auth).expect(201);
      // Wait for the 5s countdown to actually flip the room to ACTIVE.
      for (let i = 0; i < 100; i++) {
        const r = await ctx.prisma.raceRoom.findUniqueOrThrow({ where: { id: roomId } });
        if (r.status === 'ACTIVE') break;
        await sleep(100);
      }
    }, 20_000);

    it('racers cannot self-report ACCEPTED', async () => {
      await ctx.http().patch(`/api/v1/races/${roomId}/status`).set(alice.auth).send({ status: 'ACCEPTED' }).expect(400);
      await ctx.http().patch(`/api/v1/races/${roomId}/status`).set(alice.auth).send({ status: 'CODING' }).expect(200);
    });

    it('submitting without a verified solve fails and awards nothing', async () => {
      const before = await getXp(ctx, alice);
      await ctx.http().post(`/api/v1/races/${roomId}/solve`).set(alice.auth).expect(409);
      expect(await getXp(ctx, alice)).toBe(before);
    });

    it('a verified solve finishes the racer once; repeats are rejected', async () => {
      ctx.leetcode.addSubmission('alice_lc', 'n-queens');
      const before = await getXp(ctx, alice);
      const first = await ctx.http().post(`/api/v1/races/${roomId}/solve`).set(alice.auth).expect(201);
      expect(first.body.data.placement).toBe(1);
      const afterFirst = await getXp(ctx, alice);
      expect(afterFirst - before).toBeGreaterThanOrEqual(150); // race XP (+ HARD solve XP)

      for (let i = 0; i < 3; i++) {
        await ctx.http().post(`/api/v1/races/${roomId}/solve`).set(alice.auth).expect(409);
      }
      expect(await getXp(ctx, alice)).toBe(afterFirst);
    });

    it('a verified solve arriving through sync finishes the race automatically', async () => {
      ctx.leetcode.addSubmission('bob_lc', 'n-queens');
      await ctx.http().post('/api/v1/leetcode/extension-solve').set(bob.auth).send({ problemSlug: 'n-queens' }).expect(201);
      const room = await ctx.prisma.raceRoom.findUniqueOrThrow({ where: { id: roomId }, include: { participants: true } });
      expect(room.status).toBe('FINISHED');
      expect(room.participants.find((p) => p.userId === bob.id)?.rank).toBe(2);
    });
  });

  it('a full sync never lowers XP earned from races and challenges', async () => {
    const before = await getXp(ctx, alice);
    await ctx.http().post('/api/v1/leetcode/sync').set(alice.auth).expect(201);
    for (let i = 0; i < 20; i++) {
      const job = await ctx.prisma.syncJob.findFirst({ where: { userId: alice.id }, orderBy: { createdAt: 'desc' } });
      if (job?.status === 'COMPLETED' || job?.status === 'FAILED') break;
      await sleep(100);
    }
    expect(await getXp(ctx, alice)).toBe(before);
  });
});
