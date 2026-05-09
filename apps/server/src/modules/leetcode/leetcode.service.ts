import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../core/prisma/prisma.service';
import { LeetCodeClient } from './leetcode.client';
import { SyncService } from './sync.service';

@Injectable()
export class LeetCodeService {
  private readonly logger = new Logger(LeetCodeService.name);

  constructor(
    private prisma: PrismaService,
    private leetcode: LeetCodeClient,
    private syncService: SyncService,
  ) {}

  /** Link a LeetCode username to the user's profile. */
  async linkAccount(userId: string, leetcodeUsername: string) {
    const trimmed = leetcodeUsername.trim().toLowerCase();
    if (!trimmed || trimmed.length < 1 || trimmed.length > 50) {
      throw new BadRequestException('Invalid LeetCode username');
    }

    // Check if already linked by someone else
    const existing = await this.prisma.userProfile.findFirst({
      where: { leetcodeUsername: trimmed, userId: { not: userId } },
    });
    if (existing) {
      throw new ConflictException('This LeetCode account is linked to another user');
    }

    // Validate username on LeetCode
    const valid = await this.leetcode.validateUsername(trimmed);
    if (!valid) {
      throw new BadRequestException('LeetCode username not found');
    }

    // Update profile
    const profile = await this.prisma.userProfile.update({
      where: { userId },
      data: {
        leetcodeUsername: trimmed,
        leetcodeVerified: true,
        leetcodeLinkedAt: new Date(),
      },
    });

    // Trigger initial sync
    await this.syncService.triggerSync(userId, 'full_refresh');

    return {
      leetcodeUsername: profile.leetcodeUsername,
      leetcodeVerified: profile.leetcodeVerified,
      leetcodeLinkedAt: profile.leetcodeLinkedAt,
    };
  }

  /** Unlink LeetCode account. */
  async unlinkAccount(userId: string) {
    await this.prisma.userProfile.update({
      where: { userId },
      data: {
        leetcodeUsername: null,
        leetcodeVerified: false,
        leetcodeLinkedAt: null,
        lastSyncAt: null,
      },
    });
  }

  /** Get linking status. */
  async getLinkStatus(userId: string) {
    const profile = await this.prisma.userProfile.findUnique({
      where: { userId },
      select: {
        leetcodeUsername: true,
        leetcodeVerified: true,
        leetcodeLinkedAt: true,
        lastSyncAt: true,
      },
    });
    if (!profile) throw new NotFoundException('Profile not found');

    const lastSync = await this.prisma.syncJob.findFirst({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      select: { status: true, completedAt: true, error: true },
    });

    return {
      ...profile,
      lastSync: lastSync ?? null,
    };
  }

  /** Manually trigger a sync. */
  async manualSync(userId: string) {
    const profile = await this.prisma.userProfile.findUnique({
      where: { userId },
      select: { leetcodeUsername: true },
    });
    if (!profile?.leetcodeUsername) {
      throw new BadRequestException('No LeetCode account linked');
    }

    // Rate limit: max 1 sync per 5 minutes
    const recentSync = await this.prisma.syncJob.findFirst({
      where: {
        userId,
        createdAt: { gte: new Date(Date.now() - 5 * 60_000) },
        status: { in: ['PENDING', 'RUNNING'] },
      },
    });
    if (recentSync) {
      throw new BadRequestException('Sync already in progress. Try again later.');
    }

    return this.syncService.triggerSync(userId, 'leetcode_sync');
  }

  /** Get sync history. */
  async getSyncHistory(userId: string, limit = 10) {
    return this.prisma.syncJob.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }
}
