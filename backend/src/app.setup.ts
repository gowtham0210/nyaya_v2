import {
  HttpStatus,
  ValidationPipe,
  type INestApplication,
} from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import {
  DocumentBuilder,
  SwaggerModule,
  type OpenAPIObject,
} from '@nestjs/swagger';
import type { ValidationError } from 'class-validator';
import { AppModule } from './app.module.js';
import { ApiExceptionFilter } from './core/api-exception.filter.js';
import type { AppConfig } from './core/config.js';
import { ApiError } from './core/errors.js';
import { requestId } from './core/request-id.js';

function flatten(
  errors: ValidationError[],
  prefix = '',
): { field: string; reason: string }[] {
  return errors.flatMap((e) => {
    const field = prefix ? `${prefix}.${e.property}` : e.property;
    const own = Object.values(e.constraints ?? {}).map((reason) => ({
      field,
      reason,
    }));
    return [...own, ...flatten(e.children ?? [], field)];
  });
}

/** Builds the app with everything main.ts and the tests share. */
export async function createApp(
  config: AppConfig,
  opts: { logger?: false } = {},
): Promise<INestApplication> {
  const app = await NestFactory.create<NestExpressApplication>(
    AppModule.register(config),
    { logger: opts.logger },
  );
  if (config.trustProxyHops) app.set('trust proxy', config.trustProxyHops);
  app.setGlobalPrefix('v1');
  app.use(requestId);
  app.enableCors({
    origin: config.corsOrigins,
    exposedHeaders: ['X-Request-Id'],
  });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      exceptionFactory: (errors) =>
        new ApiError(
          HttpStatus.BAD_REQUEST,
          'validation_failed',
          'Request is invalid',
          flatten(errors),
        ),
    }),
  );
  app.useGlobalFilters(new ApiExceptionFilter());
  app.enableShutdownHooks();
  return app;
}

export function buildOpenApi(app: INestApplication): OpenAPIObject {
  const doc = new DocumentBuilder()
    .setTitle('Nyaya API')
    .setDescription(
      'Single write path for the Flutter app and the Content Management Portal. ' +
        'Errors use { code, message, details, request_id }. Timestamps are ISO-8601 UTC.',
    )
    .setVersion('0.1.0')
    .addBearerAuth()
    .build();
  return SwaggerModule.createDocument(app, doc);
}
