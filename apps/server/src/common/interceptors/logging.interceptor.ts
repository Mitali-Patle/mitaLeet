import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  HttpException,
  Logger,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';

/**
 * One line per HTTP request, success or failure: method, path, status,
 * latency, request id and user id. Never logs bodies, headers or tokens.
 */
@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType() !== 'http') return next.handle();

    const request = context.switchToHttp().getRequest();
    const { method } = request;
    const path = (request.originalUrl ?? request.url ?? '').split('?')[0];
    const started = Date.now();
    const line = (status: number) =>
      `${method} ${path} ${status} ${Date.now() - started}ms rid=${request.id ?? '-'} uid=${request.user?.sub ?? '-'}`;

    return next.handle().pipe(
      tap({
        next: () => this.logger.log(line(context.switchToHttp().getResponse().statusCode)),
        error: (err: unknown) => {
          const status = err instanceof HttpException ? err.getStatus() : 500;
          if (status >= 500) this.logger.error(line(status));
          else this.logger.warn(line(status));
        },
      }),
    );
  }
}
