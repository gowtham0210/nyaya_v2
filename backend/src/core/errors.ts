import { HttpException, HttpStatus } from '@nestjs/common';

export interface ErrorDetail {
  field?: string;
  reason: string;
}

/** An error carrying the API's standard `{ code, message, details }` body. */
export class ApiError extends HttpException {
  constructor(
    status: HttpStatus,
    readonly code: string,
    message: string,
    readonly details?: ErrorDetail[],
  ) {
    super({ code, message, details }, status);
  }

  static notFound(what: string) {
    return new ApiError(HttpStatus.NOT_FOUND, 'not_found', `${what} not found`);
  }

  static forbidden(message = 'You do not have permission to do this') {
    return new ApiError(HttpStatus.FORBIDDEN, 'forbidden', message);
  }

  static invalidTransition(message: string) {
    return new ApiError(HttpStatus.CONFLICT, 'invalid_transition', message);
  }

  static incomplete(details: ErrorDetail[]) {
    return new ApiError(
      HttpStatus.UNPROCESSABLE_ENTITY,
      'content_incomplete',
      'The question is missing information required for this step',
      details,
    );
  }
}

/** Postgres unique_violation, possibly wrapped by the query builder. */
export const isUniqueViolation = (e: unknown): boolean => {
  for (let x: any = e; x; x = x.cause) if (x.code === '23505') return true;
  return false;
};
