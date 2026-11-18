import { Module } from '@nestjs/common';
import {
  DailyTipsController,
  EditorDailyTipsController,
} from './daily-tips.controller.js';
import { DailyTipsService } from './daily-tips.service.js';

@Module({
  controllers: [DailyTipsController, EditorDailyTipsController],
  providers: [DailyTipsService],
})
export class DailyTipsModule {}
