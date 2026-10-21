import { Controller, Get, Post, Body, Param, Patch } from '@nestjs/common';
import { RaceService } from './race.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../../core/auth/types';
import { CreateRaceDto, JoinRaceDto, UpdateRaceStatusDto } from './dto/race.dto';
import { RateLimit } from '../../common/throttle/rate-limit';

@Controller('races')
export class RaceController {
  constructor(private readonly raceService: RaceService) {}

  @RateLimit(20)
  @Post()
  create(@CurrentUser() user: JwtPayload, @Body() body: CreateRaceDto) {
    return this.raceService.createRoom(user.sub, body.problemSlug, body.problemName);
  }

  @RateLimit(20)
  @Post('join')
  join(@CurrentUser() user: JwtPayload, @Body() body: JoinRaceDto) {
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
    @Body() body: UpdateRaceStatusDto,
  ) {
    return this.raceService.updateStatus(user.sub, id, body.status);
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
