import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../core/prisma/prisma.service';
import { EventsGateway, WS_EVENTS } from '../../core/events/events.gateway';

@Injectable()
export class StreakService {
  private readonly logger = new Logger(StreakService.name);

  constructor(
    private prisma: PrismaService,
    private events: EventsGateway,
  ) {}

  /**
   * Record a solve for streak purposes.
   * Timezone-aware: uses UTC date boundaries.
   */
  async recordSolve(userId: string): Promise<void> {
    const streak = await this.getOrCreate(userId);
    const now = new Date();
    const today = this.toDateOnly(now);
    const lastDate = streak.lastSolveDate
      ? this.toDateOnly(streak.lastSolveDate)
      : null;

    // Already solved today — no-op
    if (lastDate && lastDate === today) return;

    const yesterday = this.toDateOnly(new Date(now.getTime() - 86_400_000));
    let newStreak: number;
    let type: 'STREAK_EXTENDED' | 'STREAK_BROKEN' | null = null;

    if (lastDate === yesterday) {
      // Continuing streak
      newStreak = streak.currentStreak + 1;
      type = 'STREAK_EXTENDED';
    } else if (!lastDate) {
      // First ever solve
      newStreak = 1;
      type = 'STREAK_EXTENDED';
    } else {
      // Missed a day — reset
      newStreak = 1;
      type = 'STREAK_BROKEN';
    }

    const longestStreak = Math.max(streak.longestStreak, newStreak);

    await this.prisma.streak.update({
      where: { userId },
      data: { currentStreak: newStreak, longestStreak, lastSolveDate: now },
    });

    // Emit streak event
    this.events.emitToUser(userId, WS_EVENTS.STREAK_UPDATE, {
      currentStreak: newStreak,
      longestStreak,
      type,
    });

    // Persist activity
    await this.prisma.activity.create({
      data: {
        userId,
        type,
        data: { currentStreak: newStreak, longestStreak },
      },
    });

    this.logger.log(`Streak [${userId}]: ${newStreak} (${type})`);
  }

  /**
   * Called on daily reset — break streak if no solve yesterday.
   */
  async checkAndUpdateStreak(userId: string): Promise<void> {
    const streak = await this.prisma.streak.findUnique({ where: { userId } });
    if (!streak || streak.currentStreak === 0) return;

    const yesterday = this.toDateOnly(new Date(Date.now() - 86_400_000));
    const lastDate = streak.lastSolveDate
      ? this.toDateOnly(streak.lastSolveDate)
      : null;

    if (lastDate && lastDate < yesterday) {
      // Streak is broken
      const broken = streak.currentStreak;
      await this.prisma.streak.update({
        where: { userId },
        data: { currentStreak: 0 },
      });

      this.events.emitToUser(userId, WS_EVENTS.STREAK_UPDATE, {
        currentStreak: 0,
        longestStreak: streak.longestStreak,
        type: 'STREAK_BROKEN',
        previousStreak: broken,
      });

      await this.prisma.activity.create({
        data: {
          userId,
          type: 'STREAK_BROKEN',
          data: { previousStreak: broken },
        },
      });

      this.logger.log(`Streak broken [${userId}]: was ${broken}`);
    }
  }

  /** Get full streak info. */
  async getStreak(userId: string) {
    const streak = await this.getOrCreate(userId);
    const today = this.toDateOnly(new Date());
    const lastDate = streak.lastSolveDate
      ? this.toDateOnly(streak.lastSolveDate)
      : null;

    return {
      ...streak,
      isSolvedToday: lastDate === today,
      daysUntilLoss: lastDate === today ? 1 : 0,
    };
  }

  /** Get last N days of daily solve data for heatmap. */
  async getDailySolves(userId: string, days = 90) {
    const since = new Date();
    since.setDate(since.getDate() - days);
    since.setHours(0, 0, 0, 0);

    return this.prisma.dailySolve.findMany({
      where: { userId, date: { gte: since } },
      orderBy: { date: 'asc' },
    });
  }

  // ── Private ─────────────────────────────────────────────────────

  private async getOrCreate(userId: string) {
    const existing = await this.prisma.streak.findUnique({ where: { userId } });
    if (existing) return existing;
    return this.prisma.streak.create({ data: { userId } });
  }

  private toDateOnly(date: Date): string {
    return date.toISOString().split('T')[0]; // "YYYY-MM-DD"
  }
}
