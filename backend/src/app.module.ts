import { DynamicModule, Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ThrottlerModule } from '@nestjs/throttler';
import { AppConfigModule } from './appconfig/appconfig.module.js';
import { AnalyticsModule } from './analytics/analytics.module.js';
import { AuthModule } from './auth/auth.module.js';
import { ChatModule } from './chat/chat.module.js';
import { ImportsModule } from './imports/imports.module.js';
import type { AppConfig } from './core/config.js';
import { CoreModule } from './core/core.module.js';
import { LearnModule } from './learn/learn.module.js';
import { NewsModule } from './news/news.module.js';
import { RateLimitStore, SharedThrottlerStorage } from './core/rate-limits.js';
import { QuestionsModule } from './questions/questions.module.js';
import { ReportsModule } from './reports/reports.module.js';
import { StaffModule } from './staff/staff.module.js';
import { TaxonomyModule } from './taxonomy/taxonomy.module.js';

@Module({})
export class AppModule {
  static register(config: AppConfig): DynamicModule {
    return {
      module: AppModule,
      imports: [
        CoreModule.register(config),
        JwtModule.register({
          global: true,
          secret: config.jwtSecret,
          signOptions: {
            expiresIn: config.accessTokenTtlSec,
            algorithm: 'HS256',
          },
          verifyOptions: { algorithms: ['HS256'] },
        }),
        // Only applied where AuthThrottlerGuard is used (sign-in, refresh and
        // the like). Counts live in Postgres so every API copy shares them.
        ThrottlerModule.forRootAsync({
          inject: [RateLimitStore],
          useFactory: (store: RateLimitStore) => ({
            throttlers: [{ ttl: 60_000, limit: config.authRateLimitPerMinute }],
            storage: new SharedThrottlerStorage(store),
          }),
        }),
        AuthModule,
        AppConfigModule,
        TaxonomyModule,
        ImportsModule,
        StaffModule,
        AnalyticsModule,
        QuestionsModule,
        LearnModule,
        ChatModule,
        ReportsModule,
        NewsModule,
      ],
    };
  }
}
