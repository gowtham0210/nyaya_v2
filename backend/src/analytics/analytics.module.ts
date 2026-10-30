import { Module } from '@nestjs/common';
import {
  AnalyticsController,
  AppOpenController,
} from './analytics.controller.js';
import { AnalyticsService } from './analytics.service.js';

@Module({
  controllers: [AnalyticsController, AppOpenController],
  providers: [AnalyticsService],
})
export class AnalyticsModule {}
