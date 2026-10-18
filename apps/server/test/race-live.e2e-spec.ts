import { AddressInfo } from 'net';
import { io, Socket } from 'socket.io-client';
import { createTestApp, login, resetDb, seedProblem, TestContext, TestUser } from './helpers';

describe('Race live updates over sockets (e2e)', () => {
  let ctx: TestContext;
  let host: TestUser;
  let guest: TestUser;
  let outsider: TestUser;
  let url: string;
  const sockets: Socket[] = [];

  beforeAll(async () => {
    ctx = await createTestApp();
    await resetDb(ctx.prisma);
    await seedProblem(ctx.prisma, 'two-sum');
    host = await login(ctx, 'host');
    guest = await login(ctx, 'guest');
    outsider = await login(ctx, 'outsider');
    await ctx.app.listen(0);
    url = `http://127.0.0.1:${(ctx.app.getHttpServer().address() as AddressInfo).port}`;
  });

  afterAll(async () => {
    sockets.forEach((s) => s.disconnect());
    await new Promise((r) => setTimeout(r, 300));
    await ctx.app.close();
  });

  const connect = (u: TestUser) =>
    new Promise<Socket>((resolve, reject) => {
      const s = io(url, { transports: ['websocket'], auth: { token: u.accessToken }, forceNew: true });
      sockets.push(s);
      s.on('connect', () => resolve(s));
      s.on('connect_error', reject);
    });

  const joinRoom = (s: Socket, room: string) =>
    new Promise<{ ok: boolean }>((resolve) => s.emit('join_room', { room }, resolve));

  it('participants receive countdown; outsiders cannot subscribe', async () => {
    const room = (await ctx.http().post('/api/v1/races').set(host.auth).send({ problemSlug: 'two-sum' }).expect(201)).body.data;
    await ctx.http().post('/api/v1/races/join').set(guest.auth).send({ code: room.code }).expect(201);

    const [hs, gs, os] = await Promise.all([connect(host), connect(guest), connect(outsider)]);
    const got = { host: 0, guest: 0, outsider: 0 };
    hs.on('race_countdown', () => got.host++);
    gs.on('race_countdown', () => got.guest++);
    os.on('race_countdown', () => got.outsider++);

    expect(await joinRoom(hs, `race:${room.id}`)).toEqual({ ok: true });
    expect(await joinRoom(gs, `race:${room.id}`)).toEqual({ ok: true });
    expect(await joinRoom(os, `race:${room.id}`)).toEqual({ ok: false });
    expect(await joinRoom(os, 'group:anything')).toEqual({ ok: false });

    await ctx.http().post(`/api/v1/races/${room.id}/start`).set(host.auth).expect(201);
    await new Promise((r) => setTimeout(r, 400));
    expect(got).toEqual({ host: 1, guest: 1, outsider: 0 });
  });
});
