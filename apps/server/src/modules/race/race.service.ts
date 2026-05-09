import {
  Injectable, NotFoundException, BadRequestException, ForbiddenException, Logger,
} from '@nestjs/common';
import { PrismaService } from '../../core/prisma/prisma.service';
import { EventsGateway, WS_EVENTS } from '../../core/events/events.gateway';
import { XPService } from '../gamification/xp.service';

const RACE_XP = { 1: 150, 2: 75, 3: 40 } as Record<number, number>;
const COUNTDOWN_SECONDS = 5;

@Injectable()
export class RaceService {
  private readonly logger = new Logger(RaceService.name);
  private countdownTimers = new Map<string, NodeJS.Timeout>();

  constructor(
    private prisma: PrismaService,
    private events: EventsGateway,
    private xp: XPService,
  ) {}

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

  /** Record solve completion. */
  async submitSolve(userId: string, roomId: string) {
    const room = await this.prisma.raceRoom.findUnique({
      where: { id: roomId },
      include: { participants: { where: { completedAt: { not: null } } } },
    });
    if (!room || room.status !== 'ACTIVE') throw new BadRequestException('Race not active');

    const startedAt = room.startedAt!;
    const durationMs = Date.now() - startedAt.getTime();
    const placement = room.participants.length + 1;

    await this.prisma.raceParticipant.update({
      where: { userId_roomId: { userId, roomId } },
      data: { status: 'ACCEPTED', completedAt: new Date(), durationMs, rank: placement },
    });

    // Award XP
    const xpReward = RACE_XP[placement] ?? 25;
    await this.xp.awardBonusXP(userId, xpReward, `race_finish:${roomId}:place${placement}`);

    this.events.emitToRoom(`race:${roomId}`, WS_EVENTS.RACE_PARTICIPANT_STATUS, {
      roomId, userId, status: 'ACCEPTED', placement, durationMs,
    });

    // Check if all participants finished
    const allParticipants = await this.prisma.raceParticipant.findMany({ where: { roomId } });
    const allDone = allParticipants.every((p) => p.completedAt !== null);
    if (allDone) await this.finishRace(roomId);

    return { placement, xpReward, durationMs };
  }

  /** End the race, broadcast results. */
  async finishRace(roomId: string) {
    const room = await this.prisma.raceRoom.update({
      where: { id: roomId },
      data: { status: 'FINISHED', finishedAt: new Date() },
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
