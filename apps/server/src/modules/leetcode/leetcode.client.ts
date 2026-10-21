import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

const REQUEST_TIMEOUT_MS = 10_000;

/** Unofficial LeetCode GraphQL API client. */
@Injectable()
export class LeetCodeClient {
  private readonly logger = new Logger(LeetCodeClient.name);
  private readonly BASE: string;

  constructor(config: ConfigService) {
    this.BASE = config.get<string>('LEETCODE_GRAPHQL_URL', 'https://leetcode.com/graphql');
  }

  /** Validate that a LeetCode username exists. */
  async validateUsername(username: string): Promise<boolean> {
    try {
      const profile = await this.fetchUserProfile(username);
      return !!profile;
    } catch {
      return false;
    }
  }

  /** Fetch user profile stats from LeetCode. */
  async fetchUserProfile(username: string): Promise<LeetCodeProfile | null> {
    const query = `
      query userPublicProfile($username: String!) {
        matchedUser(username: $username) {
          username
          profile {
            realName
            ranking
            reputation
          }
          submitStatsGlobal {
            acSubmissionNum {
              difficulty
              count
            }
          }
        }
      }
    `;

    const data = await this.gql(query, { username });
    const user = data?.matchedUser;
    if (!user) return null;

    const stats = user.submitStatsGlobal?.acSubmissionNum ?? [];
    const findCount = (d: string) =>
      stats.find((s: any) => s.difficulty === d)?.count ?? 0;

    return {
      username: user.username,
      realName: user.profile?.realName,
      ranking: user.profile?.ranking,
      totalSolved: findCount('All'),
      easySolved: findCount('Easy'),
      mediumSolved: findCount('Medium'),
      hardSolved: findCount('Hard'),
    };
  }

  /**
   * Read the profile "About me" text, used to prove account ownership.
   * Returns null when the user does not exist (or LeetCode is unreachable).
   */
  async fetchProfileAboutMe(username: string): Promise<string | null> {
    const query = `
      query userAboutMe($username: String!) {
        matchedUser(username: $username) {
          profile { aboutMe }
        }
      }
    `;
    const data = await this.gql(query, { username });
    const user = data?.matchedUser;
    if (!user) return null;
    return user.profile?.aboutMe ?? '';
  }

  /** Fetch recent accepted submissions. */
  async fetchRecentSubmissions(
    username: string,
    limit = 20,
  ): Promise<LeetCodeSubmission[]> {
    const query = `
      query recentAcSubmissions($username: String!, $limit: Int!) {
        recentAcSubmissionList(username: $username, limit: $limit) {
          id
          title
          titleSlug
          timestamp
          lang
          runtime
          memory
        }
      }
    `;

    const data = await this.gql(query, { username, limit });
    const list = data?.recentAcSubmissionList ?? [];

    return list.map((s: any) => ({
      id: s.id,
      title: s.title,
      slug: s.titleSlug,
      timestamp: parseInt(s.timestamp, 10),
      language: s.lang,
      runtime: this.parseRuntime(s.runtime),
      memory: this.parseMemory(s.memory),
    }));
  }

  /** Fetch problem details for slug. */
  async fetchProblem(slug: string): Promise<LeetCodeProblem | null> {
    const query = `
      query questionData($titleSlug: String!) {
        question(titleSlug: $titleSlug) {
          questionId
          title
          titleSlug
          difficulty
          acRate
          isPaidOnly
          topicTags {
            slug
          }
        }
      }
    `;

    const data = await this.gql(query, { titleSlug: slug });
    const q = data?.question;
    if (!q) return null;

    return {
      id: q.questionId,
      title: q.title,
      slug: q.titleSlug,
      difficulty: q.difficulty?.toUpperCase() as 'EASY' | 'MEDIUM' | 'HARD',
      acceptanceRate: parseFloat(q.acRate) || null,
      isPremium: q.isPaidOnly ?? false,
      topicTags: (q.topicTags ?? []).map((t: any) => t.slug),
    };
  }

  /** Fetch user's solve calendar (daily activity). */
  async fetchSubmissionCalendar(
    username: string,
  ): Promise<Record<string, number>> {
    const query = `
      query userProfileCalendar($username: String!) {
        matchedUser(username: $username) {
          submissionCalendar
        }
      }
    `;

    const data = await this.gql(query, { username });
    const raw = data?.matchedUser?.submissionCalendar;
    if (!raw) return {};

    try {
      return JSON.parse(raw);
    } catch {
      return {};
    }
  }

  // ── GraphQL helper ─────────────────────────────────────────────

  private async gql(query: string, variables: Record<string, any>): Promise<any> {
    try {
      const res = await fetch(this.BASE, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Referer': 'https://leetcode.com',
          'User-Agent': 'mitaLeet/1.0',
        },
        body: JSON.stringify({ query, variables }),
        // A hung request would otherwise hold a sync slot indefinitely.
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      });

      if (!res.ok) {
        this.logger.warn(`LeetCode API ${res.status}: ${res.statusText}`);
        return null;
      }

      const json = await res.json();
      if (json.errors) {
        this.logger.warn(`LeetCode GraphQL error: ${JSON.stringify(json.errors)}`);
        return null;
      }

      return json.data;
    } catch (err) {
      this.logger.error(`LeetCode API error: ${err}`);
      return null;
    }
  }

  private parseRuntime(s: string): number | null {
    if (!s) return null;
    const n = parseInt(s.replace(/\D/g, ''), 10);
    return isNaN(n) ? null : n;
  }

  private parseMemory(s: string): number | null {
    if (!s) return null;
    const n = parseFloat(s.replace(/[^\d.]/g, ''));
    return isNaN(n) ? null : n;
  }
}

// ── Types ─────────────────────────────────────────────────────────

export interface LeetCodeProfile {
  username: string;
  realName?: string;
  ranking?: number;
  totalSolved: number;
  easySolved: number;
  mediumSolved: number;
  hardSolved: number;
}

export interface LeetCodeSubmission {
  id: string;
  title: string;
  slug: string;
  timestamp: number;
  language: string;
  runtime: number | null;
  memory: number | null;
}

export interface LeetCodeProblem {
  id: string;
  title: string;
  slug: string;
  difficulty: 'EASY' | 'MEDIUM' | 'HARD';
  acceptanceRate: number | null;
  isPremium: boolean;
  topicTags: string[];
}
