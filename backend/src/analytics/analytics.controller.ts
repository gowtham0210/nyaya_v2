import { Controller, Get, HttpCode, Post, Query } from '@nestjs/common';
import { Inject } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser, Roles } from '../auth/decorators.js';
import type { AuthUser } from '../auth/auth-user.js';
import { DB, type Db } from '../core/db.js';
import { appOpens } from '../db/schema.js';
import { indiaToday } from '../learn/scoring.js';
import { AnalyticsOverviewDto, AnalyticsQuery } from './analytics.dto.js';
import { AnalyticsService } from './analytics.service.js';

@ApiTags('admin')
@ApiBearerAuth()
@Controller('admin/analytics')
@Roles('admin', 'analyst')
export class AnalyticsController {
  constructor(private readonly analytics: AnalyticsService) {}

  @Get('overview')
  @ApiOperation({
    summary:
      'Learners, activity, retention, quizzes and content health, calculated from what the app already records',
  })
  @ApiOkResponse({ type: AnalyticsOverviewDto })
  overview(@Query() query: AnalyticsQuery) {
    return this.analytics.overview(query.days ?? 30);
  }
}

@ApiTags('me')
@ApiBearerAuth()
@Controller('me')
export class AppOpenController {
  constructor(@Inject(DB) private readonly db: Db) {}

  @Post('app-open')
  @HttpCode(204)
  @ApiOperation({
    summary:
      'Note that the learner opened the app today (once a day; used for retention)',
  })
  @ApiNoContentResponse()
  async appOpen(@CurrentUser() user: AuthUser) {
    await this.db
      .insert(appOpens)
      .values({ userId: user.id, day: indiaToday(new Date()) })
      .onConflictDoNothing();
  }
}
