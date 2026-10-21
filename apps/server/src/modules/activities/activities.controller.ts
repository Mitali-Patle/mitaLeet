import { Controller, Get, Query } from '@nestjs/common';
import { ActivitiesService } from './activities.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../../core/auth/types';
import { FeedQueryDto } from '../../common/dto/query.dto';

@Controller('activities')
export class ActivitiesController {
  constructor(private readonly activitiesService: ActivitiesService) {}

  @Get('feed')
  getFeed(@CurrentUser() user: JwtPayload, @Query() q: FeedQueryDto) {
    return this.activitiesService.getFeed(user.sub, q.limit, q.cursor);
  }

  @Get('me')
  getMyActivity(@CurrentUser() user: JwtPayload) {
    return this.activitiesService.getByUser(user.sub);
  }
}
