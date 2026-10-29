import { Module } from '@nestjs/common';
import { LearnController } from './learn.controller.js';
import { LeagueService } from './league.service.js';
import { LearnService } from './learn.service.js';
import { ReviewController } from './review.controller.js';
import { ReviewService } from './review.service.js';

@Module({
  controllers: [LearnController, ReviewController],
  providers: [LearnService, LeagueService, ReviewService],
})
export class LearnModule {}
