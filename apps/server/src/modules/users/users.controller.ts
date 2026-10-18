import {
  Controller,
  Get,
  Put,
  Post,
  Delete,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { UsersService } from './users.service';
import { UpdateProfileDto, RegisterDeviceDto } from './dto/users.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../../core/auth/types';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  getMe(@CurrentUser() user: JwtPayload) {
    return this.usersService.getMe(user.sub);
  }

  @Put('me/profile')
  updateProfile(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.usersService.updateProfile(user.sub, dto);
  }

  @Get(':username')
  getByUsername(@Param('username') username: string) {
    return this.usersService.getByUsername(username);
  }

  @Post('me/devices')
  registerDevice(
    @CurrentUser() user: JwtPayload,
    @Body() dto: RegisterDeviceDto,
  ) {
    return this.usersService.registerDevice(user.sub, dto);
  }

  @Delete('me/devices/:token')
  unregisterDevice(@CurrentUser() user: JwtPayload, @Param('token') token: string) {
    return this.usersService.unregisterDevice(user.sub, token);
  }
}
