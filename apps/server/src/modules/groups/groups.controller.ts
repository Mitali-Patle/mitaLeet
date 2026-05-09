import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
} from '@nestjs/common';
import { GroupsService } from './groups.service';
import { CreateGroupDto, JoinGroupDto } from './dto/groups.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../../core/auth/types';

@Controller('groups')
export class GroupsController {
  constructor(private readonly groupsService: GroupsService) {}

  @Post()
  create(@CurrentUser() user: JwtPayload, @Body() dto: CreateGroupDto) {
    return this.groupsService.create(user.sub, dto);
  }

  @Post('join')
  joinByCode(@CurrentUser() user: JwtPayload, @Body() dto: JoinGroupDto) {
    return this.groupsService.joinByCode(user.sub, dto);
  }

  @Get()
  getMyGroups(@CurrentUser() user: JwtPayload) {
    return this.groupsService.getMyGroups(user.sub);
  }

  @Get(':id')
  getById(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.groupsService.getById(id, user.sub);
  }

  @Get(':id/leaderboard')
  getLeaderboard(@Param('id') id: string) {
    return this.groupsService.getLeaderboard(id);
  }

  @Get(':id/activity')
  getActivity(@Param('id') id: string) {
    return this.groupsService.getActivity(id);
  }

  @Delete(':id/leave')
  leave(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.groupsService.leave(user.sub, id);
  }

  @Put(':id/members/:memberId/promote')
  promote(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Param('memberId') memberId: string,
  ) {
    return this.groupsService.promoteMember(user.sub, id, memberId);
  }

  @Put(':id/members/:memberId/demote')
  demote(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Param('memberId') memberId: string,
  ) {
    return this.groupsService.demoteMember(user.sub, id, memberId);
  }

  @Delete(':id/members/:memberId')
  removeMember(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Param('memberId') memberId: string,
  ) {
    return this.groupsService.removeMember(user.sub, id, memberId);
  }

  @Put(':id/transfer/:newOwnerId')
  transfer(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Param('newOwnerId') newOwnerId: string,
  ) {
    return this.groupsService.transferOwnership(user.sub, id, newOwnerId);
  }

  @Post(':id/regenerate-code')
  regenerateCode(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.groupsService.regenerateCode(user.sub, id);
  }
}
