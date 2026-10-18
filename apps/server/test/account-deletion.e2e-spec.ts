import { createTestApp, login, resetDb, TestContext } from './helpers';

describe('Account deletion (e2e)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp();
    await resetDb(ctx.prisma);
  });

  afterAll(async () => {
    await ctx.app.close();
  });

  it('requires explicit confirmation', async () => {
    const u = await login(ctx, 'careful');
    await ctx.http().delete('/api/v1/users/me').set(u.auth).send({}).expect(400);
    await ctx.http().delete('/api/v1/users/me').set(u.auth).send({ confirm: 'yes' }).expect(400);
    await ctx.http().get('/api/v1/users/me').set(u.auth).expect(200);
  });

  it('removes the user and their data, hands owned squads on, and ends sessions', async () => {
    const leaving = await login(ctx, 'leaving');
    const admin = await login(ctx, 'admin_stays');
    const member = await login(ctx, 'member_stays');

    const shared = (await ctx.http().post('/api/v1/groups').set(leaving.auth).send({ name: 'Shared' }).expect(201)).body.data;
    await ctx.http().post('/api/v1/groups/join').set(member.auth).send({ code: shared.code }).expect(201);
    await ctx.http().post('/api/v1/groups/join').set(admin.auth).send({ code: shared.code }).expect(201);
    await ctx.http().put(`/api/v1/groups/${shared.id}/members/${admin.id}/promote`).set(leaving.auth).expect(200);
    const solo = (await ctx.http().post('/api/v1/groups').set(leaving.auth).send({ name: 'Solo' }).expect(201)).body.data;
    await ctx.http().post('/api/v1/friends/requests').set(leaving.auth).send({ receiverId: member.id }).expect(201);

    await ctx.http().delete('/api/v1/users/me').set(leaving.auth).send({ confirm: 'DELETE' }).expect(204);

    expect(await ctx.prisma.user.count({ where: { id: leaving.id } })).toBe(0);
    expect(await ctx.prisma.userProfile.count({ where: { userId: leaving.id } })).toBe(0);
    expect(await ctx.prisma.userSession.count({ where: { userId: leaving.id } })).toBe(0);
    expect(await ctx.prisma.friendRequest.count({ where: { senderId: leaving.id } })).toBe(0);
    expect(await ctx.prisma.group.count({ where: { id: solo.id } })).toBe(0);

    const owner = await ctx.prisma.groupMember.findFirstOrThrow({ where: { groupId: shared.id, role: 'OWNER' } });
    expect(owner.userId).toBe(admin.id); // admin preferred over the earlier-joined member

    await ctx.http().get('/api/v1/users/me').set(leaving.auth).expect(401);
    await ctx.http().post('/api/v1/auth/refresh').send({ refreshToken: leaving.refreshToken }).expect(401);
  });
});
