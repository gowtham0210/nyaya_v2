import { Module } from '@nestjs/common';
import { ContentSourcesController } from './content-sources.controller.js';
import { ContentSourcesService } from './content-sources.service.js';
import { ExamEligibilityService } from './exam-eligibility.service.js';
import { ExamsController } from './exams.controller.js';
import {
  AttemptsAdminController,
  AttemptsController,
  AttemptSweeper,
} from './attempts.controller.js';
import { AttemptsService } from './attempts.service.js';
import { ExamsService } from './exams.service.js';
import { MockPlanService } from './mock-plan.service.js';
import {
  PapersAdminController,
  PapersLearnerController,
} from './papers.controller.js';
import { PapersService } from './papers.service.js';

/** Mock exam setup: exams, blueprints, content sources and pool eligibility. */
@Module({
  controllers: [
    ExamsController,
    ContentSourcesController,
    PapersAdminController,
    PapersLearnerController,
    AttemptsController,
    AttemptsAdminController,
  ],
  providers: [
    ExamsService,
    ContentSourcesService,
    ExamEligibilityService,
    PapersService,
    MockPlanService,
    AttemptsService,
    AttemptSweeper,
  ],
  exports: [
    ExamsService,
    ExamEligibilityService,
    PapersService,
    MockPlanService,
  ],
})
export class ExamsModule {}
