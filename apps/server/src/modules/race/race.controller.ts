import { Controller, Get, Post, Body, Param, Patch } from '@nestjs/common';
import { RaceService } from './race.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../../core/auth/types';

@Controller('races')
export class RaceController {
  constructor(private readonly raceService: RaceService) {}

  @Post()
  create(@CurrentUser() user: JwtPayload, @Body() body: { problemSlug: string; problemName?: string }) {
    return this.raceService.createRoom(user.sub, body.problemSlug, body.problemName);
  }

  @Post('join')
  join(@CurrentUser() user: JwtPayload, @Body() body: { code: string }) {
    return this.raceService.joinRoom(user.sub, body.code);
  }

  @Post(':id/start')
  start(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.raceService.startRace(user.sub, id);
  }

  @Patch(':id/status')
  updateStatus(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body('status') status: string,
  ) {
    return this.raceService.updateStatus(user.sub, id, status);
  }

  @Post(':id/solve')
  submitSolve(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.raceService.submitSolve(user.sub, id);
  }

  @Get(':id')
  getRoom(@Param('id') id: string) {
    return this.raceService.getRoom(id);
  }

  @Get()
  getUserRaces(@CurrentUser() user: JwtPayload) {
    return this.raceService.getUserRaces(user.sub);
  }
}
