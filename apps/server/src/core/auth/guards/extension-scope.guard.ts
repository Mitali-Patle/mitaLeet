import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ALLOW_EXTENSION_TOKEN } from '../../../common/decorators/allow-extension-token.decorator';

/** Runs after the JWT guard: extension-scoped tokens only reach @AllowExtensionToken() routes. */
@Injectable()
export class ExtensionScopeGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    if (context.getType() !== 'http') return true;
    const user = context.switchToHttp().getRequest().user;
    if (user?.scope !== 'extension') return true;

    const allowed = this.reflector.getAllAndOverride<boolean>(ALLOW_EXTENSION_TOKEN, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!allowed) throw new ForbiddenException('Extension tokens can only report solves');
    return true;
  }
}
