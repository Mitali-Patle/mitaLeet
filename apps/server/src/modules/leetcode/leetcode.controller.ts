import {
  Controller, Get, Post, Delete, Body, Query, Param,
} from '@nestjs/common';
import { LeetCodeService } from './leetcode.service';
import { SolvesService } from './solves.service';
import { StreakService } from './streak.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../../core/auth/types';
import { PROBLEM_SLUG } from '../../common/validation/slug';
import {
  IsDateString, IsInt, IsNotEmpty, IsOptional, IsString, Matches, MaxLength, Min,
} from 'class-validator';
import { RateLimit } from '../../common/throttle/rate-limit';
import { HeatmapQueryDto, LimitQueryDto } from '../../common/dto/query.dto';

class LinkAccountDto {
  @IsNotEmpty() @IsString() @MaxLength(50)
  @Matches(/^[A-Za-z0-9_-]+$/, { message: 'Invalid LeetCode username format' })
  leetcodeUsername!: string;
}

class ExtensionSolveDto {
  @IsString() @MaxLength(120) @Matches(PROBLEM_SLUG)
  problemSlug!: string;

  // Sent by existing extension builds; accepted but not trusted.
  @IsOptional() @IsString() @MaxLength(40)
  language?: string;

  @IsOptional() @IsDateString()
  solvedAt?: string;

  @IsOptional() @IsInt() @Min(0)
  durationMs?: number;
}

@Controller('leetcode')
export class LeetCodeController {
  constructor(
    private readonly leetcodeService: LeetCodeService,
    private readonly solvesService: SolvesService,
    private readonly streakService: StreakService,
  ) {}

  // ── Account linking ────────────────────────────────────────────

  @Get('status')
  getStatus(@CurrentUser() user: JwtPayload) {
    return this.leetcodeService.getLinkStatus(user.sub);
  }

  /** Step 1: returns a code to put in the LeetCode profile "About me". */
  @RateLimit(10)
  @Post('link')
  link(@CurrentUser() user: JwtPayload, @Body() dto: LinkAccountDto) {
    return this.leetcodeService.startLink(user.sub, dto.leetcodeUsername);
  }

  /** Step 2: checks the code on LeetCode, then links the account. */
  @RateLimit(10)
  @Post('link/verify')
  verifyLink(@CurrentUser() user: JwtPayload, @Body() dto: LinkAccountDto) {
    return this.leetcodeService.verifyLink(user.sub, dto.leetcodeUsername);
  }

  @Delete('link')
  unlink(@CurrentUser() user: JwtPayload) {
    return this.leetcodeService.unlinkAccount(user.sub);
  }

  @RateLimit(4)
  @Post('sync')
  manualSync(@CurrentUser() user: JwtPayload) {
    return this.leetcodeService.manualSync(user.sub);
  }

  @Get('sync/history')
  syncHistory(@CurrentUser() user: JwtPayload, @Query() q: LimitQueryDto) {
    return this.leetcodeService.getSyncHistory(user.sub, q.limit);
  }

  // ── Extension real-time solve ──────────────────────────────────────

  @RateLimit(30)
  @Post('extension-solve')
  extensionSolve(@CurrentUser() user: JwtPayload, @Body() dto: ExtensionSolveDto) {
    return this.solvesService.verifyExtensionSolve(user.sub, dto.problemSlug);
  }

  // ── Solves ─────────────────────────────────────────────────────

  @Get('solves')
  getRecentSolves(@CurrentUser() user: JwtPayload, @Query() q: LimitQueryDto) {
    return this.solvesService.getRecentSolves(user.sub, q.limit);
  }

  @Get('stats')
  getStats(@CurrentUser() user: JwtPayload) {
    return this.solvesService.getStats(user.sub);
  }

  @Get('heatmap')
  getHeatmap(@CurrentUser() user: JwtPayload, @Query() q: HeatmapQueryDto) {
    return this.solvesService.getHeatmap(user.sub, q.days);
  }

  // ── Streak ─────────────────────────────────────────────────────

  @Get('streak')
  getStreak(@CurrentUser() user: JwtPayload) {
    return this.streakService.getStreak(user.sub);
  }

  // ── Solve sessions ─────────────────────────────────────────────

  @Post('sessions')
  startSession(
    @CurrentUser() user: JwtPayload,
    @Body('problemSlug') slug: string,
  ) {
    return this.solvesService.startSession(user.sub, slug);
  }

  @Post('sessions/:id/complete')
  completeSession(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.solvesService.completeSession(id, user.sub);
  }

  @Get('sessions')
  getSessions(@CurrentUser() user: JwtPayload, @Query() q: LimitQueryDto) {
    return this.solvesService.getSessions(user.sub, q.limit);
  }
}
