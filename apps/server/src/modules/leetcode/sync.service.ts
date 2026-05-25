import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../../core/prisma/prisma.service';
import { LeetCodeClient, LeetCodeSubmission } from './leetcode.client';
import { StreakService } from './streak.service';
import { EventsGateway, WS_EVENTS } from '../../core/events/events.gateway';

const XP_TABLE = { EASY: 10, MEDIUM: 25, HARD: 50 } as const;

@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);
  private readonly MAX_CONCURRENT = 5;
  private activeSyncs = 0;

  constructor(
    private prisma: PrismaService,
    private leetcode: LeetCodeClient,
    private streakService: StreakService,
    private events: EventsGateway,
  ) {}

  /** Queue and process a sync job for a user. */
  async triggerSync(userId: string, type = 'leetcode_sync') {
    const job = await this.prisma.syncJob.create({
      data: { userId, type, status: 'PENDING' },
    });
    this.processSyncJob(job.id, userId).catch((err) =>
      this.logger.error(`Sync ${job.id} crashed: ${err}`),
    );
    return job;
  }

  /** Every 30 min: sync all verified linked users. */
  @Cron(CronExpression.EVERY_30_MINUTES)
  async scheduledSync() {
    this.logger.log('[Cron] Scheduled sync starting');
    const users = await this.prisma.userProfile.findMany({
      where: { leetcodeUsername: { not: null }, leetcodeVerified: true },
      select: { userId: true },
    });
    for (const { userId } of users) {
      if (this.activeSyncs >= this.MAX_CONCURRENT) await this.waitForSlot();
      this.triggerSync(userId).catch(() => {});
    }
  }

  /** Midnight UTC: check for broken streaks. */
  @Cron('0 0 * * *')
  async dailyStreakCheck() {
    this.logger.log('[Cron] Daily streak check');
    const streaks = await this.prisma.streak.findMany({
      where: { currentStreak: { gt: 0 } },
      select: { userId: true },
    });
    for (const { userId } of streaks) {
      await this.streakService.checkAndUpdateStreak(userId);
    }
  }

  // ── Core sync ──────────────────────────────────────────────────

  private async processSyncJob(jobId: string, userId: string) {
    this.activeSyncs++;
    try {
      await this.prisma.syncJob.update({
        where: { id: jobId },
        data: { status: 'RUNNING', startedAt: new Date() },
      });

      const profile = await this.prisma.userProfile.findUnique({
        where: { userId },
        select: { leetcodeUsername: true },
      });
      if (!profile?.leetcodeUsername) {
        await this.failJob(jobId, 'No LeetCode username linked');
        return;
      }

      const username = profile.leetcodeUsername;

      // 1. Sync aggregate stats
      const lcProfile = await this.leetcode.fetchUserProfile(username);
      if (lcProfile) {
        await this.prisma.userProfile.update({
          where: { userId },
          data: {
            totalSolves: lcProfile.totalSolved,
            easySolves: lcProfile.easySolved,
            mediumSolves: lcProfile.mediumSolved,
            hardSolves: lcProfile.hardSolved,
          },
        });
      }

      // 2. Ingest submissions
      const submissions = await this.leetcode.fetchRecentSubmissions(username, 50);
      const { newSolves, hasTodaySolve, mostRecentSolveAt } = await this.ingestSubmissions(userId, submissions);

      // 3. Update streak — only fire recordSolve for genuine today-solves.
      // Historical back-fills (first sync) must not mark today as solved.
      if (hasTodaySolve) {
        await this.streakService.recordSolve(userId);
      } else if (newSolves > 0 && mostRecentSolveAt) {
        // First-time sync: anchor lastSolveDate to the actual most recent solve
        // so streak continuity is correct going forward.
        await this.streakService.anchorLastSolveDate(userId, mostRecentSolveAt);
      }

      // 4. Daily solve counters
      await this.updateDailySolves(userId);

      // 5. Recalculate XP
      await this.recalculateXP(userId);

      // 6. Complete
      await this.prisma.syncJob.update({
        where: { id: jobId },
        data: {
          status: 'COMPLETED',
          completedAt: new Date(),
          result: { newSolves, totalFetched: submissions.length },
        },
      });
      await this.prisma.userProfile.update({
        where: { userId },
        data: { lastSyncAt: new Date() },
      });

      // 7. Broadcast
      this.events.emitToUser(userId, WS_EVENTS.STREAK_UPDATE, {
        type: 'SYNC_COMPLETED',
        newSolves,
      });
      if (newSolves > 0) await this.emitActivities(userId, submissions.slice(0, newSolves));

      this.logger.log(`Sync done [${userId}]: ${newSolves} new solves`);
    } catch (err) {
      await this.failJob(jobId, String(err));
    } finally {
      this.activeSyncs--;
    }
  }

  private async ingestSubmissions(userId: string, subs: LeetCodeSubmission[]) {
    let newSolves = 0;
    let hasTodaySolve = false;
    let mostRecentSolveAt: Date | null = null;

    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    for (const sub of subs) {
      const solvedAt = new Date(sub.timestamp * 1000);
      await this.ensureProblem(sub.slug, sub.title);

      const exists = await this.prisma.solve.findFirst({
        where: {
          userId,
          problemSlug: sub.slug,
          solvedAt: {
            gte: new Date(solvedAt.getTime() - 60_000),
            lte: new Date(solvedAt.getTime() + 60_000),
          },
        },
      });
      if (!exists) {
        const problem = await this.prisma.problem.findUnique({ where: { slug: sub.slug } });
        await this.prisma.solve.create({
          data: {
            userId,
            problemSlug: sub.slug,
            problemName: sub.title,
            difficulty: problem?.difficulty ?? 'MEDIUM',
            language: sub.language,
            runtime: sub.runtime,
            memory: sub.memory,
            solvedAt,
            source: 'sync',
            problemId: problem?.id,
          },
        });
        newSolves++;

        // Track whether any new solve actually happened today.
        if (solvedAt >= todayStart) hasTodaySolve = true;

        // Track the most recent solve date across all new ingestions.
        if (!mostRecentSolveAt || solvedAt > mostRecentSolveAt) {
          mostRecentSolveAt = solvedAt;
        }
      }
    }
    return { newSolves, hasTodaySolve, mostRecentSolveAt };
  }

  private async ensureProblem(slug: string, title: string) {
    const exists = await this.prisma.problem.findUnique({ where: { slug } });
    if (exists) return;
    const data = await this.leetcode.fetchProblem(slug);
    if (data) {
      await this.prisma.problem.upsert({
        where: { slug },
        update: { title: data.title, acceptanceRate: data.acceptanceRate, topicTags: data.topicTags },
        create: {
          slug: data.slug, title: data.title, difficulty: data.difficulty,
          acceptanceRate: data.acceptanceRate, isPremium: data.isPremium, topicTags: data.topicTags,
        },
      });
    } else {
      await this.prisma.problem.upsert({
        where: { slug },
        update: {},
        create: { slug, title, difficulty: 'MEDIUM' },
      });
    }
  }

  private async updateDailySolves(userId: string) {
    const today = new Date(); today.setHours(0, 0, 0, 0);
    const solves = await this.prisma.solve.findMany({ where: { userId, solvedAt: { gte: today } } });
    if (!solves.length) return;
    await this.prisma.dailySolve.upsert({
      where: { userId_date: { userId, date: today } },
      update: {
        solveCount: solves.length,
        easyCount:   solves.filter((s) => s.difficulty === 'EASY').length,
        mediumCount: solves.filter((s) => s.difficulty === 'MEDIUM').length,
        hardCount:   solves.filter((s) => s.difficulty === 'HARD').length,
      },
      create: {
        userId, date: today,
        solveCount: solves.length,
        easyCount:   solves.filter((s) => s.difficulty === 'EASY').length,
        mediumCount: solves.filter((s) => s.difficulty === 'MEDIUM').length,
        hardCount:   solves.filter((s) => s.difficulty === 'HARD').length,
      },
    });
  }

  private async recalculateXP(userId: string) {
    const solves = await this.prisma.solve.findMany({ where: { userId }, select: { difficulty: true } });
    const xp = solves.reduce((t, s) => t + (XP_TABLE[s.difficulty] ?? 10), 0);
    await this.prisma.userProfile.update({ where: { userId }, data: { xp } });
  }

  private async emitActivities(userId: string, subs: LeetCodeSubmission[]) {
    for (const sub of subs) {
      const problem = await this.prisma.problem.findUnique({ where: { slug: sub.slug } });
      const activity = await this.prisma.activity.create({
        data: {
          userId,
          type: problem?.difficulty === 'HARD' ? 'HARD_PROBLEM_SOLVED' : 'SOLVE',
          data: { problemSlug: sub.slug, problemName: sub.title, difficulty: problem?.difficulty ?? 'MEDIUM', language: sub.language },
        },
        include: { user: { select: { id: true, displayName: true, avatarUrl: true } } },
      });
      const memberships = await this.prisma.groupMember.findMany({ where: { userId }, select: { groupId: true } });
      for (const { groupId } of memberships) {
        this.events.emitToGroup(groupId, WS_EVENTS.ACTIVITY_CREATED, activity);
      }
    }
  }

  private async failJob(jobId: string, error: string) {
    await this.prisma.syncJob.update({
      where: { id: jobId },
      data: { status: 'FAILED', completedAt: new Date(), error },
    });
  }

  private waitForSlot(): Promise<void> {
    return new Promise((resolve) => {
      const check = () =>
        this.activeSyncs < this.MAX_CONCURRENT ? resolve() : setTimeout(check, 500);
      check();
    });
  }
}
