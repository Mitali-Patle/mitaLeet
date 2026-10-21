import {
  Injectable,
  NotFoundException,
  ConflictException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../core/prisma/prisma.service';
import { EventsGateway, WS_EVENTS } from '../../core/events/events.gateway';
import { CreateGroupDto, JoinGroupDto } from './dto/groups.dto';
import { assertGroupMember } from '../../common/authz/group-membership';

@Injectable()
export class GroupsService {
  private readonly logger = new Logger(GroupsService.name);

  constructor(
    private prisma: PrismaService,
    private events: EventsGateway,
  ) {}

  /** Create a new group. Creator becomes OWNER. */
  async create(userId: string, dto: CreateGroupDto) {
    const code = this.generateCode();
    const group = await this.prisma.group.create({
      data: {
        name: dto.name,
        description: dto.description,
        code,
        members: { create: { userId, role: 'OWNER' } },
      },
      include: this.groupInclude,
    });

    return this.formatGroup(group, userId);
  }

  /** Join a group by invite code. */
  async joinByCode(userId: string, dto: JoinGroupDto) {
    const group = await this.prisma.group.findUnique({
      where: { code: dto.code.toUpperCase() },
    });
    if (!group) throw new NotFoundException('Invalid group code');

    const existing = await this.prisma.groupMember.findUnique({
      where: { userId_groupId: { userId, groupId: group.id } },
    });
    if (existing) throw new ConflictException('Already a member');

    await this.prisma.groupMember.create({
      data: { userId, groupId: group.id, role: 'MEMBER' },
    });

    // Notify group members via WS
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, displayName: true, avatarUrl: true },
    });
    this.events.emitToGroup(group.id, WS_EVENTS.GROUP_MEMBER_JOINED, {
      groupId: group.id,
      user,
    });

    return this.getById(group.id, userId);
  }

  /** Get group details with members and online status. Members only. */
  async getById(groupId: string, requesterId: string) {
    await assertGroupMember(this.prisma, requesterId, groupId);
    const group = await this.prisma.group.findUnique({
      where: { id: groupId },
      include: this.groupInclude,
    });
    if (!group) throw new NotFoundException('Group not found');
    return this.formatGroup(group, requesterId);
  }

  /** Get all groups for a user. */
  async getMyGroups(userId: string) {
    const groups = await this.prisma.group.findMany({
      where: { members: { some: { userId } } },
      include: this.groupInclude,
      orderBy: { updatedAt: 'desc' },
    });
    return groups.map((g) => this.formatGroup(g, userId));
  }

  /** Leave a group. */
  async leave(userId: string, groupId: string) {
    const member = await this.prisma.groupMember.findUnique({
      where: { userId_groupId: { userId, groupId } },
    });
    if (!member) throw new NotFoundException('Not a member');
    if (member.role === 'OWNER') {
      throw new ForbiddenException('Transfer ownership before leaving');
    }

    await this.prisma.groupMember.delete({ where: { id: member.id } });

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, displayName: true },
    });
    this.events.emitToGroup(groupId, WS_EVENTS.GROUP_MEMBER_LEFT, {
      groupId, user,
    });
  }

  /** Promote a member to ADMIN. */
  async promoteMember(requesterId: string, groupId: string, targetId: string) {
    await this.requireRole(requesterId, groupId, ['OWNER']);
    const member = await this.prisma.groupMember.findUnique({
      where: { userId_groupId: { userId: targetId, groupId } },
    });
    if (!member) throw new NotFoundException('Member not found');

    return this.prisma.groupMember.update({
      where: { id: member.id },
      data: { role: 'ADMIN' },
    });
  }

  /** Demote an ADMIN back to MEMBER. */
  async demoteMember(requesterId: string, groupId: string, targetId: string) {
    await this.requireRole(requesterId, groupId, ['OWNER']);
    const member = await this.prisma.groupMember.findUnique({
      where: { userId_groupId: { userId: targetId, groupId } },
    });
    if (!member || member.role !== 'ADMIN') {
      throw new NotFoundException('Admin not found');
    }
    return this.prisma.groupMember.update({
      where: { id: member.id },
      data: { role: 'MEMBER' },
    });
  }

  /** Remove a member from the group (OWNER/ADMIN only). */
  async removeMember(requesterId: string, groupId: string, targetId: string) {
    await this.requireRole(requesterId, groupId, ['OWNER', 'ADMIN']);
    const target = await this.prisma.groupMember.findUnique({
      where: { userId_groupId: { userId: targetId, groupId } },
    });
    if (!target) throw new NotFoundException('Member not found');
    if (target.role === 'OWNER') {
      throw new ForbiddenException('Cannot remove the owner');
    }

    await this.prisma.groupMember.delete({ where: { id: target.id } });
    this.events.emitToGroup(groupId, WS_EVENTS.GROUP_MEMBER_LEFT, {
      groupId, userId: targetId, removedBy: requesterId,
    });
  }

  /** Transfer ownership. */
  async transferOwnership(ownerId: string, groupId: string, newOwnerId: string) {
    await this.requireRole(ownerId, groupId, ['OWNER']);
    const newOwner = await this.prisma.groupMember.findUnique({
      where: { userId_groupId: { userId: newOwnerId, groupId } },
    });
    if (!newOwner) throw new NotFoundException('Member not found');

    await this.prisma.$transaction([
      this.prisma.groupMember.update({
        where: { userId_groupId: { userId: ownerId, groupId } },
        data: { role: 'ADMIN' },
      }),
      this.prisma.groupMember.update({
        where: { id: newOwner.id },
        data: { role: 'OWNER' },
      }),
    ]);

    this.events.emitToGroup(groupId, WS_EVENTS.GROUP_UPDATED, {
      groupId, event: 'ownership_transferred', newOwnerId,
    });
  }

  /** Regenerate invite code (OWNER/ADMIN only). */
  async regenerateCode(requesterId: string, groupId: string) {
    await this.requireRole(requesterId, groupId, ['OWNER', 'ADMIN']);
    const code = this.generateCode();
    return this.prisma.group.update({
      where: { id: groupId },
      data: { code },
      select: { id: true, code: true },
    });
  }

  /** Get leaderboard for a group. Members only. */
  async getLeaderboard(groupId: string, requesterId: string) {
    await assertGroupMember(this.prisma, requesterId, groupId);
    const members = await this.prisma.groupMember.findMany({
      where: { groupId },
      include: {
        user: {
          include: {
            profile: { select: { xp: true, totalSolves: true, easySolves: true, mediumSolves: true, hardSolves: true } },
            streak: { select: { currentStreak: true } },
          },
        },
      },
    });

    return members
      .map((m) => ({
        userId: m.user.id,
        displayName: m.user.displayName,
        avatarUrl: m.user.avatarUrl,
        status: m.user.status,
        role: m.role,
        xp: m.user.profile?.xp ?? 0,
        totalSolves: m.user.profile?.totalSolves ?? 0,
        currentStreak: m.user.streak?.currentStreak ?? 0,
        isOnline: this.events.isUserOnline(m.user.id),
      }))
      .sort((a, b) => b.xp - a.xp)
      .map((e, i) => ({ ...e, rank: i + 1 }));
  }

  /** Get group activity feed. Members only. */
  async getActivity(groupId: string, requesterId: string, limit = 30) {
    await assertGroupMember(this.prisma, requesterId, groupId);
    const members = await this.prisma.groupMember.findMany({
      where: { groupId },
      select: { userId: true },
    });
    const memberIds = members.map((m) => m.userId);

    return this.prisma.activity.findMany({
      where: { userId: { in: memberIds } },
      include: {
        user: { select: { id: true, displayName: true, avatarUrl: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  // ── Private helpers ─────────────────────────────────────────────

  private async requireRole(userId: string, groupId: string, roles: string[]) {
    const member = await this.prisma.groupMember.findUnique({
      where: { userId_groupId: { userId, groupId } },
    });
    if (!member || !roles.includes(member.role)) {
      throw new ForbiddenException('Insufficient permissions');
    }
  }

  private generateCode(): string {
    const c = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    const p = Array.from({ length: 3 }, () => c[Math.floor(Math.random() * c.length)]).join('');
    const s = Array.from({ length: 4 }, () => c[Math.floor(Math.random() * c.length)]).join('');
    return `${p}-${s}`;
  }

  private readonly groupInclude = {
    members: {
      include: {
        user: {
          select: { id: true, displayName: true, avatarUrl: true, status: true } as const,
        },
      },
      orderBy: { joinedAt: 'asc' as const },
    },
    _count: { select: { members: true } as const },
  };

  private formatGroup(group: any, requesterId?: string) {
    const onlineCount = group.members.filter(
      (m: any) => this.events.isUserOnline(m.user.id),
    ).length;

    return {
      ...group,
      onlineCount,
      members: group.members.map((m: any) => ({
        ...m,
        user: {
          ...m.user,
          isOnline: this.events.isUserOnline(m.user.id),
        },
      })),
      myRole: requesterId
        ? group.members.find((m: any) => m.userId === requesterId)?.role ?? null
        : null,
    };
  }
}
