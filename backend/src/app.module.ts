import { DynamicModule, Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ThrottlerModule } from '@nestjs/throttler';
import { AuthModule } from './auth/auth.module.js';
import type { AppConfig } from './core/config.js';
import { CoreModule } from './core/core.module.js';
import { LearnModule } from './learn/learn.module.js';
import { QuestionsModule } from './questions/questions.module.js';
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
        // Only applied where ThrottlerGuard is used (sign-in and refresh).
        ThrottlerModule.forRoot([
          { ttl: 60_000, limit: config.authRateLimitPerMinute },
        ]),
        AuthModule,
        TaxonomyModule,
        QuestionsModule,
        LearnModule,
      ],
    };
  }
}
