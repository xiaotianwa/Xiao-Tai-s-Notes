import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { Request, Response } from 'express';

import type { ApiErrorDetail, ApiErrorResponse } from '../response';

interface ValidationErrorPayload {
  message?: string | string[];
  error?: string;
  statusCode?: number;
}

const httpStatusCode = {
  badRequest: Number(HttpStatus.BAD_REQUEST),
  unauthorized: Number(HttpStatus.UNAUTHORIZED),
  forbidden: Number(HttpStatus.FORBIDDEN),
  notFound: Number(HttpStatus.NOT_FOUND),
  conflict: Number(HttpStatus.CONFLICT),
  unprocessableEntity: Number(HttpStatus.UNPROCESSABLE_ENTITY),
  tooManyRequests: Number(HttpStatus.TOO_MANY_REQUESTS),
  internalServerError: Number(HttpStatus.INTERNAL_SERVER_ERROR),
};

@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(ApiExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const requestId = randomUUID();
    const status = this.getStatus(exception);
    const payload = this.buildPayload(exception, status, requestId);

    if (status >= httpStatusCode.internalServerError) {
      this.logger.error(
        `requestId=${requestId} ${request.method} ${request.url}`,
        exception instanceof Error ? exception.stack : String(exception),
      );
    }

    response.status(status).json(payload);
  }

  private getStatus(exception: unknown): number {
    if (exception instanceof HttpException) {
      return exception.getStatus();
    }
    return HttpStatus.INTERNAL_SERVER_ERROR;
  }

  private buildPayload(
    exception: unknown,
    status: number,
    requestId: string,
  ): ApiErrorResponse {
    if (exception instanceof HttpException) {
      const exceptionResponse = exception.getResponse();
      const normalized = this.normalizeExceptionResponse(exceptionResponse);
      return {
        code: this.mapStatusToCode(status),
        data: null,
        message: normalized.message,
        ...(normalized.details.length > 0 ? { details: normalized.details } : {}),
        ...(status >= httpStatusCode.internalServerError ? { requestId } : {}),
      };
    }

    return {
      code: 50000,
      data: null,
      message: '服务暂时不可用，请稍后重试',
      requestId,
    };
  }

  private normalizeExceptionResponse(response: string | object): {
    message: string;
    details: ApiErrorDetail[];
  } {
    if (typeof response === 'string') {
      return { message: response, details: [] };
    }

    const payload = response as ValidationErrorPayload;
    if (Array.isArray(payload.message)) {
      const reasons = payload.message.filter(
        (item): item is string => typeof item === 'string' && item.length > 0,
      );
      const summary =
        reasons.length > 0
          ? `密码大于8位}`
          : payload.error ?? '密码不对';
      return {
        message: summary,
        details: reasons.map((reason) => ({ reason })),
      };
    }

    return {
      message:
        (typeof payload.message === 'string' && payload.message) ||
        payload.error ||
        '请求处理失败',
      details: [],
    };
  }

  private mapStatusToCode(status: number): number {
    if (status === httpStatusCode.badRequest) return 40001;
    if (status === httpStatusCode.unauthorized) return 40100;
    if (status === httpStatusCode.forbidden) return 40300;
    if (status === httpStatusCode.notFound) return 40400;
    if (status === httpStatusCode.conflict) return 40900;
    if (status === httpStatusCode.unprocessableEntity) return 42200;
    if (status === httpStatusCode.tooManyRequests) return 42900;
    if (status >= httpStatusCode.internalServerError) return 50000;
    return status * 100;
  }
}
