import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtStrategy } from './strategies/jwt.strategy';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { WsAuthGuard } from './guards/ws-auth.guard';
import { UserOrIpThrottlerGuard } from '../../common/throttle/rate-limit';
import { ExtensionScopeGuard } from './guards/extension-scope.guard';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
        signOptions: {
          expiresIn: config.get<string>('JWT_ACCESS_EXPIRATION', '15m') as any,
        },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtStrategy,
    WsAuthGuard,
    // Apply JwtAuthGuard globally — use @Public() to bypass
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
    // Extension tokens may only reach routes marked @AllowExtensionToken().
    {
      provide: APP_GUARD,
      useClass: ExtensionScopeGuard,
    },
    // Registered after the JWT guard so limits can be keyed by user.
    {
      provide: APP_GUARD,
      useClass: UserOrIpThrottlerGuard,
    },
  ],
  exports: [AuthService, JwtModule, WsAuthGuard],
})
export class AuthModule {}
