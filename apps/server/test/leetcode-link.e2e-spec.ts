import { createTestApp, login, resetDb, TestContext, TestUser } from './helpers';

describe('LeetCode account linking requires proof of ownership (e2e)', () => {
  let ctx: TestContext;
  let owner: TestUser;
  let impostor: TestUser;

  const setAboutMe = (username: string, text: string) => {
    ctx.leetcode.profiles.get(username)!.aboutMe = text;
  };

  beforeAll(async () => {
    ctx = await createTestApp();
    await resetDb(ctx.prisma);
    owner = await login(ctx, 'owner');
    impostor = await login(ctx, 'impostor');
    ctx.leetcode.addUser('famous_coder', 'I like graphs');
  });

  afterAll(async () => {
    await ctx.app.close();
  });

  const status = async (u: TestUser) =>
    (await ctx.http().get('/api/v1/leetcode/status').set(u.auth).expect(200)).body.data;

  it('rejects unknown LeetCode usernames and bad formats', async () => {
    await ctx.http().post('/api/v1/leetcode/link').set(owner.auth).send({ leetcodeUsername: 'nobody_here' }).expect(400);
    await ctx.http().post('/api/v1/leetcode/link').set(owner.auth).send({ leetcodeUsername: 'a b; drop' }).expect(400);
  });

  it('starting a link only issues a code; nothing is linked yet', async () => {
    const res = await ctx.http().post('/api/v1/leetcode/link').set(owner.auth)
      .send({ leetcodeUsername: 'Famous_Coder' }).expect(201);
    expect(res.body.data.leetcodeUsername).toBe('famous_coder');
    expect(res.body.data.verificationCode).toMatch(/^mitaleet-[0-9a-f]{10}$/);
    expect((await status(owner)).leetcodeUsername).toBeNull();
  });

  it('codes are specific to each user', async () => {
    const a = await ctx.http().post('/api/v1/leetcode/link').set(owner.auth).send({ leetcodeUsername: 'famous_coder' });
    const b = await ctx.http().post('/api/v1/leetcode/link').set(impostor.auth).send({ leetcodeUsername: 'famous_coder' });
    expect(a.body.data.verificationCode).not.toBe(b.body.data.verificationCode);
  });

  it('verification fails until the code is on the LeetCode profile', async () => {
    await ctx.http().post('/api/v1/leetcode/link/verify').set(impostor.auth)
      .send({ leetcodeUsername: 'famous_coder' }).expect(400);
    expect((await status(impostor)).leetcodeUsername).toBeNull();
  });

  it("someone else's code on the profile does not verify the impostor", async () => {
    const ownerCode = (await ctx.http().post('/api/v1/leetcode/link').set(owner.auth)
      .send({ leetcodeUsername: 'famous_coder' })).body.data.verificationCode;
    setAboutMe('famous_coder', `I like graphs ${ownerCode}`);
    await ctx.http().post('/api/v1/leetcode/link/verify').set(impostor.auth)
      .send({ leetcodeUsername: 'famous_coder' }).expect(400);
  });

  it('the real owner verifies, gets linked, and an initial sync is queued', async () => {
    const res = await ctx.http().post('/api/v1/leetcode/link/verify').set(owner.auth)
      .send({ leetcodeUsername: 'famous_coder' }).expect(201);
    expect(res.body.data).toMatchObject({ leetcodeUsername: 'famous_coder', leetcodeVerified: true });
    expect(await ctx.prisma.syncJob.count({ where: { userId: owner.id } })).toBeGreaterThan(0);
  });

  it('a linked account cannot be claimed by a second user', async () => {
    const code = (await ctx.http().post('/api/v1/leetcode/link').set(impostor.auth)
      .send({ leetcodeUsername: 'famous_coder' })).status;
    expect(code).toBe(409);
  });

  it('the profile endpoint can no longer set a LeetCode username', async () => {
    await ctx.http().put('/api/v1/users/me/profile').set(impostor.auth)
      .send({ leetcodeUsername: 'famous_coder' }).expect(400);
    expect((await status(impostor)).leetcodeUsername).toBeNull();
  });
});
