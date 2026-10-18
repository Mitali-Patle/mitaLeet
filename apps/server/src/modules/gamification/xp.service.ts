import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../../core/prisma/prisma.service';
import { EventsGateway, WS_EVENTS } from '../../core/events/events.gateway';
import { NewSolvesEvent, SyncService } from '../leetcode/sync.service';
import {
  XP_REWARDS, levelForXP, levelProgress, rankForXP,
  ACHIEVEMENTS, AchievementStats,
} from './gamification.config';

/**
 * The single authority for XP. Solve XP is only ever awarded here, in
 * response to solves the sync pipeline verified against LeetCode.
 */
@Injectable()
export class XPService implements OnModuleInit {
  private readonly logger = new Logger(XPService.name);

  constructor(
    private prisma: PrismaService,
    private events: EventsGateway,
    private sync: SyncService,
  ) {}

  onModuleInit() {
    this.sync.onNewSolves((event) => this.awardForVerifiedSolves(event));
  }

  /**
   * Today's solves earn full solve XP (streak + first-of-day bonuses);
   * older solves imported on first link earn base XP only, in one award.
   */
  async awardForVerifiedSolves({ userId, solves }: NewSolvesEvent): Promise<void> {
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const older = solves.filter((s) => s.solvedAt < todayStart);
    const today = solves
      .filter((s) => s.solvedAt >= todayStart)
      .sort((a, b) => a.solvedAt.getTime() - b.solvedAt.getTime());

    if (older.length > 0) {
      const historyXP = older.reduce((t, s) => t + XP_REWARDS[s.difficulty], 0);
      await this.awardBonusXP(userId, historyXP, 'solve_history');
    }

    if (today.length > 0) {
      const solvedTodayBefore =
        (await this.prisma.solve.count({ where: { userId, solvedAt: { gte: todayStart } } })) - today.length;
      for (const [i, solve] of today.entries()) {
        await this.awardSolveXP(userId, solve.difficulty, solvedTodayBefore === 0 && i === 0);
      }
    }
  }

  /**
   * Award XP for a completed solve.
   * Handles streak bonus, level-up detection, rank promotion, achievement check.
   */
  async awardSolveXP(
    userId: string,
    difficulty: 'EASY' | 'MEDIUM' | 'HARD',
    isFirstOfDay: boolean,
  ): Promise<void> {
    const streak = await this.prisma.streak.findUnique({
      where: { userId },
      select: { currentStreak: true },
    });

    const baseXP = XP_REWARDS[difficulty];
    const streakBonus = this.calcStreakBonus(baseXP, streak?.currentStreak ?? 0);
    const firstDayBonus = isFirstOfDay ? XP_REWARDS.FIRST_SOLVE_OF_DAY : 0;
    const totalXP = baseXP + streakBonus + firstDayBonus;

    await this.applyXP(userId, totalXP);
  }

  /** Award flat XP (for achievements, challenges, etc.) */
  async awardBonusXP(userId: string, amount: number, reason: string): Promise<void> {
    await this.applyXP(userId, amount, reason);
  }

  /** Get full progression data for a user. */
  async getProgression(userId: string) {
    const profile = await this.prisma.userProfile.findUnique({
      where: { userId },
      select: { xp: true, level: true, rank: true },
    });
    const xp = profile?.xp ?? 0;
    return {
      xp,
      rank: profile?.rank ?? 'INITIATE',
      ...levelProgress(xp),
    };
  }

  // ── Private ─────────────────────────────────────────────────────

  private async applyXP(userId: string, amount: number, reason = 'solve'): Promise<void> {
    if (amount <= 0) return;

    // Atomic increment: concurrent awards can no longer overwrite each other.
    const { newXP, newLevel, newRank, currentLevel, currentRank } =
      await this.prisma.$transaction(async (tx) => {
        const updated = await tx.userProfile.update({
          where: { userId },
          data: { xp: { increment: amount } },
          select: { xp: true, level: true, rank: true },
        });
        const level = levelForXP(updated.xp);
        const rank = rankForXP(updated.xp);
        if (level !== updated.level || rank !== updated.rank) {
          await tx.userProfile.update({ where: { userId }, data: { level, rank } });
        }
        return {
          newXP: updated.xp, newLevel: level, newRank: rank,
          currentLevel: updated.level, currentRank: updated.rank,
        };
      });

    // Emit XP gained
    this.events.emitToUser(userId, WS_EVENTS.XP_GAINED, {
      xpGained: amount,
      totalXP: newXP,
      level: newLevel,
      rank: newRank,
      reason,
    });

    // Level-up event
    if (newLevel > currentLevel) {
      this.logger.log(`Level up [${userId}]: ${currentLevel} → ${newLevel}`);
      this.events.emitToUser(userId, WS_EVENTS.LEVEL_UP, {
        previousLevel: currentLevel,
        newLevel,
        rank: newRank,
        xp: newXP,
      });
      await this.prisma.activity.create({
        data: {
          userId, type: 'LEVEL_UP',
          data: { previousLevel: currentLevel, newLevel, rank: newRank },
        },
      });
    }

    // Rank-up event
    if (newRank !== currentRank) {
      this.logger.log(`Rank up [${userId}]: ${currentRank} → ${newRank}`);
      this.events.emitToUser(userId, WS_EVENTS.RANK_UPDATED, {
        previousRank: currentRank,
        newRank,
        xp: newXP,
      });
      await this.prisma.activity.create({
        data: {
          userId, type: 'RANK_CHANGED',
          data: { previousRank: currentRank, newRank },
        },
      });
    }

    // Check achievements after XP update
    await this.checkAchievements(userId);
  }

  private calcStreakBonus(baseXP: number, streak: number): number {
    const multiplier = Math.min(Math.floor(streak / 10) * 0.1, 1.0); // cap at 2x
    return Math.floor(baseXP * multiplier);
  }

  private async checkAchievements(userId: string): Promise<void> {
    const [profile, streak, achievements] = await Promise.all([
      this.prisma.userProfile.findUnique({
        where: { userId },
        select: { xp: true, level: true, totalSolves: true, hardSolves: true },
      }),
      this.prisma.streak.findUnique({
        where: { userId },
        select: { currentStreak: true, longestStreak: true },
      }),
      this.prisma.userAchievement.findMany({
        where: { userId },
        select: { key: true },
      }),
    ]);

    const unlockedKeys = new Set(achievements.map((a) => a.key));
    const stats: AchievementStats = {
      totalSolves: profile?.totalSolves ?? 0,
      hardSolves: profile?.hardSolves ?? 0,
      currentStreak: streak?.currentStreak ?? 0,
      longestStreak: streak?.longestStreak ?? 0,
      level: profile?.level ?? 1,
      xp: profile?.xp ?? 0,
    };

    for (const def of ACHIEVEMENTS) {
      if (unlockedKeys.has(def.key)) continue;
      if (!def.check(stats)) continue;

      // Unlock achievement
      await this.prisma.userAchievement.create({
        data: {
          userId,
          type: def.type as any,
          key: def.key,
          title: def.title,
          description: def.description,
          xpReward: def.xpReward,
        },
      });

      // Award XP (direct DB update to avoid recursion)
      await this.prisma.userProfile.update({
        where: { userId },
        data: { xp: { increment: def.xpReward } },
      });

      // Persist activity
      await this.prisma.activity.create({
        data: {
          userId, type: 'ACHIEVEMENT_UNLOCKED',
          data: { key: def.key, title: def.title, xpReward: def.xpReward },
        },
      });

      // Emit to user
      this.events.emitToUser(userId, WS_EVENTS.ACHIEVEMENT_UNLOCKED, {
        key: def.key,
        title: def.title,
        description: def.description,
        xpReward: def.xpReward,
        type: def.type,
      });

      this.logger.log(`Achievement unlocked [${userId}]: ${def.key}`);
    }
  }
}
