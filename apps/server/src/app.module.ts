import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
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
    ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
    ScheduleModule.forRoot(),
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
