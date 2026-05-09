import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { GamificationController } from './gamification.controller';
import { XPService } from './xp.service';
import { LeaderboardService } from './leaderboard.service';
import { ChallengeService } from './challenge.service';
import { EventsModule } from '../../core/events/events.module';

@Module({
  imports: [EventsModule, ScheduleModule],
  controllers: [GamificationController],
  providers: [XPService, LeaderboardService, ChallengeService],
  exports: [XPService, LeaderboardService, ChallengeService],
})
export class GamificationModule {}
