import {
  Injectable,
  NotFoundException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../core/prisma/prisma.service';
import { UpdateProfileDto, RegisterDeviceDto } from './dto/users.dto';

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(private prisma: PrismaService) {}

  /** Get full user with profile and streak. */
  async getMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        profile: true,
        streak: true,
      },
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  /** Get public user profile by username. */
  async getByUsername(username: string) {
    const profile = await this.prisma.userProfile.findUnique({
      where: { username },
      include: {
        user: {
          select: {
            id: true,
            displayName: true,
            avatarUrl: true,
            status: true,
          },
        },
      },
    });
    if (!profile) throw new NotFoundException('User not found');
    return profile;
  }

  /** Update user profile. */
  async updateProfile(userId: string, dto: UpdateProfileDto) {
    // Check username uniqueness if changing
    if (dto.username) {
      const existing = await this.prisma.userProfile.findUnique({
        where: { username: dto.username },
      });
      if (existing && existing.userId !== userId) {
        throw new ConflictException('Username already taken');
      }
    }

    // Update user fields
    if (dto.displayName || dto.avatarUrl) {
      await this.prisma.user.update({
        where: { id: userId },
        data: {
          ...(dto.displayName && { displayName: dto.displayName }),
          ...(dto.avatarUrl && { avatarUrl: dto.avatarUrl }),
        },
      });
    }

    // Update profile fields
    return this.prisma.userProfile.update({
      where: { userId },
      data: {
        ...(dto.username && { username: dto.username }),
        ...(dto.bio !== undefined && { bio: dto.bio }),
        ...(dto.timezone && { timezone: dto.timezone }),
      },
      include: {
        user: {
          select: {
            id: true,
            displayName: true,
            avatarUrl: true,
            status: true,
          },
        },
      },
    });
  }

  /** Register a device token for push notifications. */
  async registerDevice(userId: string, dto: RegisterDeviceDto) {
    return this.prisma.deviceToken.upsert({
      where: { token: dto.token },
      create: {
        token: dto.token,
        platform: dto.platform,
        userId,
      },
      update: {
        platform: dto.platform,
        userId,
      },
    });
  }

  /** Remove one of the caller's own device tokens. */
  async unregisterDevice(userId: string, token: string) {
    await this.prisma.deviceToken.deleteMany({
      where: { token, userId },
    });
  }

  /**
   * Delete the account and everything that belongs to it (profile, sessions,
   * devices, solves, streak, activity, notifications, friendships, requests,
   * memberships, races created) via the schema's ON DELETE CASCADE.
   * Squads the user owns go to the longest-standing admin (else member), or
   * are deleted when nobody else is left.
   */
  async deleteAccount(userId: string): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const owned = await tx.groupMember.findMany({ where: { userId, role: 'OWNER' }, select: { groupId: true } });
      for (const { groupId } of owned) {
        const successor = await tx.groupMember.findFirst({
          where: { groupId, userId: { not: userId } },
          orderBy: [{ role: 'asc' }, { joinedAt: 'asc' }], // enum order: OWNER, ADMIN, MEMBER
        });
        if (successor) {
          await tx.groupMember.update({ where: { id: successor.id }, data: { role: 'OWNER' } });
        } else {
          await tx.group.delete({ where: { id: groupId } });
        }
      }
      await tx.user.delete({ where: { id: userId } });
    });
    this.logger.log(`Account deleted: ${userId}`);
  }

  /** Update user online status. */
  async updateStatus(userId: string, status: 'ONLINE' | 'OFFLINE' | 'SOLVING' | 'IDLE') {
    return this.prisma.user.update({
      where: { id: userId },
      data: { status },
      select: { id: true, status: true },
    });
  }
}
