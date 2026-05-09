import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../core/prisma/prisma.service';

export interface SolveAnalytics {
  totalSolves: number;
  byDifficulty: { easy: number; medium: number; hard: number };
  byLanguage: Record<string, number>;
  topTopics: { tag: string; count: number }[];
  weakTopics: { tag: string; count: number }[];
  recentTrend: { date: string; count: number }[];
  avgSolveHour: number;
}

export interface Insight {
  id: string;
  type: 'strength' | 'weakness' | 'pattern' | 'recommendation';
  title: string;
  body: string;
  metric?: string;
}

@Injectable()
export class AnalyticsService {
  private readonly logger = new Logger(AnalyticsService.name);

  constructor(private prisma: PrismaService) {}

  /** Full analytics payload for a user. */
  async getUserAnalytics(userId: string): Promise<SolveAnalytics> {
    const [solves, dailySolves, profile] = await Promise.all([
      this.prisma.solve.findMany({
        where: { userId },
        select: {
          difficulty: true, language: true, solvedAt: true,
          problem: { select: { topicTags: true } },
        },
        orderBy: { solvedAt: 'desc' },
      }),
      this.prisma.dailySolve.findMany({
        where: { userId, date: { gte: new Date(Date.now() - 90 * 86_400_000) } },
        orderBy: { date: 'asc' },
        select: { date: true, solveCount: true },
      }),
      this.prisma.userProfile.findUnique({
        where: { userId },
        select: { easySolves: true, mediumSolves: true, hardSolves: true },
      }),
    ]);

    // Language distribution
    const byLanguage: Record<string, number> = {};
    for (const s of solves) {
      byLanguage[s.language] = (byLanguage[s.language] ?? 0) + 1;
    }

    // Topic distribution
    const topicCounts: Record<string, number> = {};
    for (const s of solves) {
      for (const tag of s.problem?.topicTags ?? []) {
        topicCounts[tag] = (topicCounts[tag] ?? 0) + 1;
      }
    }
    const sortedTopics = Object.entries(topicCounts)
      .map(([tag, count]) => ({ tag, count }))
      .sort((a, b) => b.count - a.count);

    // Hour distribution
    const hourCounts = new Array(24).fill(0);
    for (const s of solves) {
      hourCounts[new Date(s.solvedAt).getHours()]++;
    }
    const avgSolveHour = hourCounts.indexOf(Math.max(...hourCounts));

    // 30-day trend
    const recentTrend = dailySolves.slice(-30).map((d) => ({
      date: d.date.toISOString().split('T')[0],
      count: d.solveCount,
    }));

    return {
      totalSolves: solves.length,
      byDifficulty: {
        easy: profile?.easySolves ?? 0,
        medium: profile?.mediumSolves ?? 0,
        hard: profile?.hardSolves ?? 0,
      },
      byLanguage,
      topTopics: sortedTopics.slice(0, 5),
      weakTopics: sortedTopics.slice(-5).reverse(),
      recentTrend,
      avgSolveHour,
    };
  }

  /** Generate smart insights for a user. */
  async getInsights(userId: string): Promise<Insight[]> {
    const analytics = await this.getUserAnalytics(userId);
    const insights: Insight[] = [];

    const { byDifficulty, topTopics, weakTopics, avgSolveHour, totalSolves, recentTrend } = analytics;
    const total = byDifficulty.easy + byDifficulty.medium + byDifficulty.hard;

    // Difficulty bias
    if (total > 10) {
      const hardRatio = byDifficulty.hard / total;
      if (hardRatio > 0.3) {
        insights.push({
          id: 'hard_solver', type: 'strength',
          title: 'Hard Problem Specialist',
          body: `${Math.round(hardRatio * 100)}% of your solves are HARD — top-tier difficulty ratio.`,
          metric: `${byDifficulty.hard} hard`,
        });
      } else if (hardRatio < 0.05 && total > 20) {
        insights.push({
          id: 'try_hard', type: 'recommendation',
          title: 'Push Harder',
          body: 'Less than 5% hard problems. Attempting harder problems accelerates growth.',
          metric: `${byDifficulty.hard} hard / ${total} total`,
        });
      }
    }

    // Top topic strength
    if (topTopics.length > 0) {
      const top = topTopics[0];
      insights.push({
        id: `strength_${top.tag}`, type: 'strength',
        title: `Strong in ${top.tag.replace(/-/g, ' ').toUpperCase()}`,
        body: `Your most-solved topic with ${top.count} problems. This is a clear strength.`,
        metric: `${top.count} solves`,
      });
    }

    // Weak topic
    if (weakTopics.length > 0 && weakTopics[0].count < 3) {
      const weak = weakTopics[0];
      insights.push({
        id: `weakness_${weak.tag}`, type: 'weakness',
        title: `Low Exposure: ${weak.tag.replace(/-/g, ' ').toUpperCase()}`,
        body: `Only ${weak.count} problem${weak.count !== 1 ? 's' : ''} solved in this topic. Consider focusing here.`,
        metric: `${weak.count} solved`,
      });
    }

    // Peak hour
    const hourLabel = avgSolveHour < 12
      ? 'morning'
      : avgSolveHour < 17 ? 'afternoon' : avgSolveHour < 21 ? 'evening' : 'night';
    insights.push({
      id: 'peak_hour', type: 'pattern',
      title: `Peak Productivity: ${hourLabel.toUpperCase()}`,
      body: `Most of your solves happen in the ${hourLabel} (around ${avgSolveHour}:00). Schedule hard problems then.`,
      metric: `~${avgSolveHour}:00`,
    });

    // Trend analysis
    if (recentTrend.length >= 7) {
      const lastWeek = recentTrend.slice(-7).reduce((s, d) => s + d.count, 0);
      const prevWeek = recentTrend.slice(-14, -7).reduce((s, d) => s + d.count, 0);
      if (lastWeek > prevWeek && prevWeek > 0) {
        insights.push({
          id: 'trend_up', type: 'pattern',
          title: 'Momentum Building',
          body: `+${lastWeek - prevWeek} more solves this week vs last week. Keep the pressure up.`,
          metric: `${lastWeek} this week`,
        });
      } else if (lastWeek < prevWeek && lastWeek < 3) {
        insights.push({
          id: 'trend_down', type: 'recommendation',
          title: 'Activity Drop Detected',
          body: `Down from ${prevWeek} to ${lastWeek} solves this week. Consistency is the edge.`,
          metric: `${lastWeek} this week`,
        });
      }
    }

    return insights;
  }
}
