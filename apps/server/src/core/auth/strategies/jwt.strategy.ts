import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { JwtPayload } from '../types';
import { AuthService } from '../auth.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(config: ConfigService, private readonly auth: AuthService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.getOrThrow<string>('JWT_SECRET'),
    });
  }

  async validate(payload: JwtPayload): Promise<JwtPayload> {
    // A logged-out (or rotated-away) session must not keep its access token alive.
    if (!(await this.auth.isSessionActive(payload.sessionId))) {
      throw new UnauthorizedException('Session has ended');
    }
    return {
      sub: payload.sub,
      email: payload.email,
      sessionId: payload.sessionId,
      ...(payload.scope && { scope: payload.scope }),
    };
  }
}
