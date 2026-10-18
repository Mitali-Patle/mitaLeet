import { Controller, Get, Post, Body, Param, Query } from '@nestjs/common';
import { LeaderboardService, LeaderboardPeriod } from './leaderboard.service';
import { ChallengeService } from './challenge.service';
import { XPService } from './xp.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../../core/auth/types';
import { PrismaService } from '../../core/prisma/prisma.service';

@Controller('gamification')
export class GamificationController {
  constructor(
    private leaderboard: LeaderboardService,
    private challenge: ChallengeService,
    private xp: XPService,
    private prisma: PrismaService,
  ) {}

  // ── Progression ────────────────────────────────────────────────

  @Get('progression')
  getProgression(@CurrentUser() user: JwtPayload) {
    return this.xp.getProgression(user.sub);
  }

  @Get('achievements')
  getAchievements(@CurrentUser() user: JwtPayload) {
    return this.prisma.userAchievement.findMany({
      where: { userId: user.sub },
      orderBy: { unlockedAt: 'desc' },
    });
  }

  // ── Leaderboards ───────────────────────────────────────────────

  @Get('leaderboard/global')
  getGlobal(
    @Query('period') period: LeaderboardPeriod = 'alltime',
    @Query('limit') limit = 50,
    @Query('offset') offset = 0,
  ) {
    return this.leaderboard.getGlobal(period, +limit, +offset);
  }

  @Get('leaderboard/friends')
  getFriends(@CurrentUser() user: JwtPayload) {
    return this.leaderboard.getFriends(user.sub);
  }

  @Get('leaderboard/groups/:groupId')
  getGroup(@CurrentUser() user: JwtPayload, @Param('groupId') groupId: string) {
    return this.leaderboard.getGroupForMember(user.sub, groupId);
  }

  // ── Challenges ─────────────────────────────────────────────────

  @Get('challenges')
  getUserChallenges(@CurrentUser() user: JwtPayload) {
    return this.challenge.getUserChallenges(user.sub);
  }

  @Get('challenges/group/:groupId')
  getGroupChallenges(@CurrentUser() user: JwtPayload, @Param('groupId') groupId: string) {
    return this.challenge.getGroupChallenges(user.sub, groupId);
  }

  @Post('challenges/group/:groupId')
  createChallenge(
    @CurrentUser() user: JwtPayload,
    @Param('groupId') groupId: string,
    @Body() body: any,
  ) {
    return this.challenge.createChallenge(user.sub, groupId, body);
  }

  @Post('challenges/:id/join')
  joinChallenge(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.challenge.joinChallenge(user.sub, id);
  }

  @Post('challenges/:id/complete')
  completeChallenge(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.challenge.completeChallenge(user.sub, id);
  }
}
