import {
  Controller,
  Get,
  Put,
  Post,
  Delete,
  Body,
  Param,
  UseGuards,
  HttpCode,
} from '@nestjs/common';
import { UsersService } from './users.service';
import { UpdateProfileDto, RegisterDeviceDto, DeleteAccountDto } from './dto/users.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../../core/auth/types';
import { AllowExtensionToken } from '../../common/decorators/allow-extension-token.decorator';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @AllowExtensionToken() // the extension popup shows who it is linked to
  @Get('me')
  getMe(@CurrentUser() user: JwtPayload) {
    return this.usersService.getMe(user.sub);
  }

  /** Permanently delete the caller's account and data (app-store requirement). */
  @Delete('me')
  @HttpCode(204)
  async deleteMe(@CurrentUser() user: JwtPayload, @Body() _dto: DeleteAccountDto) {
    await this.usersService.deleteAccount(user.sub);
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
