import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    const message =
      exception instanceof HttpException
        ? exception.getResponse()
        : 'Internal server error';

    const errorResponse = {
      success: false,
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url.split('?')[0],
      method: request.method,
      requestId: (request as any).id,
      message:
        typeof message === 'string'
          ? message
          : (message as Record<string, unknown>).message || 'Unknown error',
    };

    // Auth/permission/rate-limit rejections never reach the logging
    // interceptor (guards run first), so record them here for security review.
    if (status === 401 || status === 403 || status === 429) {
      this.logger.warn(
        `${request.method} ${request.url.split('?')[0]} ${status} rid=${(request as any).id ?? '-'} ip=${(request as any).clientIp ?? request.ip}`,
      );
    }

    if (status >= 500) {
      this.logger.error(
        `${request.method} ${request.url.split('?')[0]} ${status} rid=${(request as any).id ?? '-'}`,
        exception instanceof Error ? exception.stack : undefined,
      );
    }

    response.status(status).json(errorResponse);
  }
}
