import { createTestApp, login, resetDb, TestContext, TestUser } from './helpers';

describe('Friends (e2e)', () => {
  let ctx: TestContext;
  let ann: TestUser;
  let ben: TestUser;

  beforeAll(async () => {
    ctx = await createTestApp();
    await resetDb(ctx.prisma);
    ann = await login(ctx, 'ann');
    ben = await login(ctx, 'ben');
  });

  afterAll(async () => {
    await ctx.app.close();
  });

  const send = (from: TestUser, to: TestUser) =>
    ctx.http().post('/api/v1/friends/requests').set(from.auth).send({ receiverId: to.id });
  const respond = (as: TestUser, id: string, action: 'ACCEPTED' | 'DECLINED') =>
    ctx.http().put(`/api/v1/friends/requests/${id}`).set(as.auth).send({ action });

  it('lists empty friends and requests without errors', async () => {
    await ctx.http().get('/api/v1/friends').set(ann.auth).expect(200);
    await ctx.http().get('/api/v1/friends/requests/incoming').set(ann.auth).expect(200);
    await ctx.http().get('/api/v1/friends/requests/outgoing').set(ann.auth).expect(200);
  });

  it('request shows up incoming/outgoing with usernames', async () => {
    const r = await send(ann, ben).expect(201);
    const inc = await ctx.http().get('/api/v1/friends/requests/incoming').set(ben.auth).expect(200);
    expect(inc.body.data[0].sender.profile.username).toBe('ann');
    const out = await ctx.http().get('/api/v1/friends/requests/outgoing').set(ann.auth).expect(200);
    expect(out.body.data[0].receiver.profile.username).toBe('ben');
    await respond(ben, r.body.data.id, 'DECLINED').expect(200);
  });

  it('can send again after a decline', async () => {
    const again = await send(ann, ben).expect(201);
    await respond(ben, again.body.data.id, 'ACCEPTED').expect(200);
    const list = await ctx.http().get('/api/v1/friends').set(ann.auth).expect(200);
    expect(list.body.data.map((f: { id: string }) => f.id)).toEqual([ben.id]);
    expect(list.body.data[0].profile.username).toBe('ben');
  });

  it('a request cannot be answered twice', async () => {
    const reqs = await ctx.prisma.friendRequest.findFirstOrThrow({ where: { senderId: ann.id, receiverId: ben.id } });
    await respond(ben, reqs.id, 'ACCEPTED').expect(400);
  });

  it('can re-friend after unfriending', async () => {
    await ctx.http().delete(`/api/v1/friends/${ben.id}`).set(ann.auth).expect(200);
    expect((await ctx.http().get('/api/v1/friends').set(ann.auth)).body.data).toHaveLength(0);
    const r = await send(ann, ben).expect(201);
    await respond(ben, r.body.data.id, 'ACCEPTED').expect(200);
    expect((await ctx.http().get('/api/v1/friends').set(ben.auth)).body.data).toHaveLength(1);
  });
});
