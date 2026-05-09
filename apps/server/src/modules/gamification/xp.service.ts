import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../core/prisma/prisma.service';
import { EventsGateway, WS_EVENTS } from '../../core/events/events.gateway';
import {
  XP_REWARDS, levelForXP, levelProgress, rankForXP,
  ACHIEVEMENTS, AchievementStats,
} from './gamification.config';
import { Rank } from '@prisma/client';

@Injectable()
export class XPService {
  private readonly logger = new Logger(XPService.name);

  constructor(
    private prisma: PrismaService,
    private events: EventsGateway,
  ) {}

  /**
   * Award XP for a completed solve.
   * Handles streak bonus, level-up detection, rank promotion, achievement check.
   */
  async awardSolveXP(
    userId: string,
    difficulty: 'EASY' | 'MEDIUM' | 'HARD',
    isFirstOfDay: boolean,
  ): Promise<void> {
    const profile = await this.prisma.userProfile.findUnique({
      where: { userId },
      select: { xp: true, level: true, rank: true },
    });
    const streak = await this.prisma.streak.findUnique({
      where: { userId },
      select: { currentStreak: true },
    });

    const baseXP = XP_REWARDS[difficulty];
    const streakBonus = this.calcStreakBonus(baseXP, streak?.currentStreak ?? 0);
    const firstDayBonus = isFirstOfDay ? XP_REWARDS.FIRST_SOLVE_OF_DAY : 0;
    const totalXP = baseXP + streakBonus + firstDayBonus;

    await this.applyXP(userId, totalXP, profile?.xp ?? 0, profile?.level ?? 1, profile?.rank ?? 'INITIATE');
  }

  /** Award flat XP (for achievements, challenges, etc.) */
  async awardBonusXP(userId: string, amount: number, reason: string): Promise<void> {
    const profile = await this.prisma.userProfile.findUnique({
      where: { userId },
      select: { xp: true, level: true, rank: true },
    });
    await this.applyXP(userId, amount, profile?.xp ?? 0, profile?.level ?? 1, profile?.rank ?? 'INITIATE', reason);
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

  private async applyXP(
    userId: string,
    amount: number,
    currentXP: number,
    currentLevel: number,
    currentRank: Rank,
    reason = 'solve',
  ): Promise<void> {
    const newXP = currentXP + amount;
    const newLevel = levelForXP(newXP);
    const newRank = rankForXP(newXP);

    await this.prisma.userProfile.update({
      where: { userId },
      data: { xp: newXP, level: newLevel, rank: newRank },
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
