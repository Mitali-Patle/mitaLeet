import { Controller, Get, Query } from '@nestjs/common';
import { ActivitiesService } from './activities.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../../core/auth/types';

@Controller('activities')
export class ActivitiesController {
  constructor(private readonly activitiesService: ActivitiesService) {}

  @Get('feed')
  getFeed(
    @CurrentUser() user: JwtPayload,
    @Query('limit') limit?: number,
    @Query('cursor') cursor?: string,
  ) {
    return this.activitiesService.getFeed(user.sub, limit, cursor);
  }

  @Get('me')
  getMyActivity(@CurrentUser() user: JwtPayload) {
    return this.activitiesService.getByUser(user.sub);
  }
}
