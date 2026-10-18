import {
  Injectable, NotFoundException, BadRequestException, ForbiddenException,
  ConflictException, OnModuleInit, Logger,
} from '@nestjs/common';
import { Challenge, ChallengeParticipant } from '@prisma/client';
import { PrismaService } from '../../core/prisma/prisma.service';
import { EventsGateway, WS_EVENTS } from '../../core/events/events.gateway';
import { XPService } from './xp.service';
import { LeaderboardService } from './leaderboard.service';
import { assertGroupMember } from '../../common/authz/group-membership';
import { NewSolvesEvent, SyncService } from '../leetcode/sync.service';
import { CreateChallengeDto } from './dto/challenge.dto';

const MAX_CHALLENGE_DAYS = 31;

@Injectable()
export class ChallengeService implements OnModuleInit {
  private readonly logger = new Logger(ChallengeService.name);

  constructor(
    private prisma: PrismaService,
    private events: EventsGateway,
    private xp: XPService,
    private leaderboard: LeaderboardService,
    private sync: SyncService,
  ) {}

  onModuleInit() {
    // A verified solve of the challenge problem completes the challenge automatically.
    this.sync.onNewSolves((event) => this.completeFromSolves(event));
  }

  /** Create a new squad challenge. */
  async createChallenge(creatorId: string, groupId: string, dto: CreateChallengeDto) {
    const startsAt = new Date(dto.startsAt);
    const endsAt = new Date(dto.endsAt);
    if (endsAt <= startsAt) throw new BadRequestException('endsAt must be after startsAt');
    if (endsAt.getTime() - startsAt.getTime() > MAX_CHALLENGE_DAYS * 86_400_000) {
      throw new BadRequestException(`Challenges can last at most ${MAX_CHALLENGE_DAYS} days`);
    }

    // Must be admin/owner
    const member = await this.prisma.groupMember.findUnique({
      where: { userId_groupId: { userId: creatorId, groupId } },
    });
    if (!member || !['OWNER', 'ADMIN'].includes(member.role)) {
      throw new ForbiddenException('Only admins can create challenges');
    }

    const challenge = await this.prisma.challenge.create({
      data: {
        title: dto.title,
        description: dto.description,
        problemSlug: dto.problemSlug,
        startsAt,
        endsAt,
        groupId,
        type: dto.type ?? 'squad',
        xpReward: dto.xpReward ?? 75,
      },
      include: { group: { select: { name: true } } },
    });

    this.events.emitToGroup(groupId, WS_EVENTS.CHALLENGE_STARTED, {
      challengeId: challenge.id,
      title: challenge.title,
      problemSlug: challenge.problemSlug,
      endsAt: challenge.endsAt,
    });

    return challenge;
  }

  /** Join a challenge. */
  async joinChallenge(userId: string, challengeId: string) {
    const challenge = await this.prisma.challenge.findUnique({
      where: { id: challengeId },
    });
    if (!challenge) throw new NotFoundException('Challenge not found');
    await assertGroupMember(this.prisma, userId, challenge.groupId).catch(() => {
      throw new NotFoundException('Challenge not found');
    });
    if (new Date() > challenge.endsAt) throw new BadRequestException('Challenge has ended');

    const participation = await this.prisma.challengeParticipant.upsert({
      where: { userId_challengeId: { userId, challengeId } },
      update: {},
      create: { userId, challengeId },
    });

    this.events.emitToGroup(challenge.groupId, WS_EVENTS.CHALLENGE_STARTED, {
      type: 'participant_joined',
      challengeId,
      userId,
    });

    return participation;
  }

  /**
   * Complete a challenge. Requires an accepted LeetCode submission of the
   * challenge problem inside the challenge window; the client's word is not enough.
   */
  async completeChallenge(userId: string, challengeId: string) {
    const [challenge, participation] = await Promise.all([
      this.prisma.challenge.findUnique({ where: { id: challengeId } }),
      this.prisma.challengeParticipant.findUnique({
        where: { userId_challengeId: { userId, challengeId } },
      }),
    ]);

    if (!challenge) throw new NotFoundException('Challenge not found');
    if (!participation) throw new BadRequestException('Not participating in this challenge');
    if (participation.completedAt) return participation; // already done

    let solve = await this.findQualifyingSolve(userId, challenge);
    if (!solve) {
      await this.sync.syncRecent(userId);
      solve = await this.findQualifyingSolve(userId, challenge);
    }
    if (!solve) {
      throw new ConflictException(
        `No accepted LeetCode submission for "${challenge.problemSlug}" in the challenge window yet`,
      );
    }

    return (await this.markCompleted(userId, challenge, solve.solvedAt))
      ?? this.prisma.challengeParticipant.findUnique({ where: { userId_challengeId: { userId, challengeId } } });
  }

  /** Auto-complete any joined, open challenges that the new verified solves satisfy. */
  private async completeFromSolves({ userId, solves }: NewSolvesEvent): Promise<void> {
    const slugs = [...new Set(solves.map((s) => s.problemSlug))];
    const open = await this.prisma.challengeParticipant.findMany({
      where: { userId, completedAt: null, challenge: { problemSlug: { in: slugs } } },
      include: { challenge: true },
    });
    for (const p of open) {
      const solve = solves
        .filter((s) => s.problemSlug === p.challenge.problemSlug)
        .find((s) => s.solvedAt >= p.challenge.startsAt && s.solvedAt <= p.challenge.endsAt);
      if (solve) await this.markCompleted(userId, p.challenge, solve.solvedAt);
    }
  }

  private findQualifyingSolve(userId: string, challenge: Challenge) {
    return this.prisma.solve.findFirst({
      where: {
        userId,
        problemSlug: challenge.problemSlug,
        solvedAt: { gte: challenge.startsAt, lte: challenge.endsAt },
      },
      orderBy: { solvedAt: 'asc' },
    });
  }

  /**
   * Mark complete exactly once (concurrent calls cannot double-award), rank by
   * the real LeetCode solve time, then award XP.
   */
  private async markCompleted(
    userId: string,
    challenge: Challenge,
    solvedAt: Date,
  ): Promise<ChallengeParticipant | null> {
    const claimed = await this.prisma.challengeParticipant.updateMany({
      where: { userId, challengeId: challenge.id, completedAt: null },
      data: { completedAt: solvedAt },
    });
    if (claimed.count === 0) return null;

    const placement = await this.prisma.challengeParticipant.count({
      where: { challengeId: challenge.id, completedAt: { not: null, lte: solvedAt } },
    });
    const xpMultiplier = placement === 1 ? 2 : placement <= 3 ? 1.5 : 1;
    const xpAwarded = Math.floor(challenge.xpReward * xpMultiplier);

    const updated = await this.prisma.challengeParticipant.update({
      where: { userId_challengeId: { userId, challengeId: challenge.id } },
      data: { rank: placement, xpAwarded },
    });

    await this.xp.awardBonusXP(userId, xpAwarded, `challenge_complete:${challenge.id}`);

    await this.prisma.activity.create({
      data: {
        userId, type: 'CHALLENGE_COMPLETED',
        data: { challengeId: challenge.id, title: challenge.title, placement, xpAwarded },
      },
    });

    this.events.emitToGroup(challenge.groupId, WS_EVENTS.CHALLENGE_COMPLETED, {
      challengeId: challenge.id,
      userId,
      placement,
      xpAwarded,
      title: challenge.title,
    });
    this.logger.log(`Challenge ${challenge.id} completed by ${userId} (place ${placement})`);
    return updated;
  }

  /** Get active challenges for a group. Members only. */
  async getGroupChallenges(userId: string, groupId: string) {
    await assertGroupMember(this.prisma, userId, groupId);
    const now = new Date();
    return this.prisma.challenge.findMany({
      where: { groupId, endsAt: { gte: now } },
      orderBy: { startsAt: 'asc' },
      include: {
        participants: {
          orderBy: { completedAt: 'asc' },
          include: {
            user: { select: { displayName: true, avatarUrl: true } },
          },
        },
      },
    });
  }

  /** Get all challenges a user participates in. */
  async getUserChallenges(userId: string) {
    return this.prisma.challengeParticipant.findMany({
      where: { userId },
      orderBy: { joinedAt: 'desc' },
      include: {
        challenge: {
          include: { group: { select: { id: true, name: true } } },
        },
      },
    });
  }
}
