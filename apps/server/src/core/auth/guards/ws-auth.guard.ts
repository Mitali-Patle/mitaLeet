import { CanActivate, ExecutionContext, Injectable, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { WsException } from '@nestjs/websockets';
import { Socket } from 'socket.io';
import { JwtPayload } from '../types';

@Injectable()
export class WsAuthGuard implements CanActivate {
  private readonly logger = new Logger(WsAuthGuard.name);

  constructor(private jwtService: JwtService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const client: Socket = context.switchToWs().getClient();
    const token = this.extractToken(client);

    if (!token) {
      throw new WsException('Missing authentication token');
    }

    try {
      const payload = await this.jwtService.verifyAsync<JwtPayload>(token);
      (client as any).user = payload;
      return true;
    } catch {
      this.logger.warn(`WS auth failed for socket ${client.id}`);
      throw new WsException('Invalid authentication token');
    }
  }

  private extractToken(client: Socket): string | null {
    const auth = client.handshake?.headers?.authorization;
    if (auth && auth.startsWith('Bearer ')) {
      return auth.slice(7);
    }
    const queryToken = client.handshake?.auth?.token;
    return queryToken || null;
  }
}
