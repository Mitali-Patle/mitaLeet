import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  ConnectedSocket,
  MessageBody,
} from '@nestjs/websockets';
import { Logger, OnModuleDestroy } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import { JwtPayload } from '../auth/types';

/** Typed Socket.IO event constants. */
export const WS_EVENTS = {
  // ── Client → Server ────────────────────────────────────
  JOIN_GROUP: 'join_group',
  LEAVE_GROUP: 'leave_group',
  STATUS_UPDATE: 'status_update',
  HEARTBEAT: 'heartbeat',

  // ── Server → Client ────────────────────────────────────
  MEMBER_STATUS: 'member_status',
  PRESENCE_UPDATE: 'presence_update',
  NEW_SOLVE: 'new_solve',
  PROBLEM_SOLVED: 'problem_solved',
  SYNC_COMPLETED: 'sync_completed',
  DAILY_UPDATED: 'daily_updated',
  STREAK_UPDATE: 'streak_update',
  XP_GAINED: 'xp_gained',
  LEVEL_UP: 'level_up',
  RANK_UPDATED: 'rank_updated',
  ACHIEVEMENT_UNLOCKED: 'achievement_unlocked',
  LEADERBOARD_CHANGED: 'leaderboard_changed',
  CHALLENGE_STARTED: 'challenge_started',
  CHALLENGE_COMPLETED: 'challenge_completed',
  LEADERBOARD: 'leaderboard',
  CHALLENGE_UPDATE: 'challenge_update',
  ACTIVITY_CREATED: 'activity_created',
  NOTIFICATION: 'notification',
  FRIEND_REQUEST_SENT: 'friend_request_sent',
  FRIEND_REQUEST_ACCEPTED: 'friend_request_accepted',
  GROUP_MEMBER_JOINED: 'group_member_joined',
  GROUP_MEMBER_LEFT: 'group_member_left',
  GROUP_UPDATED: 'group_updated',
  ONLINE_MEMBERS: 'online_members',
  // ── Race events ──────────────────────────────────────────
  RACE_PLAYER_JOINED: 'race_player_joined',
  RACE_COUNTDOWN: 'race_countdown',
  RACE_STARTED: 'race_started',
  RACE_PARTICIPANT_STATUS: 'race_participant_status',
  RACE_FINISHED: 'race_finished',
} as const;

/** Tracked user presence entry. */
interface PresenceEntry {
  socketIds: Set<string>;
  status: string;
  lastHeartbeat: number;
}

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/',
  transports: ['websocket'],
  pingInterval: 25000,
  pingTimeout: 10000,
})
export class EventsGateway
  implements OnGatewayConnection, OnGatewayDisconnect, OnModuleDestroy
{
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(EventsGateway.name);
  private readonly presenceMap = new Map<string, PresenceEntry>();
  private heartbeatInterval?: ReturnType<typeof setInterval>;

  constructor(
    private jwtService: JwtService,
    private prisma: PrismaService,
  ) {}

  afterInit() {
    // Sweep stale connections every 60s
    this.heartbeatInterval = setInterval(() => this.sweepStale(), 60_000);
  }

  onModuleDestroy() {
    if (this.heartbeatInterval) clearInterval(this.heartbeatInterval);
  }

  async handleConnection(client: Socket) {
    try {
      const user = await this.authenticateSocket(client);
      if (!user) { client.disconnect(); return; }

      (client as any).user = user;
      this.trackConnection(user.sub, client.id);

      // Set user ONLINE in DB
      await this.prisma.user.update({
        where: { id: user.sub },
        data: { status: 'ONLINE' },
      }).catch(() => {});

      // Auto-join user's group rooms
      const memberships = await this.prisma.groupMember.findMany({
        where: { userId: user.sub },
        select: { groupId: true },
      });
      for (const { groupId } of memberships) {
        client.join(`group:${groupId}`);
      }

      // Auto-join friend presence room
      client.join(`user:${user.sub}`);

      // Broadcast presence to friends
      await this.broadcastPresence(user.sub, 'ONLINE');

      this.logger.log(`Connected: ${client.id} (${user.sub})`);
    } catch {
      client.disconnect();
    }
  }

  async handleDisconnect(client: Socket) {
    const user = (client as any).user as JwtPayload | undefined;
    if (!user) return;

    const entry = this.presenceMap.get(user.sub);
    if (entry) {
      entry.socketIds.delete(client.id);
      if (entry.socketIds.size === 0) {
        this.presenceMap.delete(user.sub);
        // Set OFFLINE in DB
        await this.prisma.user.update({
          where: { id: user.sub },
          data: { status: 'OFFLINE' },
        }).catch(() => {});
        await this.broadcastPresence(user.sub, 'OFFLINE');
      }
    }
    this.logger.log(`Disconnected: ${client.id}`);
  }

  // ── Client events ──────────────────────────────────────────────────

  @SubscribeMessage(WS_EVENTS.JOIN_GROUP)
  async handleJoinGroup(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { groupId: string },
  ) {
    const user = (client as any).user as JwtPayload | undefined;
    if (!user || typeof data?.groupId !== 'string') return { ok: false };

    // Only members may subscribe to a squad's live events.
    const member = await this.prisma.groupMember.findUnique({
      where: { userId_groupId: { userId: user.sub, groupId: data.groupId } },
      select: { id: true },
    });
    if (!member) return { ok: false };

    client.join(`group:${data.groupId}`);

    // Notify group members
    this.server.to(`group:${data.groupId}`).emit(WS_EVENTS.GROUP_MEMBER_JOINED, {
      userId: user.sub,
      groupId: data.groupId,
    });

    // Send current online members in this group
    const online = this.getOnlineUsersInRoom(`group:${data.groupId}`);
    client.emit(WS_EVENTS.ONLINE_MEMBERS, { groupId: data.groupId, members: online });
  }

  @SubscribeMessage(WS_EVENTS.LEAVE_GROUP)
  handleLeaveGroup(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { groupId: string },
  ) {
    const user = (client as any).user as JwtPayload;
    client.leave(`group:${data.groupId}`);
    this.server.to(`group:${data.groupId}`).emit(WS_EVENTS.GROUP_MEMBER_LEFT, {
      userId: user.sub,
      groupId: data.groupId,
    });
  }

  @SubscribeMessage(WS_EVENTS.STATUS_UPDATE)
  async handleStatusUpdate(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { status: string },
  ) {
    const user = (client as any).user as JwtPayload;
    const validStatuses = ['ONLINE', 'SOLVING', 'IDLE', 'OFFLINE'];
    if (!validStatuses.includes(data.status)) return;

    const entry = this.presenceMap.get(user.sub);
    if (entry) entry.status = data.status;

    await this.prisma.user.update({
      where: { id: user.sub },
      data: { status: data.status as any },
    }).catch(() => {});

    await this.broadcastPresence(user.sub, data.status);
  }

  @SubscribeMessage(WS_EVENTS.HEARTBEAT)
  handleHeartbeat(@ConnectedSocket() client: Socket) {
    const user = (client as any).user as JwtPayload;
    const entry = this.presenceMap.get(user.sub);
    if (entry) entry.lastHeartbeat = Date.now();
  }

  // ── Server-side emit helpers ───────────────────────────────────────

  emitToUser(userId: string, event: string, data: unknown) {
    const entry = this.presenceMap.get(userId);
    if (entry) {
      entry.socketIds.forEach((sid) => this.server.to(sid).emit(event, data));
    }
  }

  emitToGroup(groupId: string, event: string, data: unknown) {
    this.server.to(`group:${groupId}`).emit(event, data);
  }

  /** Emit to any named Socket.IO room (e.g. race rooms). */
  emitToRoom(room: string, event: string, data: unknown) {
    this.server.to(room).emit(event, data);
  }

  isUserOnline(userId: string): boolean {
    return this.presenceMap.has(userId);
  }

  getUserStatus(userId: string): string {
    return this.presenceMap.get(userId)?.status ?? 'OFFLINE';
  }

  getOnlineUsers(): string[] {
    return Array.from(this.presenceMap.keys());
  }

  // ── Private helpers ────────────────────────────────────────────────

  private trackConnection(userId: string, socketId: string) {
    if (!this.presenceMap.has(userId)) {
      this.presenceMap.set(userId, {
        socketIds: new Set(),
        status: 'ONLINE',
        lastHeartbeat: Date.now(),
      });
    }
    this.presenceMap.get(userId)!.socketIds.add(socketId);
    this.presenceMap.get(userId)!.lastHeartbeat = Date.now();
  }

  private async broadcastPresence(userId: string, status: string) {
    // Get user's friend IDs
    const friendships = await this.prisma.friendship.findMany({
      where: { OR: [{ userAId: userId }, { userBId: userId }] },
      select: { userAId: true, userBId: true },
    });

    const friendIds = friendships.map((f) =>
      f.userAId === userId ? f.userBId : f.userAId,
    );

    // Emit to each online friend
    for (const friendId of friendIds) {
      this.emitToUser(friendId, WS_EVENTS.PRESENCE_UPDATE, {
        userId,
        status,
        timestamp: new Date().toISOString(),
      });
    }

    // Emit to all group rooms user is in
    const memberships = await this.prisma.groupMember.findMany({
      where: { userId },
      select: { groupId: true },
    });
    for (const { groupId } of memberships) {
      this.server.to(`group:${groupId}`).emit(WS_EVENTS.MEMBER_STATUS, {
        userId,
        status,
      });
    }
  }

  private getOnlineUsersInRoom(room: string): string[] {
    const online: string[] = [];
    const sockets = this.server.sockets.adapter.rooms.get(room);
    if (!sockets) return online;

    for (const sid of sockets) {
      const socket = this.server.sockets.sockets.get(sid);
      if (socket) {
        const user = (socket as any).user as JwtPayload | undefined;
        if (user && !online.includes(user.sub)) {
          online.push(user.sub);
        }
      }
    }
    return online;
  }

  private async sweepStale() {
    const threshold = Date.now() - 120_000; // 2 min no heartbeat
    for (const [userId, entry] of this.presenceMap) {
      if (entry.lastHeartbeat < threshold) {
        this.logger.warn(`Sweeping stale user: ${userId}`);
        // Disconnect all sockets
        for (const sid of entry.socketIds) {
          const socket = this.server.sockets.sockets.get(sid);
          if (socket) socket.disconnect(true);
        }
        this.presenceMap.delete(userId);
        await this.prisma.user.update({
          where: { id: userId },
          data: { status: 'OFFLINE' },
        }).catch(() => {});
        await this.broadcastPresence(userId, 'OFFLINE');
      }
    }
  }

  private async authenticateSocket(client: Socket): Promise<JwtPayload | null> {
    const token =
      client.handshake?.auth?.token ||
      client.handshake?.headers?.authorization?.replace('Bearer ', '');
    if (!token) return null;
    try {
      return await this.jwtService.verifyAsync<JwtPayload>(token);
    } catch {
      return null;
    }
  }
}
