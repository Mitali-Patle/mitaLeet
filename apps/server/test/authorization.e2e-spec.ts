import { AddressInfo } from 'net';
import { io, Socket } from 'socket.io-client';
import { createTestApp, linkLeetCode, login, resetDb, seedProblem, TestContext, TestUser } from './helpers';

describe('Authorization: squads, challenges, devices (e2e)', () => {
  let ctx: TestContext;
  let owner: TestUser;
  let member: TestUser;
  let outsider: TestUser;
  let groupId: string;
  let inviteCode: string;

  beforeAll(async () => {
    ctx = await createTestApp();
    await resetDb(ctx.prisma);
    await seedProblem(ctx.prisma, 'two-sum');
    owner = await login(ctx, 'owner');
    member = await login(ctx, 'member');
    outsider = await login(ctx, 'outsider');

    const g = await ctx.http().post('/api/v1/groups').set(owner.auth).send({ name: 'Private Squad' }).expect(201);
    groupId = g.body.data.id;
    inviteCode = g.body.data.code;
    await ctx.http().post('/api/v1/groups/join').set(member.auth).send({ code: inviteCode }).expect(201);
    await linkLeetCode(ctx, member, 'member_lc');
  });

  afterAll(async () => {
    await ctx.app.close();
  });

  describe('squad reads require membership', () => {
    it.each([
      ['group details', () => `/api/v1/groups/${groupId}`],
      ['group leaderboard', () => `/api/v1/groups/${groupId}/leaderboard`],
      ['group activity', () => `/api/v1/groups/${groupId}/activity`],
      ['gamification group leaderboard', () => `/api/v1/gamification/leaderboard/groups/${groupId}`],
      ['group challenges', () => `/api/v1/gamification/challenges/group/${groupId}`],
    ])('outsider gets 404 for %s', async (_name, path) => {
      const res = await ctx.http().get(path()).set(outsider.auth);
      expect(res.status).toBe(404);
      expect(JSON.stringify(res.body)).not.toContain(inviteCode);
    });

    it.each([
      ['group details', () => `/api/v1/groups/${groupId}`],
      ['group leaderboard', () => `/api/v1/groups/${groupId}/leaderboard`],
      ['group activity', () => `/api/v1/groups/${groupId}/activity`],
      ['gamification group leaderboard', () => `/api/v1/gamification/leaderboard/groups/${groupId}`],
      ['group challenges', () => `/api/v1/gamification/challenges/group/${groupId}`],
    ])('member can read %s', async (_name, path) => {
      await ctx.http().get(path()).set(member.auth).expect(200);
    });

    it('member sees the invite code so they can invite friends', async () => {
      const res = await ctx.http().get(`/api/v1/groups/${groupId}`).set(member.auth).expect(200);
      expect(res.body.data.code).toBe(inviteCode);
    });
  });

  it('outsider cannot join a squad challenge', async () => {
    const ch = await ctx.http()
      .post(`/api/v1/gamification/challenges/group/${groupId}`)
      .set(owner.auth)
      .send({
        title: 'Daily', problemSlug: 'two-sum',
        startsAt: new Date().toISOString(),
        endsAt: new Date(Date.now() + 86_400_000).toISOString(),
      })
      .expect(201);
    await ctx.http().post(`/api/v1/gamification/challenges/${ch.body.data.id}/join`).set(outsider.auth).expect(404);
    await ctx.http().post(`/api/v1/gamification/challenges/${ch.body.data.id}/join`).set(member.auth).expect(201);
  });

  it("a user cannot delete another user's push token", async () => {
    await ctx.http().post('/api/v1/users/me/devices').set(member.auth)
      .send({ token: 'member-device-token', platform: 'android' }).expect(201);
    await ctx.http().delete('/api/v1/users/me/devices/member-device-token').set(outsider.auth);
    expect(await ctx.prisma.deviceToken.count({ where: { token: 'member-device-token' } })).toBe(1);

    await ctx.http().delete('/api/v1/users/me/devices/member-device-token').set(member.auth).expect(200);
    expect(await ctx.prisma.deviceToken.count({ where: { token: 'member-device-token' } })).toBe(0);
  });

  describe('websocket squad rooms', () => {
    let url: string;
    const sockets: Socket[] = [];

    beforeAll(async () => {
      await ctx.app.listen(0);
      const { port } = ctx.app.getHttpServer().address() as AddressInfo;
      url = `http://127.0.0.1:${port}`;
    });

    afterAll(async () => {
      sockets.forEach((s) => s.disconnect());
      // let the server finish its disconnect handlers before the app closes
      await new Promise((r) => setTimeout(r, 300));
    });

    const connect = (user: TestUser) =>
      new Promise<Socket>((resolve, reject) => {
        const s = io(url, { transports: ['websocket'], auth: { token: user.accessToken }, forceNew: true });
        sockets.push(s);
        s.on('connect', () => setTimeout(() => resolve(s), 200)); // let server-side auto-joins finish
        s.on('connect_error', reject);
      });

    it("outsider cannot subscribe to a squad's live events via join_group", async () => {
      const spy = await connect(outsider);
      const received: unknown[] = [];
      spy.on('activity_created', (d) => received.push(d));
      spy.emit('join_group', { groupId });
      await new Promise((r) => setTimeout(r, 300));

      // A member solving broadcasts activity_created to the squad room.
      ctx.leetcode.addSubmission('member_lc', 'two-sum');
      await ctx.http().post('/api/v1/leetcode/extension-solve').set(member.auth)
        .send({ problemSlug: 'two-sum', language: 'python3' });
      await new Promise((r) => setTimeout(r, 500));
      expect(received).toHaveLength(0);
    });

    it('member still receives squad events', async () => {
      const s = await connect(owner);
      const received: unknown[] = [];
      s.on('activity_created', (d) => received.push(d));
      await ctx.prisma.solve.deleteMany({});
      ctx.leetcode.addSubmission('member_lc', 'two-sum', new Date(Date.now() + 1000));
      await ctx.http().post('/api/v1/leetcode/extension-solve').set(member.auth)
        .send({ problemSlug: 'two-sum', language: 'python3' });
      await new Promise((r) => setTimeout(r, 500));
      expect(received.length).toBeGreaterThan(0);
    });
  });
});
