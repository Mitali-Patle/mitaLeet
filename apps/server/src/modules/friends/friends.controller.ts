import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
} from '@nestjs/common';
import { FriendsService } from './friends.service';
import {
  SendFriendRequestDto,
  RespondFriendRequestDto,
} from './dto/friends.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../../core/auth/types';
import { RateLimit } from '../../common/throttle/rate-limit';

@Controller('friends')
export class FriendsController {
  constructor(private readonly friendsService: FriendsService) {}

  @Get()
  getFriends(@CurrentUser() user: JwtPayload) {
    return this.friendsService.getFriends(user.sub);
  }

  @Get('requests/incoming')
  getIncoming(@CurrentUser() user: JwtPayload) {
    return this.friendsService.getIncomingRequests(user.sub);
  }

  @Get('requests/outgoing')
  getOutgoing(@CurrentUser() user: JwtPayload) {
    return this.friendsService.getOutgoingRequests(user.sub);
  }

  @RateLimit(30)
  @Get('search')
  search(
    @CurrentUser() user: JwtPayload,
    @Query('q') query: string,
    @Query('limit') limit?: number,
  ) {
    return this.friendsService.searchUsers(user.sub, query, limit);
  }

  @Get('mutual/:userId')
  getMutual(
    @CurrentUser() user: JwtPayload,
    @Param('userId') otherUserId: string,
  ) {
    return this.friendsService.getMutualFriends(user.sub, otherUserId);
  }

  @RateLimit(30)
  @Post('requests')
  sendRequest(
    @CurrentUser() user: JwtPayload,
    @Body() dto: SendFriendRequestDto,
  ) {
    return this.friendsService.sendRequest(user.sub, dto);
  }

  @Put('requests/:id')
  respondToRequest(
    @CurrentUser() user: JwtPayload,
    @Param('id') requestId: string,
    @Body() dto: RespondFriendRequestDto,
  ) {
    return this.friendsService.respondToRequest(user.sub, requestId, dto.action);
  }

  @Delete('requests/:id')
  cancelRequest(
    @CurrentUser() user: JwtPayload,
    @Param('id') requestId: string,
  ) {
    return this.friendsService.cancelRequest(user.sub, requestId);
  }

  @Delete(':friendId')
  removeFriend(
    @CurrentUser() user: JwtPayload,
    @Param('friendId') friendId: string,
  ) {
    return this.friendsService.removeFriend(user.sub, friendId);
  }
}
