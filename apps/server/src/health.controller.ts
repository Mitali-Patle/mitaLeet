import { Controller, Get, HttpCode, ServiceUnavailableException } from '@nestjs/common';
import { Public } from './common/decorators/public.decorator';
import { PrismaService } from './core/prisma/prisma.service';
import { SkipThrottle } from '@nestjs/throttler';

/**
 * Health endpoints (outside /api/v1).
 * /health      — readiness: process is up AND the database answers. Used by
 *                Render's health check, so a deploy that cannot reach the DB
 *                never receives traffic.
 * /health/live — liveness: the process is responding (no dependencies).
 */
@Public()
@SkipThrottle()
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  @HttpCode(200)
  async ready() {
    const started = Date.now();
    try {
      await Promise.race([
        this.prisma.$queryRaw`SELECT 1`,
        new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 3_000)),
      ]);
    } catch {
      throw new ServiceUnavailableException({ status: 'error', database: 'unreachable' });
    }
    return { status: 'ok', database: 'ok', dbLatencyMs: Date.now() - started, timestamp: new Date().toISOString() };
  }

  @Get('live')
  live() {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }
}
