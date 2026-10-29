import { Module } from '@nestjs/common';
import { LearnController } from './learn.controller.js';
import { LeagueService } from './league.service.js';
import { LearnService } from './learn.service.js';

@Module({
  controllers: [LearnController],
  providers: [LearnService, LeagueService],
})
export class LearnModule {}
