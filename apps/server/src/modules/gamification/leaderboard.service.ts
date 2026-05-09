import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../../core/prisma/prisma.service';
import { EventsGateway, WS_EVENTS } from '../../core/events/events.gateway';
import { RANK_ORDER } from './gamification.config';

export interface LeaderboardEntry {
  rank: number;
  userId: string;
  displayName: string;
  avatarUrl: string | null;
  xp: number;
  level: number;
  rankBadge: string;
  totalSolves: number;
  hardSolves: number;
  currentStreak: number;
  delta?: number; // rank movement since last snapshot
}

export type LeaderboardPeriod = 'daily' | 'weekly' | 'monthly' | 'alltime';

@Injectable()
export class LeaderboardService {
  private readonly logger = new Logger(LeaderboardService.name);
  // In-memory cache: key → { entries, computedAt }
  private cache = new Map<string, { entries: LeaderboardEntry[]; computedAt: Date }>();
  private readonly CACHE_TTL_MS = 5 * 60_000; // 5 minutes

  constructor(
    private prisma: PrismaService,
    private events: EventsGateway,
  ) {}

  /** Global leaderboard by XP, with optional period filter. */
  async getGlobal(
    period: LeaderboardPeriod = 'alltime',
    limit = 50,
    offset = 0,
  ): Promise<LeaderboardEntry[]> {
    const key = `global:${period}:${limit}:${offset}`;
    const cached = this.cache.get(key);
    if (cached && Date.now() - cached.computedAt.getTime() < this.CACHE_TTL_MS) {
      return cached.entries;
    }

    const since = this.periodStart(period);
    let entries: LeaderboardEntry[];

    if (period === 'alltime') {
      entries = await this.buildGlobalAllTime(limit, offset);
    } else {
      entries = await this.buildGlobalPeriod(since!, limit, offset);
    }

    this.cache.set(key, { entries, computedAt: new Date() });
    return entries;
  }

  /** Group leaderboard — all members ranked by XP. */
  async getGroup(groupId: string): Promise<LeaderboardEntry[]> {
    const key = `group:${groupId}`;
    const cached = this.cache.get(key);
    if (cached && Date.now() - cached.computedAt.getTime() < this.CACHE_TTL_MS) {
      return cached.entries;
    }

    const members = await this.prisma.groupMember.findMany({
      where: { groupId },
      include: {
        user: {
          select: {
            id: true, displayName: true, avatarUrl: true,
            profile: { select: { xp: true, level: true, rank: true, totalSolves: true, hardSolves: true } },
            streak: { select: { currentStreak: true } },
          },
        },
      },
    });

    const entries = members
      .map((m, i): LeaderboardEntry => ({
        rank: 0, // set below
        userId: m.userId,
        displayName: m.user.displayName,
        avatarUrl: m.user.avatarUrl,
        xp: m.user.profile?.xp ?? 0,
        level: m.user.profile?.level ?? 1,
        rankBadge: m.user.profile?.rank ?? 'INITIATE',
        totalSolves: m.user.profile?.totalSolves ?? 0,
        hardSolves: m.user.profile?.hardSolves ?? 0,
        currentStreak: m.user.streak?.currentStreak ?? 0,
      }))
      .sort((a, b) => b.xp - a.xp)
      .map((e, i) => ({ ...e, rank: i + 1 }));

    this.cache.set(key, { entries, computedAt: new Date() });
    return entries;
  }

  /** Friends-only leaderboard. */
  async getFriends(userId: string): Promise<LeaderboardEntry[]> {
    const friendships = await this.prisma.friendship.findMany({
      where: { OR: [{ userAId: userId }, { userBId: userId }] },
    });
    const friendIds = friendships.map((f) =>
      f.userAId === userId ? f.userBId : f.userAId,
    );
    const allIds = [userId, ...friendIds];

    const users = await this.prisma.user.findMany({
      where: { id: { in: allIds } },
      select: {
        id: true, displayName: true, avatarUrl: true,
        profile: { select: { xp: true, level: true, rank: true, totalSolves: true, hardSolves: true } },
        streak: { select: { currentStreak: true } },
      },
    });

    return users
      .map((u): LeaderboardEntry => ({
        rank: 0,
        userId: u.id,
        displayName: u.displayName,
        avatarUrl: u.avatarUrl,
        xp: u.profile?.xp ?? 0,
        level: u.profile?.level ?? 1,
        rankBadge: u.profile?.rank ?? 'INITIATE',
        totalSolves: u.profile?.totalSolves ?? 0,
        hardSolves: u.profile?.hardSolves ?? 0,
        currentStreak: u.streak?.currentStreak ?? 0,
      }))
      .sort((a, b) => b.xp - a.xp)
      .map((e, i) => ({ ...e, rank: i + 1 }));
  }

  /** Invalidate cache for a group after a new solve. */
  invalidateGroup(groupId: string): void {
    this.cache.delete(`group:${groupId}`);
  }

  invalidateGlobal(): void {
    for (const key of this.cache.keys()) {
      if (key.startsWith('global:')) this.cache.delete(key);
    }
  }

  /** Scheduled refresh + broadcast to active groups. */
  @Cron(CronExpression.EVERY_5_MINUTES)
  async refreshAndBroadcast(): Promise<void> {
    this.invalidateGlobal();
    // Pre-warm top 50 all-time
    await this.getGlobal('alltime', 50, 0);

    // Broadcast to group rooms
    const groups = await this.prisma.group.findMany({ select: { id: true } });
    for (const g of groups) {
      this.invalidateGroup(g.id);
      const entries = await this.getGroup(g.id);
      this.events.emitToGroup(g.id, WS_EVENTS.LEADERBOARD_CHANGED, {
        groupId: g.id, entries: entries.slice(0, 10),
      });
    }
  }

  // ── Private builders ──────────────────────────────────────────────

  private async buildGlobalAllTime(limit: number, offset: number): Promise<LeaderboardEntry[]> {
    const profiles = await this.prisma.userProfile.findMany({
      orderBy: { xp: 'desc' },
      take: limit,
      skip: offset,
      include: {
        user: { select: { id: true, displayName: true, avatarUrl: true, streak: { select: { currentStreak: true } } } },
      },
    });

    return profiles.map((p, i): LeaderboardEntry => ({
      rank: offset + i + 1,
      userId: p.userId,
      displayName: p.user.displayName,
      avatarUrl: p.user.avatarUrl,
      xp: p.xp,
      level: p.level,
      rankBadge: p.rank,
      totalSolves: p.totalSolves,
      hardSolves: p.hardSolves,
      currentStreak: p.user.streak?.currentStreak ?? 0,
    }));
  }

  private async buildGlobalPeriod(
    since: Date,
    limit: number,
    offset: number,
  ): Promise<LeaderboardEntry[]> {
    // Aggregate XP from solves in the period
    const solveAggregates = await this.prisma.solve.groupBy({
      by: ['userId'],
      where: { solvedAt: { gte: since } },
      _count: { id: true },
      orderBy: { _count: { id: 'desc' } },
      take: limit,
      skip: offset,
    });

    const userIds = solveAggregates.map((s) => s.userId);
    const users = await this.prisma.user.findMany({
      where: { id: { in: userIds } },
      select: {
        id: true, displayName: true, avatarUrl: true,
        profile: { select: { xp: true, level: true, rank: true, hardSolves: true } },
        streak: { select: { currentStreak: true } },
      },
    });

    const userMap = new Map(users.map((u) => [u.id, u]));

    return solveAggregates.map((agg, i): LeaderboardEntry => {
      const u = userMap.get(agg.userId);
      return {
        rank: offset + i + 1,
        userId: agg.userId,
        displayName: u?.displayName ?? '—',
        avatarUrl: u?.avatarUrl ?? null,
        xp: agg._count.id * 25, // approximate XP for period
        level: u?.profile?.level ?? 1,
        rankBadge: u?.profile?.rank ?? 'INITIATE',
        totalSolves: agg._count.id,
        hardSolves: u?.profile?.hardSolves ?? 0,
        currentStreak: u?.streak?.currentStreak ?? 0,
      };
    });
  }

  private periodStart(period: LeaderboardPeriod): Date | null {
    const now = new Date();
    if (period === 'daily') { now.setHours(0, 0, 0, 0); return now; }
    if (period === 'weekly') { now.setDate(now.getDate() - 7); return now; }
    if (period === 'monthly') { now.setDate(now.getDate() - 30); return now; }
    return null;
  }
}
