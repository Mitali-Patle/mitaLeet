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

class LinkAccountDto {
  @IsNotEmpty() @IsString() @MaxLength(50)
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

  @Post('link')
  link(@CurrentUser() user: JwtPayload, @Body() dto: LinkAccountDto) {
    return this.leetcodeService.linkAccount(user.sub, dto.leetcodeUsername);
  }

  @Delete('link')
  unlink(@CurrentUser() user: JwtPayload) {
    return this.leetcodeService.unlinkAccount(user.sub);
  }

  @Post('sync')
  manualSync(@CurrentUser() user: JwtPayload) {
    return this.leetcodeService.manualSync(user.sub);
  }

  @Get('sync/history')
  syncHistory(@CurrentUser() user: JwtPayload, @Query('limit') limit?: number) {
    return this.leetcodeService.getSyncHistory(user.sub, limit);
  }

  // ── Extension real-time solve ──────────────────────────────────────

  @Post('extension-solve')
  extensionSolve(@CurrentUser() user: JwtPayload, @Body() dto: ExtensionSolveDto) {
    return this.solvesService.verifyExtensionSolve(user.sub, dto.problemSlug);
  }

  // ── Solves ─────────────────────────────────────────────────────

  @Get('solves')
  getRecentSolves(@CurrentUser() user: JwtPayload, @Query('limit') limit?: number) {
    return this.solvesService.getRecentSolves(user.sub, limit);
  }

  @Get('stats')
  getStats(@CurrentUser() user: JwtPayload) {
    return this.solvesService.getStats(user.sub);
  }

  @Get('heatmap')
  getHeatmap(@CurrentUser() user: JwtPayload, @Query('days') days?: number) {
    return this.solvesService.getHeatmap(user.sub, days);
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
  getSessions(@CurrentUser() user: JwtPayload, @Query('limit') limit?: number) {
    return this.solvesService.getSessions(user.sub, limit);
  }
}
