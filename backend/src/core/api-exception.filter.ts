import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import type { Request, Response } from 'express';

const CODES: Record<number, string> = {
  400: 'bad_request',
  401: 'unauthenticated',
  403: 'forbidden',
  404: 'not_found',
  409: 'conflict',
  413: 'payload_too_large',
  422: 'validation_failed',
  429: 'rate_limited',
};

/** Renders every error as `{ code, message, details, request_id }`, never a stack trace. */
@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger('Http');

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const req = ctx.getRequest<Request>();
    const res = ctx.getResponse<Response>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let code = 'internal_error';
    let message = 'Something went wrong';
    let details: unknown;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const body = exception.getResponse();
      code = CODES[status] ?? (status >= 500 ? 'internal_error' : 'error');
      if (typeof body === 'object' && body !== null) {
        const b = body as Record<string, unknown>;
        if (typeof b.code === 'string') code = b.code;
        if (typeof b.message === 'string') message = b.message;
        details = b.details;
      } else {
        message = String(body);
      }
    }
    if (status >= 500) {
      this.logger.error(
        `${req.method} ${req.path} failed [request_id=${req.id}]`,
        exception instanceof Error ? exception.stack : String(exception),
      );
    }

    res
      .status(status)
      .json({ code, message, details: details ?? null, request_id: req.id });
  }
}
