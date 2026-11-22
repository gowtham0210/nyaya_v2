import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
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
import { ExamEligibilityService } from './exam-eligibility.service.js';
import {
  BlueprintDto,
  CreateBlueprintDto,
  CreateExamDto,
  ExamDetailDto,
  ExamDto,
  ExamEligibilityDto,
  ExamEligibilityQuery,
  ExamListDto,
  ReplaceSectionsDto,
  UpdateBlueprintDto,
  UpdateExamDto,
} from './exams.dto.js';
import { ExamsService } from './exams.service.js';

const Id = () => Param('id', new ParseUUIDPipe());

/**
 * Setup of the mock exams, for staff. Nothing here is visible to learners:
 * exams start switched off, blueprints start as drafts, and no blueprint is
 * ever chosen as "current" automatically.
 */
@ApiTags('admin')
@ApiBearerAuth()
@Controller('admin')
export class ExamsController {
  constructor(
    private readonly exams: ExamsService,
    private readonly eligibility: ExamEligibilityService,
  ) {}

  @Get('exams')
  @Roles(...READ_ROLES)
  @ApiOkResponse({ type: ExamListDto })
  list() {
    return this.exams.listExams();
  }

  @Get('exams/:id')
  @Roles(...READ_ROLES)
  @ApiOkResponse({ type: ExamDetailDto })
  get(@Id() id: string) {
    return this.exams.getExam(id);
  }

  @Post('exams')
  @Roles('admin')
  @HttpCode(201)
  @ApiOperation({
    summary: 'Create an exam (AIBE, CLAT or AILET), switched off',
  })
  @ApiCreatedResponse({ type: ExamDto })
  create(@CurrentActor() actor: Actor, @Body() body: CreateExamDto) {
    return this.exams.createExam(actor, body);
  }

  @Patch('exams/:id')
  @Roles('admin')
  @ApiOperation({
    summary: 'Edit an exam; switching it on needs a published blueprint',
  })
  @ApiOkResponse({ type: ExamDto })
  update(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: UpdateExamDto,
  ) {
    return this.exams.updateExam(actor, id, body);
  }

  @Get('exams/:examId/questions/:questionId/eligibility')
  @Roles(...READ_ROLES)
  @ApiOperation({
    summary:
      'Whether a question could be drawn for a randomised mock of this exam, and every reason it could not',
  })
  @ApiOkResponse({ type: ExamEligibilityDto })
  async eligible(
    @Param('examId', new ParseUUIDPipe()) examId: string,
    @Param('questionId', new ParseUUIDPipe()) questionId: string,
    @Query() query: ExamEligibilityQuery,
  ): Promise<ExamEligibilityDto> {
    const rule = await this.exams.lawRegimeFilterOf(examId, query.blueprint_id);
    const r = await this.eligibility.explain(examId, questionId, {
      language: query.language ?? 'en',
      now: new Date(),
      lawRegimeFilter: rule.filter,
    });
    return {
      eligible: r.eligible,
      exam_only: r.examOnly,
      law_regime: r.lawRegime,
      law_regime_filter: rule.filter,
      blueprint_id: rule.blueprintId,
      reasons: r.reasons,
    };
  }

  @Get('exam-blueprints/:id')
  @Roles(...READ_ROLES)
  @ApiOkResponse({ type: BlueprintDto })
  blueprint(@Id() id: string) {
    return this.exams.getBlueprint(id);
  }

  @Post('exam-blueprints')
  @Roles('admin')
  @HttpCode(201)
  @ApiOperation({
    summary: 'Create the first version of a blueprint, as a draft',
  })
  @ApiCreatedResponse({ type: BlueprintDto })
  createBlueprint(
    @CurrentActor() actor: Actor,
    @Body() body: CreateBlueprintDto,
  ) {
    return this.exams.createBlueprint(actor, body);
  }

  @Patch('exam-blueprints/:id')
  @Roles('admin')
  @ApiOperation({ summary: 'Edit a draft blueprint' })
  @ApiOkResponse({ type: BlueprintDto })
  updateBlueprint(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: UpdateBlueprintDto,
  ) {
    return this.exams.updateBlueprint(actor, id, body);
  }

  @Put('exam-blueprints/:id/sections')
  @Roles('admin')
  @ApiOperation({
    summary: "Replace a draft blueprint's sections and topic quotas",
  })
  @ApiOkResponse({ type: BlueprintDto })
  sections(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: ReplaceSectionsDto,
  ) {
    return this.exams.replaceSections(actor, id, body);
  }

  @Post('exam-blueprints/:id/publish')
  @Roles('publisher', 'admin')
  @HttpCode(200)
  @ApiOperation({
    summary:
      'Publish a draft. It becomes read-only. Only an official-confirmed blueprint can be used for timed mocks.',
  })
  @ApiOkResponse({ type: BlueprintDto })
  publish(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.exams.publishBlueprint(actor, id);
  }

  @Post('exam-blueprints/:id/retire')
  @Roles('admin')
  @HttpCode(200)
  @ApiOkResponse({ type: BlueprintDto })
  retire(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.exams.retireBlueprint(actor, id);
  }

  @Post('exam-blueprints/:id/make-current')
  @Roles('admin')
  @HttpCode(200)
  @ApiOperation({
    summary:
      'Make a published blueprint the one randomised mocks of its exam use, replacing the previous one. Audited.',
  })
  @ApiOkResponse({ type: BlueprintDto })
  makeCurrent(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.exams.makeCurrent(actor, id);
  }

  @Post('exam-blueprints/:id/clear-current')
  @Roles('admin')
  @HttpCode(200)
  @ApiOperation({
    summary:
      'Take the current mark off a blueprint. The exam then has no current blueprint and randomised mocks are refused. Audited.',
  })
  @ApiOkResponse({ type: BlueprintDto })
  clearCurrent(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.exams.clearCurrent(actor, id);
  }

  @Post('exam-blueprints/:id/new-version')
  @Roles('admin')
  @HttpCode(201)
  @ApiOperation({
    summary: 'Copy a published or retired blueprint into a new draft version',
  })
  @ApiCreatedResponse({ type: BlueprintDto })
  newVersion(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.exams.newVersion(actor, id);
  }
}
