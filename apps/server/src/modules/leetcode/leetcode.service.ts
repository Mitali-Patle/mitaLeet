import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import { createHmac } from 'crypto';
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
    private config: ConfigService,
  ) {}

  /**
   * Step 1 of linking: check the username and hand back a code the user must
   * put in their LeetCode profile "About me". Nothing is linked yet.
   */
  async startLink(userId: string, leetcodeUsername: string) {
    const username = this.normalize(leetcodeUsername);
    await this.assertNotLinkedElsewhere(userId, username);

    const exists = await this.leetcode.validateUsername(username);
    if (!exists) throw new BadRequestException('LeetCode username not found');

    return {
      leetcodeUsername: username,
      verificationCode: this.verificationCode(userId, username),
      instructions:
        'Add this code anywhere in your LeetCode profile "About me" (Edit Profile > Summary), ' +
        'save, then tap Verify. You can remove it afterwards.',
    };
  }

  /**
   * Step 2: confirm the code is on the LeetCode profile, then link and sync.
   * This proves the caller controls the account whose solves they will earn XP for.
   */
  async verifyLink(userId: string, leetcodeUsername: string) {
    const username = this.normalize(leetcodeUsername);
    await this.assertNotLinkedElsewhere(userId, username);

    const aboutMe = await this.leetcode.fetchProfileAboutMe(username);
    if (aboutMe === null) throw new BadRequestException('LeetCode username not found');
    if (!aboutMe.includes(this.verificationCode(userId, username))) {
      throw new BadRequestException(
        'Verification code not found in your LeetCode profile "About me" yet. Save it there and try again.',
      );
    }

    const profile = await this.prisma.userProfile
      .update({
        where: { userId },
        data: {
          leetcodeUsername: username,
          leetcodeVerified: true,
          leetcodeLinkedAt: new Date(),
        },
      })
      .catch((err) => {
        if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
          throw new ConflictException('This LeetCode account is linked to another user');
        }
        throw err;
      });

    await this.syncService.triggerSync(userId, 'full_refresh');

    return {
      leetcodeUsername: profile.leetcodeUsername,
      leetcodeVerified: profile.leetcodeVerified,
      leetcodeLinkedAt: profile.leetcodeLinkedAt,
    };
  }

  /** Deterministic per (user, LeetCode account); no storage needed. */
  private verificationCode(userId: string, username: string): string {
    const digest = createHmac('sha256', this.config.getOrThrow<string>('JWT_SECRET'))
      .update(`leetcode-link:${userId}:${username}`)
      .digest('hex');
    return `mitaleet-${digest.slice(0, 10)}`;
  }

  private normalize(leetcodeUsername: string): string {
    return leetcodeUsername.trim().toLowerCase();
  }

  private async assertNotLinkedElsewhere(userId: string, username: string) {
    const existing = await this.prisma.userProfile.findFirst({
      where: { leetcodeUsername: username, userId: { not: userId } },
      select: { id: true },
    });
    if (existing) throw new ConflictException('This LeetCode account is linked to another user');
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
