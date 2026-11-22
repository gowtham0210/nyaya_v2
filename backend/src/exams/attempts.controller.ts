import {
  Body,
  Controller,
  Get,
  HttpCode,
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnModuleDestroy,
  Param,
  ParseIntPipe,
  ParseUUIDPipe,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentActor, Roles } from '../auth/decorators.js';
import { AuditService, type Actor } from '../core/audit.service.js';
import { Inject } from '@nestjs/common';
import { DB, type Db } from '../core/db.js';
import {
  AttemptDto,
  AttemptPageDto,
  AttemptResultDto,
  AttemptStatsDto,
  ListAttemptsQuery,
  SaveAnswersDto,
  SaveAnswersResultDto,
  SaveOneAnswerDto,
  StartAttemptDto,
} from './attempts.dto.js';
import { AttemptsService } from './attempts.service.js';

const Id = () => Param('id', new ParseUUIDPipe());

/**
 * A learner's formal exam attempts. Every route works only on the caller's own
 * attempts (someone else's is "not found"). Nothing here sends an answer key
 * or explanation before the attempt is submitted.
 */
@ApiTags('exam-attempts')
@ApiBearerAuth()
@Controller()
export class AttemptsController {
  constructor(private readonly attempts: AttemptsService) {}

  @Post('exams/:slug/attempts')
  @ApiOperation({
    summary:
      'Start a fixed-paper or random-mock attempt. The server fixes the questions, option order and (timed) deadline.',
  })
  @ApiCreatedResponse({ type: AttemptDto })
  start(
    @CurrentActor() actor: Actor,
    @Param('slug') slug: string,
    @Body() dto: StartAttemptDto,
  ) {
    return this.attempts.start(actor, slug, dto);
  }

  @Get('exams/:slug/attempts/active')
  @ApiOperation({
    summary: 'The unfinished attempt for this exam, to resume it',
  })
  @ApiOkResponse({ type: AttemptDto })
  active(@CurrentActor() actor: Actor, @Param('slug') slug: string) {
    return this.attempts.active(actor.id, slug);
  }

  // Declared before ':id' so "stats" is not read as an id.
  @Get('me/exam-attempts/stats')
  @ApiOkResponse({ type: AttemptStatsDto })
  stats(@CurrentActor() actor: Actor) {
    return this.attempts.stats(actor.id);
  }

  @Get('me/exam-attempts')
  @ApiOperation({ summary: 'Attempt history, newest first' })
  @ApiOkResponse({ type: AttemptPageDto })
  history(@CurrentActor() actor: Actor, @Query() query: ListAttemptsQuery) {
    return this.attempts.history(actor.id, query);
  }

  @Get('me/exam-attempts/:id')
  @ApiOkResponse({ type: AttemptDto })
  get(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.attempts.get(actor.id, id);
  }

  @Put('me/exam-attempts/:id/answers')
  @ApiOperation({
    summary:
      'Save several answers at once (autosave). Each carries a counter; an older one never overwrites a newer one. Refused after submission or expiry.',
  })
  @ApiOkResponse({ type: SaveAnswersResultDto })
  saveMany(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() dto: SaveAnswersDto,
  ) {
    return this.attempts.saveAnswers(actor.id, id, dto);
  }

  @Put('me/exam-attempts/:id/answers/:position')
  @ApiOperation({ summary: 'Save one answer' })
  @ApiOkResponse({ type: SaveAnswersResultDto })
  saveOne(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Param('position', ParseIntPipe) position: number,
    @Body() dto: SaveOneAnswerDto,
  ) {
    return this.attempts.saveAnswers(actor.id, id, {
      answers: [{ position, ...dto }],
    });
  }

  @Post('me/exam-attempts/:id/advance-section')
  @HttpCode(200)
  @ApiOperation({
    summary:
      'Locked-order exams only: close the current section and open the next',
  })
  @ApiOkResponse({ type: AttemptDto })
  advance(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.attempts.advanceSection(actor.id, id);
  }

  @Post('me/exam-attempts/:id/submit')
  @HttpCode(200)
  @ApiOperation({
    summary:
      'Submit the attempt. Repeating the request returns the same result.',
  })
  @ApiOkResponse({ type: AttemptResultDto })
  submit(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.attempts.submit(actor, id);
  }

  @Get('me/exam-attempts/:id/result')
  @ApiOkResponse({ type: AttemptResultDto })
  result(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.attempts.result(actor.id, id);
  }

  @Get('me/exam-attempts/:id/review')
  @ApiOperation({
    summary:
      'Every question with the accepted answers and explanation. Only after the attempt is submitted or expired.',
  })
  @ApiOkResponse({ type: Object })
  review(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.attempts.review(actor.id, id);
  }
}

/** Staff control of the expiry sweep. */
@ApiTags('admin')
@ApiBearerAuth()
@Controller('admin')
export class AttemptsAdminController {
  constructor(
    private readonly attempts: AttemptsService,
    private readonly audit: AuditService,
    @Inject(DB) private readonly db: Db,
  ) {}

  @Post('exam-attempts/sweep')
  @Roles('admin')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Finish every unfinished attempt whose deadline has passed',
  })
  @ApiOkResponse({ type: Object })
  async sweep(@CurrentActor() actor: Actor) {
    const finalised = await this.attempts.sweepExpired();
    await this.db.transaction((tx) =>
      this.audit.record(tx, actor, {
        action: 'exam_attempt.sweep_run',
        entityType: 'exam_attempt',
        data: { finalised },
      }),
    );
    return { finalised };
  }
}

/**
 * No scheduler exists in this project, so expired attempts are finished in
 * two ways: lazily whenever they are touched, and by this low-frequency
 * timer. Several instances may run it: finalising is locked and idempotent.
 * EXAM_SWEEP_SECONDS sets the period (default 300; 0 turns it off). It never
 * starts under the test runner, which calls the sweep directly.
 */
@Injectable()
export class AttemptSweeper implements OnApplicationBootstrap, OnModuleDestroy {
  private readonly log = new Logger(AttemptSweeper.name);
  private timer?: NodeJS.Timeout;

  constructor(private readonly attempts: AttemptsService) {}

  onApplicationBootstrap() {
    if (process.env.VITEST) return;
    const seconds = Number(process.env.EXAM_SWEEP_SECONDS ?? 300);
    if (!Number.isFinite(seconds) || seconds <= 0) return;
    this.timer = setInterval(() => {
      this.attempts
        .sweepExpired()
        .then((n) => n && this.log.log(`Finished ${n} expired exam attempt(s)`))
        .catch((e) => this.log.error(`Expiry sweep failed: ${String(e)}`));
    }, seconds * 1000);
    this.timer.unref();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }
}
