import {
  Injectable, NotFoundException, BadRequestException, ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../core/prisma/prisma.service';
import { EventsGateway, WS_EVENTS } from '../../core/events/events.gateway';
import { XPService } from './xp.service';
import { LeaderboardService } from './leaderboard.service';
import { assertGroupMember } from '../../common/authz/group-membership';

@Injectable()
export class ChallengeService {
  constructor(
    private prisma: PrismaService,
    private events: EventsGateway,
    private xp: XPService,
    private leaderboard: LeaderboardService,
  ) {}

  /** Create a new squad challenge. */
  async createChallenge(
    creatorId: string,
    groupId: string,
    data: {
      title: string;
      description?: string;
      problemSlug: string;
      type?: string;
      xpReward?: number;
      startsAt: Date;
      endsAt: Date;
    },
  ) {
    // Must be admin/owner
    const member = await this.prisma.groupMember.findUnique({
      where: { userId_groupId: { userId: creatorId, groupId } },
    });
    if (!member || !['OWNER', 'ADMIN'].includes(member.role)) {
      throw new ForbiddenException('Only admins can create challenges');
    }

    const challenge = await this.prisma.challenge.create({
      data: {
        ...data,
        groupId,
        type: data.type ?? 'squad',
        xpReward: data.xpReward ?? 75,
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

  /** Mark a challenge as completed for a user. */
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

    // Count completions to determine placement rank
    const completedCount = await this.prisma.challengeParticipant.count({
      where: { challengeId, completedAt: { not: null } },
    });
    const placement = completedCount + 1;

    // Bonus XP for first finisher
    const xpMultiplier = placement === 1 ? 2 : placement <= 3 ? 1.5 : 1;
    const xpAwarded = Math.floor(challenge.xpReward * xpMultiplier);

    const updated = await this.prisma.challengeParticipant.update({
      where: { userId_challengeId: { userId, challengeId } },
      data: { completedAt: new Date(), rank: placement, xpAwarded },
    });

    // Award XP
    await this.xp.awardBonusXP(userId, xpAwarded, `challenge_complete:${challengeId}`);

    // Create activity
    await this.prisma.activity.create({
      data: {
        userId, type: 'CHALLENGE_COMPLETED',
        data: { challengeId, title: challenge.title, placement, xpAwarded },
      },
    });

    // Broadcast completion to group
    this.events.emitToGroup(challenge.groupId, WS_EVENTS.CHALLENGE_COMPLETED, {
      challengeId,
      userId,
      placement,
      xpAwarded,
      title: challenge.title,
    });

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
