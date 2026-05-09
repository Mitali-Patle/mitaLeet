import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../core/prisma/prisma.service';
import { EventsGateway, WS_EVENTS } from '../../core/events/events.gateway';
import { ActivityType } from '@prisma/client';

@Injectable()
export class ActivitiesService {
  private readonly logger = new Logger(ActivitiesService.name);

  constructor(
    private prisma: PrismaService,
    private events: EventsGateway,
  ) {}

  /** Create an activity and broadcast to relevant groups. */
  async create(
    userId: string,
    type: ActivityType,
    data?: Record<string, unknown>,
  ) {
    const activity = await this.prisma.activity.create({
      data: { userId, type, data: (data ?? undefined) as any },
      include: {
        user: {
          select: { id: true, displayName: true, avatarUrl: true },
        },
      },
    });

    // Broadcast to all groups the user belongs to
    const memberships = await this.prisma.groupMember.findMany({
      where: { userId },
      select: { groupId: true },
    });

    for (const { groupId } of memberships) {
      this.events.emitToGroup(groupId, WS_EVENTS.ACTIVITY_CREATED, activity);
    }

    return activity;
  }

  /** Get activity feed for a user's groups. */
  async getFeed(userId: string, limit = 50, cursor?: string) {
    // Get user's group IDs
    const memberships = await this.prisma.groupMember.findMany({
      where: { userId },
      select: { groupId: true },
    });
    const groupIds = memberships.map((m) => m.groupId);

    // Get members of those groups
    const members = await this.prisma.groupMember.findMany({
      where: { groupId: { in: groupIds } },
      select: { userId: true },
    });
    const memberIds = [...new Set(members.map((m) => m.userId))];

    return this.prisma.activity.findMany({
      where: {
        userId: { in: memberIds },
        ...(cursor && { id: { lt: cursor } }),
      },
      include: {
        user: {
          select: { id: true, displayName: true, avatarUrl: true },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  /** Get activity for a specific user. */
  async getByUser(userId: string, limit = 20) {
    return this.prisma.activity.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }
}
