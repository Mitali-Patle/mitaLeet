import { Controller, Get } from '@nestjs/common';
import { AnalyticsService } from './analytics.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../../core/auth/types';

@Controller('analytics')
export class AnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  @Get()
  getAnalytics(@CurrentUser() user: JwtPayload) {
    return this.analyticsService.getUserAnalytics(user.sub);
  }

  @Get('insights')
  getInsights(@CurrentUser() user: JwtPayload) {
    return this.analyticsService.getInsights(user.sub);
  }
}
