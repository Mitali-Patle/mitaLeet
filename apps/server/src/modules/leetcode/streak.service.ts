import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../core/prisma/prisma.service';
import { EventsGateway, WS_EVENTS } from '../../core/events/events.gateway';
import { addDaysToKey, dateFromKey, getUserTimeZone, localDateKey } from '../../common/time/user-day';

@Injectable()
export class StreakService {
  private readonly logger = new Logger(StreakService.name);

  constructor(
    private prisma: PrismaService,
    private events: EventsGateway,
  ) {}

  /**
   * Record a solve for streak purposes.
   * Days are the user's own calendar days (UserProfile.timezone).
   */
  async recordSolve(userId: string): Promise<void> {
    const [streak, tz] = await Promise.all([this.getOrCreate(userId), getUserTimeZone(this.prisma, userId)]);
    const now = new Date();
    const today = localDateKey(now, tz);
    const lastDate = streak.lastSolveDate
      ? localDateKey(streak.lastSolveDate, tz)
      : null;

    // Already solved today — no-op
    if (lastDate && lastDate >= today) return;

    const yesterday = addDaysToKey(today, -1);
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

    const tz = await getUserTimeZone(this.prisma, userId);
    const yesterday = addDaysToKey(localDateKey(new Date(), tz), -1);
    const lastDate = streak.lastSolveDate
      ? localDateKey(streak.lastSolveDate, tz)
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

  /**
   * Anchor lastSolveDate to an actual past solve date without touching streak
   * counters. Used on first sync so the streak logic has a real baseline to
   * work from, without falsely marking today as solved.
   */
  async anchorLastSolveDate(userId: string, date: Date): Promise<void> {
    const streak = await this.getOrCreate(userId);
    // Only update if there is no existing lastSolveDate (true first sync),
    // or if the real solve date is more recent than what's stored.
    if (!streak.lastSolveDate || date > streak.lastSolveDate) {
      await this.prisma.streak.update({
        where: { userId },
        data: { lastSolveDate: date },
      });
    }
  }

  /** Get full streak info. */
  async getStreak(userId: string) {
    const [streak, tz] = await Promise.all([this.getOrCreate(userId), getUserTimeZone(this.prisma, userId)]);
    const today = localDateKey(new Date(), tz);
    const lastDate = streak.lastSolveDate
      ? localDateKey(streak.lastSolveDate, tz)
      : null;

    return {
      ...streak,
      isSolvedToday: lastDate === today,
      daysUntilLoss: lastDate === today ? 1 : 0,
    };
  }

  /** Get last N days of daily solve data for heatmap. */
  async getDailySolves(userId: string, days = 90) {
    const tz = await getUserTimeZone(this.prisma, userId);
    const since = dateFromKey(addDaysToKey(localDateKey(new Date(), tz), -days));

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
}
