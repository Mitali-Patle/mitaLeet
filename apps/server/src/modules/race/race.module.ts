import { Module } from '@nestjs/common';
import { RaceController } from './race.controller';
import { RaceService } from './race.service';
import { EventsModule } from '../../core/events/events.module';
import { GamificationModule } from '../gamification/gamification.module';

@Module({
  imports: [EventsModule, GamificationModule],
  controllers: [RaceController],
  providers: [RaceService],
  exports: [RaceService],
})
export class RaceModule {}
