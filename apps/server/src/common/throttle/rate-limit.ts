import { ExecutionContext, Injectable } from '@nestjs/common';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';

/**
 * Rate limits are counted per authenticated user when there is one (registered
 * after the JWT guard, so req.user is set), otherwise per client IP.
 * Mobile users behind one carrier NAT therefore do not share a bucket.
 */
@Injectable()
export class UserOrIpThrottlerGuard extends ThrottlerGuard {
  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (context.getType() !== 'http') return true; // sockets are not request/response
    return super.canActivate(context);
  }

  protected async getTracker(req: Record<string, any>): Promise<string> {
    return req.user?.sub ? `user:${req.user.sub}` : `ip:${req.ip}`;
  }
}

/** Override the default limit for one route: `limit` requests per `seconds`. */
export const RateLimit = (limit: number, seconds = 60) =>
  Throttle({ default: { limit, ttl: seconds * 1000 } });
