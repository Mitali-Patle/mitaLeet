import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../core/prisma/prisma.service';
import { StreakService } from './streak.service';

@Injectable()
export class SolvesService {
  constructor(
    private prisma: PrismaService,
    private streakService: StreakService,
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

  private todayStart() {
    const d = new Date(); d.setHours(0, 0, 0, 0); return d;
  }
}
