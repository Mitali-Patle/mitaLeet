import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/app.setup';
import { PrismaService } from '../src/core/prisma/prisma.service';
import {
  LeetCodeClient,
  LeetCodeProblem,
  LeetCodeProfile,
  LeetCodeSubmission,
} from '../src/modules/leetcode/leetcode.client';

/**
 * In-memory stand-in for LeetCode's GraphQL API so tests never call leetcode.com.
 * Tests seed it with profiles and accepted submissions per username.
 */
export class FakeLeetCodeClient {
  profiles = new Map<string, LeetCodeProfile & { aboutMe?: string }>();
  submissions = new Map<string, LeetCodeSubmission[]>();
  problems = new Map<string, LeetCodeProblem>();

  addUser(username: string, aboutMe = '') {
    this.profiles.set(username.toLowerCase(), {
      username, totalSolved: 0, easySolved: 0, mediumSolved: 0, hardSolved: 0, aboutMe,
    });
  }

  addSubmission(username: string, slug: string, at = new Date()) {
    const list = this.submissions.get(username.toLowerCase()) ?? [];
    list.unshift({
      id: String(Math.random()), title: slug, slug,
      timestamp: Math.floor(at.getTime() / 1000), language: 'python3', runtime: 1, memory: 1,
    });
    this.submissions.set(username.toLowerCase(), list);
  }

  async validateUsername(username: string) { return this.profiles.has(username.toLowerCase()); }
  async fetchUserProfile(username: string) { return this.profiles.get(username.toLowerCase()) ?? null; }
  async fetchProfileAboutMe(username: string) { return this.profiles.get(username.toLowerCase())?.aboutMe ?? null; }
  async fetchRecentSubmissions(username: string, limit = 20) {
    return (this.submissions.get(username.toLowerCase()) ?? []).slice(0, limit);
  }
  async fetchProblem(slug: string) { return this.problems.get(slug) ?? null; }
  async fetchSubmissionCalendar() { return {}; }
}

export interface TestContext {
  app: INestApplication;
  prisma: PrismaService;
  leetcode: FakeLeetCodeClient;
  http: () => ReturnType<typeof request>;
}

export async function createTestApp(): Promise<TestContext> {
  const leetcode = new FakeLeetCodeClient();
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(LeetCodeClient)
    .useValue(leetcode)
    .compile();

  const app = moduleRef.createNestApplication({ logger: ['error', 'warn'] });
  configureApp(app);
  await app.init();

  return {
    app,
    prisma: app.get(PrismaService),
    leetcode,
    http: () => request(app.getHttpServer()),
  };
}

/** Delete all rows (keeps the schema) so each test file starts clean. */
export async function resetDb(prisma: PrismaService): Promise<void> {
  const tables = await prisma.$queryRaw<{ tablename: string }[]>`
    SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename <> '_prisma_migrations'`;
  const list = tables.map((t) => `"public"."${t.tablename}"`).join(', ');
  if (list) await prisma.$executeRawUnsafe(`TRUNCATE TABLE ${list} CASCADE`);
}

export interface TestUser {
  id: string;
  accessToken: string;
  refreshToken: string;
  auth: { Authorization: string };
}

/** Create (or reuse) a user through the dev-login endpoint. */
export async function login(ctx: TestContext, username: string): Promise<TestUser> {
  const res = await ctx.http().post('/api/v1/auth/dev-login').send({ username }).expect(200);
  const { tokens, user } = res.body.data;
  return {
    id: user.id,
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    auth: { Authorization: `Bearer ${tokens.accessToken}` },
  };
}

export async function seedProblem(prisma: PrismaService, slug: string, difficulty: 'EASY' | 'MEDIUM' | 'HARD' = 'EASY') {
  return prisma.problem.upsert({
    where: { slug },
    update: {},
    create: { slug, title: slug, difficulty, topicTags: [] },
  });
}

export async function getXp(ctx: TestContext, user: TestUser): Promise<number> {
  const res = await ctx.http().get('/api/v1/gamification/progression').set(user.auth).expect(200);
  return res.body.data.xp;
}
