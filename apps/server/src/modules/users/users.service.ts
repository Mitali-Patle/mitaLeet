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

    // Check LeetCode username uniqueness
    if (dto.leetcodeUsername) {
      const existing = await this.prisma.userProfile.findUnique({
        where: { leetcodeUsername: dto.leetcodeUsername },
      });
      if (existing && existing.userId !== userId) {
        throw new ConflictException('LeetCode username already linked');
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
        ...(dto.leetcodeUsername && {
          leetcodeUsername: dto.leetcodeUsername,
        }),
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

  /** Remove a device token. */
  async unregisterDevice(token: string) {
    await this.prisma.deviceToken.deleteMany({
      where: { token },
    });
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
