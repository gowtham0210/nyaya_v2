import { Module } from '@nestjs/common';
import { DuelService } from './duel.service.js';
import { LearnController } from './learn.controller.js';
import { LeaderboardService } from './leaderboard.service.js';
import { LeagueService } from './league.service.js';
import { LearnService } from './learn.service.js';
import { ReviewController } from './review.controller.js';
import { ReviewService } from './review.service.js';

@Module({
  controllers: [LearnController, ReviewController],
  providers: [
    LearnService,
    LeagueService,
    LeaderboardService,
    ReviewService,
    DuelService,
  ],
  exports: [DuelService],
})
export class LearnModule {}
