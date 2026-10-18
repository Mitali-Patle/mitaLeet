import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import { Difficulty, Prisma } from '@prisma/client';
import { PrismaService } from '../../core/prisma/prisma.service';
import { LeetCodeClient, LeetCodeSubmission } from './leetcode.client';
import { StreakService } from './streak.service';
import { EventsGateway, WS_EVENTS } from '../../core/events/events.gateway';
import { dateFromKey, getUserTimeZone, localDateKey, startOfLocalDay } from '../../common/time/user-day';

/** A solve that was just recorded from LeetCode's own accepted-submission list. */
export interface VerifiedSolve {
  problemSlug: string;
  problemName: string;
  difficulty: Difficulty;
  language: string;
  solvedAt: Date;
}

export interface NewSolvesEvent {
  userId: string;
  solves: VerifiedSolve[];
}

type NewSolvesListener = (event: NewSolvesEvent) => Promise<void>;

/**
 * The only writer of Solve rows. Every solve comes from LeetCode's
 * recentAcSubmissionList for the user's verified account, never from a client
 * claim. Other modules (XP, races, challenges) react through onNewSolves().
 */
@Injectable()
export class SyncService implements OnModuleDestroy {
  private readonly logger = new Logger(SyncService.name);
  private readonly MAX_CONCURRENT = 5;
  private activeSyncs = 0;
  private readonly listeners: NewSolvesListener[] = [];

  /** Per-user throttle for on-demand verification, to stay polite to LeetCode. */
  private readonly lastQuickSync = new Map<string, number>();
  private readonly quickSyncIntervalMs: number;
  /** Background sync jobs still running; awaited on shutdown. */
  private readonly runningJobs = new Set<Promise<void>>();
  /** Concurrent callers for the same user share one LeetCode round-trip. */
  private readonly inFlight = new Map<string, Promise<VerifiedSolve[]>>();

  constructor(
    private prisma: PrismaService,
    private leetcode: LeetCodeClient,
    private streakService: StreakService,
    private events: EventsGateway,
    config: ConfigService,
  ) {
    this.quickSyncIntervalMs = Number(config.get('LEETCODE_QUICK_SYNC_INTERVAL_MS', 15_000));
  }

  /** Subscribe to newly recorded verified solves. */
  onNewSolves(listener: NewSolvesListener): void {
    this.listeners.push(listener);
  }

  /** Queue and process a sync job for a user. */
  async triggerSync(userId: string, type = 'leetcode_sync') {
    const job = await this.prisma.syncJob.create({
      data: { userId, type, status: 'PENDING' },
    });
    const run = this.processSyncJob(job.id, userId)
      .catch((err) => this.logger.error(`Sync ${job.id} crashed: ${err}`))
      .finally(() => this.runningJobs.delete(run));
    this.runningJobs.add(run);
    return job;
  }

  /** On shutdown (deploys send SIGTERM) let in-flight syncs finish, up to 10s. */
  async onModuleDestroy() {
    if (this.runningJobs.size === 0) return;
    this.logger.log(`Waiting for ${this.runningJobs.size} sync job(s) to finish`);
    await Promise.race([
      Promise.allSettled([...this.runningJobs]),
      new Promise((r) => setTimeout(r, 10_000)),
    ]);
  }

  /**
   * Fetch the user's latest accepted submissions from LeetCode and record any
   * new ones. Throttled per user; returns the solves that were newly recorded.
   */
  async syncRecent(userId: string): Promise<VerifiedSolve[]> {
    const running = this.inFlight.get(userId);
    if (running) return running;

    const job = this.doSyncRecent(userId).finally(() => this.inFlight.delete(userId));
    this.inFlight.set(userId, job);
    return job;
  }

  private async doSyncRecent(userId: string): Promise<VerifiedSolve[]> {
    const last = this.lastQuickSync.get(userId) ?? 0;
    if (Date.now() - last < this.quickSyncIntervalMs) return [];
    this.lastQuickSync.set(userId, Date.now());

    const username = await this.verifiedUsername(userId);
    if (!username) return [];

    const submissions = await this.leetcode.fetchRecentSubmissions(username, 20);
    return this.ingestAndPublish(userId, submissions);
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

  /** Hourly: break streaks of users whose own midnight has passed without a solve. */
  @Cron(CronExpression.EVERY_HOUR)
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

      const username = await this.verifiedUsername(userId);
      if (!username) {
        await this.failJob(jobId, 'No verified LeetCode username linked');
        return;
      }

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

      // 2. Ingest submissions (streak, daily counters, activities, listeners)
      const submissions = await this.leetcode.fetchRecentSubmissions(username, 50);
      const newSolves = await this.ingestAndPublish(userId, submissions);

      // 3. Complete
      await this.prisma.syncJob.update({
        where: { id: jobId },
        data: {
          status: 'COMPLETED',
          completedAt: new Date(),
          result: { newSolves: newSolves.length, totalFetched: submissions.length },
        },
      });
      await this.prisma.userProfile.update({
        where: { userId },
        data: { lastSyncAt: new Date() },
      });

      this.events.emitToUser(userId, WS_EVENTS.STREAK_UPDATE, {
        type: 'SYNC_COMPLETED',
        newSolves: newSolves.length,
      });

      this.logger.log(`Sync done [${userId}]: ${newSolves.length} new solves`);
    } catch (err) {
      await this.failJob(jobId, String(err));
    } finally {
      this.activeSyncs--;
    }
  }

  /** Record new submissions, update streak + daily counters, then notify. */
  private async ingestAndPublish(
    userId: string,
    submissions: LeetCodeSubmission[],
  ): Promise<VerifiedSolve[]> {
    const tz = await getUserTimeZone(this.prisma, userId);
    const { newSolves, hasTodaySolve, mostRecentSolveAt } = await this.ingestSubmissions(userId, submissions, tz);

    // Only fire recordSolve for genuine today-solves.
    // Historical back-fills (first sync) must not mark today as solved.
    if (hasTodaySolve) {
      await this.streakService.recordSolve(userId);
    } else if (newSolves.length > 0 && mostRecentSolveAt) {
      // First-time sync: anchor lastSolveDate to the actual most recent solve
      // so streak continuity is correct going forward.
      await this.streakService.anchorLastSolveDate(userId, mostRecentSolveAt);
    }

    await this.updateDailySolves(userId, tz);

    if (newSolves.length > 0) {
      await this.emitActivities(userId, newSolves);
      for (const listener of this.listeners) {
        await listener({ userId, solves: newSolves }).catch((err) =>
          this.logger.error(`New-solves listener failed for ${userId}: ${err}`),
        );
      }
    }
    return newSolves;
  }

  private async ingestSubmissions(userId: string, subs: LeetCodeSubmission[], tz: string) {
    const newSolves: VerifiedSolve[] = [];
    let hasTodaySolve = false;
    let mostRecentSolveAt: Date | null = null;

    const todayStart = startOfLocalDay(new Date(), tz);

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
        const difficulty = problem?.difficulty ?? 'MEDIUM';
        const created = await this.prisma.solve.create({
          data: {
            userId,
            problemSlug: sub.slug,
            problemName: sub.title,
            difficulty,
            language: sub.language,
            runtime: sub.runtime,
            memory: sub.memory,
            solvedAt,
            source: 'sync',
            problemId: problem?.id,
          },
        }).catch((err) => {
          // Another sync recorded this exact submission first.
          if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') return null;
          throw err;
        });
        if (!created) continue;
        newSolves.push({
          problemSlug: sub.slug,
          problemName: sub.title,
          difficulty,
          language: sub.language,
          solvedAt,
        });

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

  /** Today's counters, where "today" is the user's local calendar day. */
  private async updateDailySolves(userId: string, tz: string) {
    const now = new Date();
    const today = dateFromKey(localDateKey(now, tz));
    const solves = await this.prisma.solve.findMany({
      where: { userId, solvedAt: { gte: startOfLocalDay(now, tz) } },
    });
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

  private async emitActivities(userId: string, solves: VerifiedSolve[]) {
    const memberships = await this.prisma.groupMember.findMany({ where: { userId }, select: { groupId: true } });
    for (const solve of solves) {
      const activity = await this.prisma.activity.create({
        data: {
          userId,
          type: solve.difficulty === 'HARD' ? 'HARD_PROBLEM_SOLVED' : 'SOLVE',
          data: {
            problemSlug: solve.problemSlug,
            problemName: solve.problemName,
            difficulty: solve.difficulty,
            language: solve.language,
          },
        },
        include: { user: { select: { id: true, displayName: true, avatarUrl: true } } },
      });
      for (const { groupId } of memberships) {
        this.events.emitToGroup(groupId, WS_EVENTS.ACTIVITY_CREATED, activity);
      }
    }
  }

  private async verifiedUsername(userId: string): Promise<string | null> {
    const profile = await this.prisma.userProfile.findUnique({
      where: { userId },
      select: { leetcodeUsername: true, leetcodeVerified: true },
    });
    return profile?.leetcodeVerified && profile.leetcodeUsername ? profile.leetcodeUsername : null;
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
