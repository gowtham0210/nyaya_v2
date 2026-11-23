import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseIntPipe,
  ParseUUIDPipe,
  Patch,
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
import type { Actor } from '../core/audit.service.js';
import { READ_ROLES } from '../questions/workflow.js';
import { MockPlanService } from './mock-plan.service.js';
import {
  AddKeyHistoryDto,
  CreatePaperDto,
  KeyHistoryEntryDto,
  LearnerListPapersQuery,
  LearnerPaperDetailDto,
  LearnerPaperPageDto,
  ListPapersQuery,
  MockPlanRequestDto,
  PaperDetailDto,
  PaperDto,
  PaperPageDto,
  PaperReadinessDto,
  ReplacePositionsDto,
  UpdatePaperDto,
} from './papers.dto.js';
import { PapersService } from './papers.service.js';

const Id = () => Param('id', new ParseUUIDPipe());

/**
 * Fixed previous-year papers and randomised-mock planning, for staff.
 * Writes are admin-only; reads may be done by anyone who can read questions.
 */
@ApiTags('admin')
@ApiBearerAuth()
@Controller('admin')
export class PapersAdminController {
  constructor(
    private readonly papers: PapersService,
    private readonly plans: MockPlanService,
  ) {}

  @Get('exam-papers')
  @Roles(...READ_ROLES)
  @ApiOkResponse({ type: PaperPageDto })
  list(@Query() query: ListPapersQuery) {
    return this.papers.list(query);
  }

  @Get('exam-papers/:id')
  @Roles(...READ_ROLES)
  @ApiOperation({
    summary:
      'A paper with every position, its effective key and key history (staff only)',
  })
  @ApiOkResponse({ type: PaperDetailDto })
  get(@Id() id: string) {
    return this.papers.get(id);
  }

  @Get('exam-papers/:id/readiness')
  @Roles(...READ_ROLES)
  @ApiOperation({ summary: 'What would stop this draft being published' })
  @ApiOkResponse({ type: PaperReadinessDto })
  readiness(@Id() id: string) {
    return this.papers.readiness(id);
  }

  @Post('exam-papers')
  @Roles('admin')
  @ApiCreatedResponse({ type: PaperDto })
  create(@CurrentActor() actor: Actor, @Body() dto: CreatePaperDto) {
    return this.papers.create(actor, dto);
  }

  @Patch('exam-papers/:id')
  @Roles('admin')
  @ApiOperation({
    summary: 'Edit a draft paper; a frozen paper is refused (409 paper_frozen)',
  })
  @ApiOkResponse({ type: PaperDto })
  update(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() dto: UpdatePaperDto,
  ) {
    return this.papers.update(actor, id, dto);
  }

  @Put('exam-papers/:id/positions')
  @Roles('admin')
  @ApiOperation({
    summary:
      'Set the positions of a draft: pin exact question versions, or leave a withdrawn placeholder',
  })
  @ApiOkResponse({ type: PaperDetailDto })
  positions(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() dto: ReplacePositionsDto,
  ) {
    return this.papers.replacePositions(actor, id, dto.positions);
  }

  @Post('exam-papers/:id/positions/:position/key-history')
  @Roles('admin')
  @ApiOperation({
    summary:
      'Record what the official key said for a position, with its source (draft papers only)',
  })
  @ApiCreatedResponse({ type: KeyHistoryEntryDto })
  key(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Param('position', ParseIntPipe) position: number,
    @Body() dto: AddKeyHistoryDto,
  ) {
    return this.papers.addKeyHistory(actor, id, position, dto);
  }

  @Post('exam-papers/:id/publish')
  @Roles('publisher', 'admin')
  @HttpCode(200)
  @ApiOperation({
    summary:
      'Freeze a complete draft; it can then only be superseded by a revision',
  })
  @ApiOkResponse({ type: PaperDto })
  publish(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.papers.publish(actor, id);
  }

  @Post('exam-papers/:id/retire')
  @Roles('admin')
  @HttpCode(200)
  @ApiOkResponse({ type: PaperDto })
  retire(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.papers.retire(actor, id);
  }

  @Post('exam-papers/:id/revise')
  @Roles('admin')
  @ApiOperation({ summary: 'Start a new draft revision of a frozen paper' })
  @ApiCreatedResponse({ type: PaperDetailDto })
  revise(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.papers.revise(actor, id);
  }

  @Get('exams/:examId/mock-readiness')
  @Roles(...READ_ROLES)
  @ApiOperation({
    summary:
      "Whether a randomised mock could be built from the exam's current blueprint now, with per-topic pool sizes",
  })
  @ApiOkResponse({ type: Object })
  readinessOfMock(
    @Param('examId', new ParseUUIDPipe()) examId: string,
    @Query('language') language?: string,
  ) {
    return this.plans.readiness(examId, language);
  }

  @Post('exams/:examId/mock-plans')
  @Roles(...READ_ROLES)
  @HttpCode(200)
  @ApiOperation({
    summary:
      'Build (and return, without saving) a randomised mock plan. Question ids and option orders only; repeat with the returned seed to get the same plan.',
  })
  @ApiOkResponse({ type: Object })
  plan(
    @Param('examId', new ParseUUIDPipe()) examId: string,
    @Body() dto: MockPlanRequestDto,
  ) {
    return this.plans.generate(examId, dto);
  }
}

/** Published fixed papers, for learners of an active exam. Never includes keys. */
@ApiTags('exams')
@ApiBearerAuth()
@Controller('exams')
export class PapersLearnerController {
  constructor(private readonly papers: PapersService) {}

  @Get(':slug/papers')
  @ApiOkResponse({ type: LearnerPaperPageDto })
  list(@Param('slug') slug: string, @Query() query: LearnerListPapersQuery) {
    return this.papers.listPublished(slug, query);
  }

  @Get(':slug/papers/:id')
  @ApiOperation({
    summary:
      'A published paper in its original order. No answer keys or explanations; withdrawn positions are placeholders.',
  })
  @ApiOkResponse({ type: LearnerPaperDetailDto })
  get(@Param('slug') slug: string, @Id() id: string) {
    return this.papers.getPublished(slug, id);
  }
}
