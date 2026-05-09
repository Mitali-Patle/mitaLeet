import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../core/prisma/prisma.service';
import { StreakService } from './streak.service';
import { LeetCodeClient } from './leetcode.client';
import { XPService } from '../gamification/xp.service';
import { EventsGateway, WS_EVENTS } from '../../core/events/events.gateway';

@Injectable()
export class SolvesService {
  constructor(
    private prisma: PrismaService,
    private streakService: StreakService,
    private leetcode: LeetCodeClient,
    private xpService: XPService,
    private events: EventsGateway,
  ) {}

  /** Get recent solves for a user. */
  async getRecentSolves(userId: string, limit = 20) {
    return this.prisma.solve.findMany({
      where: { userId },
      orderBy: { solvedAt: 'desc' },
      take: limit,
      include: {
        problem: { select: { slug: true, difficulty: true, topicTags: true, acceptanceRate: true } },
      },
    });
  }

  /** Get solve stats breakdown. */
  async getStats(userId: string) {
    const [profile, streak, todaySolves] = await Promise.all([
      this.prisma.userProfile.findUnique({
        where: { userId },
        select: { xp: true, totalSolves: true, easySolves: true, mediumSolves: true, hardSolves: true },
      }),
      this.streakService.getStreak(userId),
      this.prisma.dailySolve.findFirst({
        where: { userId, date: { gte: this.todayStart() } },
      }),
    ]);

    return {
      profile,
      streak,
      today: todaySolves ?? { solveCount: 0, easyCount: 0, mediumCount: 0, hardCount: 0 },
    };
  }

  /** Get solve history heatmap data. */
  async getHeatmap(userId: string, days = 365) {
    return this.streakService.getDailySolves(userId, days);
  }

  /** Start a solve session (placeholder for extension integration). */
  async startSession(userId: string, problemSlug: string) {
    // Abandon any active sessions for same problem
    await this.prisma.solveSession.updateMany({
      where: { userId, problemSlug, status: 'active' },
      data: { status: 'abandoned', completedAt: new Date() },
    });

    return this.prisma.solveSession.create({
      data: { userId, problemSlug },
    });
  }

  /** Complete a solve session. */
  async completeSession(sessionId: string, userId: string) {
    const session = await this.prisma.solveSession.findFirst({
      where: { id: sessionId, userId, status: 'active' },
    });
    if (!session) return null;

    const durationMs = Date.now() - session.startedAt.getTime();
    return this.prisma.solveSession.update({
      where: { id: sessionId },
      data: { status: 'completed', completedAt: new Date(), durationMs },
    });
  }

  /** Get solve sessions. */
  async getSessions(userId: string, limit = 20) {
    return this.prisma.solveSession.findMany({
      where: { userId },
      orderBy: { startedAt: 'desc' },
      take: limit,
    });
  }

  /**
   * Record a solve submitted by the browser extension in real time.
   * Idempotent — skips if a matching solve already exists within a 5-minute window.
   */
  async extensionSolve(
    userId: string,
    problemSlug: string,
    language: string,
    solvedAt: Date,
  ): Promise<{ created: boolean }> {
    await this.ensureProblem(problemSlug);

    const windowMs = 5 * 60 * 1000;
    const duplicate = await this.prisma.solve.findFirst({
      where: {
        userId,
        problemSlug,
        solvedAt: {
          gte: new Date(solvedAt.getTime() - windowMs),
          lte: new Date(solvedAt.getTime() + windowMs),
        },
      },
    });
    if (duplicate) return { created: false };

    const problem = await this.prisma.problem.findUnique({ where: { slug: problemSlug } });
    const difficulty = (problem?.difficulty ?? 'MEDIUM') as 'EASY' | 'MEDIUM' | 'HARD';

    await this.prisma.solve.create({
      data: {
        userId,
        problemSlug,
        problemName: problem?.title ?? problemSlug,
        difficulty,
        language,
        solvedAt,
        source: 'extension',
        problemId: problem?.id,
      },
    });

    await this.updateDailySolves(userId);
    await this.streakService.recordSolve(userId);

    const today = this.todayStart();
    const todayCount = await this.prisma.solve.count({
      where: { userId, solvedAt: { gte: today } },
    });
    await this.xpService.awardSolveXP(userId, difficulty, todayCount === 1);

    const activity = await this.prisma.activity.create({
      data: {
        userId,
        type: difficulty === 'HARD' ? 'HARD_PROBLEM_SOLVED' : 'SOLVE',
        data: { problemSlug, problemName: problem?.title ?? problemSlug, difficulty, language, source: 'extension' } as any,
      },
    });
    const memberships = await this.prisma.groupMember.findMany({
      where: { userId },
      select: { groupId: true },
    });
    for (const { groupId } of memberships) {
      this.events.emitToGroup(groupId, WS_EVENTS.ACTIVITY_CREATED, activity);
    }

    return { created: true };
  }

  private async ensureProblem(slug: string) {
    const exists = await this.prisma.problem.findUnique({ where: { slug } });
    if (exists) return;
    const data = await this.leetcode.fetchProblem(slug);
    if (data) {
      await this.prisma.problem.upsert({
        where: { slug },
        update: { title: data.title, acceptanceRate: data.acceptanceRate, topicTags: data.topicTags },
        create: { slug: data.slug, title: data.title, difficulty: data.difficulty, acceptanceRate: data.acceptanceRate, isPremium: data.isPremium, topicTags: data.topicTags },
      });
    } else {
      await this.prisma.problem.upsert({
        where: { slug },
        update: {},
        create: { slug, title: slug, difficulty: 'MEDIUM' },
      });
    }
  }

  private async updateDailySolves(userId: string) {
    const today = this.todayStart();
    const solves = await this.prisma.solve.findMany({ where: { userId, solvedAt: { gte: today } } });
    if (!solves.length) return;
    await this.prisma.dailySolve.upsert({
      where: { userId_date: { userId, date: today } },
      update: {
        solveCount: solves.length,
        easyCount: solves.filter((s) => s.difficulty === 'EASY').length,
        mediumCount: solves.filter((s) => s.difficulty === 'MEDIUM').length,
        hardCount: solves.filter((s) => s.difficulty === 'HARD').length,
      },
      create: {
        userId,
        date: today,
        solveCount: solves.length,
        easyCount: solves.filter((s) => s.difficulty === 'EASY').length,
        mediumCount: solves.filter((s) => s.difficulty === 'MEDIUM').length,
        hardCount: solves.filter((s) => s.difficulty === 'HARD').length,
      },
    });
  }

  private todayStart() {
    const d = new Date(); d.setHours(0, 0, 0, 0); return d;
  }
}
