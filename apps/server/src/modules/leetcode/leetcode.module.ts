import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { LeetCodeController } from './leetcode.controller';
import { LeetCodeService } from './leetcode.service';
import { LeetCodeClient } from './leetcode.client';
import { SyncService } from './sync.service';
import { StreakService } from './streak.service';
import { SolvesService } from './solves.service';
import { EventsModule } from '../../core/events/events.module';

@Module({
  imports: [EventsModule, ScheduleModule],
  controllers: [LeetCodeController],
  providers: [LeetCodeService, LeetCodeClient, SyncService, StreakService, SolvesService],
  exports: [SyncService, StreakService, SolvesService, LeetCodeClient],
})
export class LeetCodeModule {}
