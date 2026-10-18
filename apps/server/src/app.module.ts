import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerModule } from '@nestjs/throttler';
import { PrismaModule } from './core/prisma/prisma.module';
import { AuthModule } from './core/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { FriendsModule } from './modules/friends/friends.module';
import { GroupsModule } from './modules/groups/groups.module';
import { ActivitiesModule } from './modules/activities/activities.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { EventsModule } from './core/events/events.module';
import { LeetCodeModule } from './modules/leetcode/leetcode.module';
import { GamificationModule } from './modules/gamification/gamification.module';
import { RaceModule } from './modules/race/race.module';
import { AnalyticsModule } from './modules/analytics/analytics.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
      // Tests configure everything through process.env and must never pick
      // up a developer's real credentials from a local .env file.
      ignoreEnvFile: process.env.NODE_ENV === 'test',
    }),
    ScheduleModule.forRoot(),
    // Default: 120 requests/minute per user (or IP). Sensitive routes override
    // this with @RateLimit(). In-memory, i.e. per instance; see the scaling plan.
    ThrottlerModule.forRoot({
      throttlers: [{ name: 'default', ttl: 60_000, limit: 120 }],
      skipIf: () => process.env.THROTTLE_DISABLED === 'true',
    }),
    PrismaModule,
    AuthModule,
    EventsModule,
    UsersModule,
    FriendsModule,
    GroupsModule,
    ActivitiesModule,
    NotificationsModule,
    LeetCodeModule,
    GamificationModule,
    RaceModule,
    AnalyticsModule,
  ],
})
export class AppModule {}
