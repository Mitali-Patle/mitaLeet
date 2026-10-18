import {
  Injectable, NotFoundException, BadRequestException, ForbiddenException, Logger,
  ConflictException, OnModuleInit,
} from '@nestjs/common';
import { RaceRoom } from '@prisma/client';
import { PrismaService } from '../../core/prisma/prisma.service';
import { EventsGateway, WS_EVENTS } from '../../core/events/events.gateway';
import { XPService } from '../gamification/xp.service';
import { NewSolvesEvent, SyncService } from '../leetcode/sync.service';

const RACE_XP = { 1: 150, 2: 75, 3: 40 } as Record<number, number>;

/** LeetCode submission timestamps have 1s precision; compare race starts at the same precision. */
const toSecond = (d: Date) => new Date(Math.floor(d.getTime() / 1000) * 1000);
const COUNTDOWN_SECONDS = 5;

@Injectable()
export class RaceService implements OnModuleInit {
  private readonly logger = new Logger(RaceService.name);
  private countdownTimers = new Map<string, NodeJS.Timeout>();

  constructor(
    private prisma: PrismaService,
    private events: EventsGateway,
    private xp: XPService,
    private sync: SyncService,
  ) {}

  onModuleInit() {
    // A verified solve of the race problem finishes the racer automatically.
    this.sync.onNewSolves((event) => this.finishFromSolves(event));
  }

  /** Create a new race room. */
  async createRoom(userId: string, problemSlug: string, problemName?: string) {
    const code = this.genCode();
    const room = await this.prisma.raceRoom.create({
      data: {
        code, problemSlug, problemName,
        creatorId: userId,
        participants: { create: { userId } },
      },
      include: { participants: { include: { user: { select: { id: true, displayName: true } } } } },
    });

    this.logger.log(`Race room created: ${room.code} by ${userId}`);
    return room;
  }

  /** Join an existing race room by code. */
  async joinRoom(userId: string, code: string) {
    const room = await this.prisma.raceRoom.findUnique({
      where: { code: code.toUpperCase() },
      include: { participants: true },
    });
    if (!room) throw new NotFoundException('Race room not found');
    if (room.status !== 'WAITING') throw new BadRequestException('Race already in progress');
    if (room.participants.length >= room.maxPlayers) throw new BadRequestException('Room is full');

    const existing = room.participants.find((p) => p.userId === userId);
    if (!existing) {
      await this.prisma.raceParticipant.create({ data: { userId, roomId: room.id } });
    }

    const updated = await this.getRoom(room.id);
    this.events.emitToRoom(`race:${room.id}`, WS_EVENTS.RACE_PLAYER_JOINED, {
      roomId: room.id,
      participants: updated?.participants,
    });
    return updated;
  }

  /** Creator starts the countdown. */
  async startRace(userId: string, roomId: string) {
    const room = await this.prisma.raceRoom.findUnique({
      where: { id: roomId },
      include: { participants: true },
    });
    if (!room) throw new NotFoundException('Room not found');
    if (room.creatorId !== userId) throw new ForbiddenException('Only creator can start');
    if (room.status !== 'WAITING') throw new BadRequestException('Race already started');
    if (room.participants.length < 2) throw new BadRequestException('Need at least 2 players');

    // Countdown phase
    await this.prisma.raceRoom.update({
      where: { id: roomId },
      data: { status: 'COUNTDOWN' },
    });

    this.events.emitToRoom(`race:${roomId}`, WS_EVENTS.RACE_COUNTDOWN, {
      roomId, seconds: COUNTDOWN_SECONDS,
    });

    const timer = setTimeout(() => this.activateRace(roomId), COUNTDOWN_SECONDS * 1000);
    this.countdownTimers.set(roomId, timer);

    return { started: true, countdown: COUNTDOWN_SECONDS };
  }

  /** Called after countdown — transitions to ACTIVE. */
  private async activateRace(roomId: string) {
    this.countdownTimers.delete(roomId);
    await this.prisma.raceRoom.update({
      where: { id: roomId },
      data: { status: 'ACTIVE', startedAt: new Date() },
    });
    this.events.emitToRoom(`race:${roomId}`, WS_EVENTS.RACE_STARTED, { roomId, startedAt: new Date() });
    this.logger.log(`Race ${roomId} started`);
  }

  /** Participant updates their solving status. */
  async updateStatus(userId: string, roomId: string, status: string) {
    const participant = await this.prisma.raceParticipant.findUnique({
      where: { userId_roomId: { userId, roomId } },
    });
    if (!participant) throw new NotFoundException('Not in this race');

    await this.prisma.raceParticipant.update({
      where: { userId_roomId: { userId, roomId } },
      data: { status },
    });

    this.events.emitToRoom(`race:${roomId}`, WS_EVENTS.RACE_PARTICIPANT_STATUS, {
      roomId, userId, status,
    });
  }

  /**
   * A racer says they solved it. Requires an accepted LeetCode submission of
   * the race problem made after the race started; counts once per racer.
   */
  async submitSolve(userId: string, roomId: string) {
    const room = await this.prisma.raceRoom.findUnique({ where: { id: roomId } });
    if (!room || room.status !== 'ACTIVE' || !room.startedAt) {
      throw new BadRequestException('Race not active');
    }
    const participant = await this.prisma.raceParticipant.findUnique({
      where: { userId_roomId: { userId, roomId } },
    });
    if (!participant) throw new NotFoundException('Not in this race');
    if (participant.completedAt) throw new ConflictException('You already finished this race');

    let solve = await this.findQualifyingSolve(userId, room);
    if (!solve) {
      await this.sync.syncRecent(userId);
      solve = await this.findQualifyingSolve(userId, room);
    }
    if (!solve) {
      throw new ConflictException(
        `No accepted LeetCode submission for "${room.problemSlug}" since the race started yet`,
      );
    }

    const result = await this.markFinished(userId, room, solve.solvedAt);
    if (result) return result;

    // The verification above may already have finished this racer via sync.
    const finished = await this.prisma.raceParticipant.findUniqueOrThrow({
      where: { userId_roomId: { userId, roomId } },
    });
    if (!finished.completedAt || participant.completedAt) {
      throw new ConflictException('You already finished this race');
    }
    return {
      placement: finished.rank,
      xpReward: RACE_XP[finished.rank ?? 0] ?? 25,
      durationMs: finished.durationMs,
    };
  }

  /** Finish racers in active races whose problem one of the new verified solves matches. */
  private async finishFromSolves({ userId, solves }: NewSolvesEvent): Promise<void> {
    const slugs = [...new Set(solves.map((s) => s.problemSlug))];
    const open = await this.prisma.raceParticipant.findMany({
      where: { userId, completedAt: null, room: { status: 'ACTIVE', problemSlug: { in: slugs } } },
      include: { room: true },
    });
    for (const p of open) {
      const solve = solves.find(
        (s) => s.problemSlug === p.room.problemSlug && p.room.startedAt && s.solvedAt >= toSecond(p.room.startedAt),
      );
      if (solve) await this.markFinished(userId, p.room, solve.solvedAt);
    }
  }

  private findQualifyingSolve(userId: string, room: RaceRoom) {
    return this.prisma.solve.findFirst({
      where: { userId, problemSlug: room.problemSlug, solvedAt: { gte: toSecond(room.startedAt!) } },
      orderBy: { solvedAt: 'asc' },
    });
  }

  /** Record a racer's finish exactly once, ranked by the real LeetCode solve time. */
  private async markFinished(userId: string, room: RaceRoom, solvedAt: Date) {
    const durationMs = Math.max(0, solvedAt.getTime() - room.startedAt!.getTime());
    const claimed = await this.prisma.raceParticipant.updateMany({
      where: { userId, roomId: room.id, completedAt: null },
      data: { status: 'ACCEPTED', completedAt: solvedAt, durationMs },
    });
    if (claimed.count === 0) return null;

    const placement = await this.prisma.raceParticipant.count({
      where: { roomId: room.id, completedAt: { not: null, lte: solvedAt } },
    });
    await this.prisma.raceParticipant.update({
      where: { userId_roomId: { userId, roomId: room.id } },
      data: { rank: placement },
    });

    const xpReward = RACE_XP[placement] ?? 25;
    await this.xp.awardBonusXP(userId, xpReward, `race_finish:${room.id}:place${placement}`);

    this.events.emitToRoom(`race:${room.id}`, WS_EVENTS.RACE_PARTICIPANT_STATUS, {
      roomId: room.id, userId, status: 'ACCEPTED', placement, durationMs,
    });

    const remaining = await this.prisma.raceParticipant.count({
      where: { roomId: room.id, completedAt: null },
    });
    if (remaining === 0) await this.finishRace(room.id);

    return { placement, xpReward, durationMs };
  }

  /** End the race, broadcast results. */
  async finishRace(roomId: string) {
    const ended = await this.prisma.raceRoom.updateMany({
      where: { id: roomId, status: 'ACTIVE' },
      data: { status: 'FINISHED', finishedAt: new Date() },
    });
    if (ended.count === 0) return null;
    const room = await this.prisma.raceRoom.findUniqueOrThrow({
      where: { id: roomId },
      include: {
        participants: {
          orderBy: { rank: 'asc' },
          include: { user: { select: { id: true, displayName: true } } },
        },
      },
    });
    this.events.emitToRoom(`race:${roomId}`, WS_EVENTS.RACE_FINISHED, {
      roomId,
      results: room.participants.map((p) => ({
        userId: p.userId,
        displayName: p.user.displayName,
        placement: p.rank,
        durationMs: p.durationMs,
        status: p.status,
      })),
    });
    this.logger.log(`Race ${roomId} finished`);
    return room;
  }

  async getRoom(roomId: string) {
    return this.prisma.raceRoom.findUnique({
      where: { id: roomId },
      include: {
        participants: {
          include: { user: { select: { id: true, displayName: true, avatarUrl: true } } },
        },
        creator: { select: { id: true, displayName: true } },
      },
    });
  }

  async getUserRaces(userId: string, limit = 10) {
    const participations = await this.prisma.raceParticipant.findMany({
      where: { userId },
      orderBy: { joinedAt: 'desc' },
      take: limit,
      include: {
        room: {
          include: {
            participants: {
              include: { user: { select: { displayName: true } } },
            },
          },
        },
      },
    });
    return participations;
  }

  private genCode(): string {
    return Math.random().toString(36).slice(2, 8).toUpperCase();
  }
}
