import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import type { AuthUser } from '../auth/auth-user.js';
import { CurrentActor, CurrentUser, Roles } from '../auth/decorators.js';
import type { Actor } from '../core/audit.service.js';
import { ApiError } from '../core/errors.js';
import type { Role } from '../db/schema.js';
import {
  ApproveDto,
  BulkActionDto,
  BulkResultDto,
  CreateQuestionDto,
  ListQuestionsQuery,
  QuestionDetailDto,
  QuestionPageDto,
  ReasonDto,
  ReviseDto,
  UpdateQuestionDto,
} from './questions.dto.js';
import { QuestionsService } from './questions.service.js';
import { ACTIONS, READ_ROLES } from './workflow.js';

const Id = () => Param('id', new ParseUUIDPipe());

@ApiTags('editor')
@ApiBearerAuth()
@Controller('editor/questions')
export class QuestionsController {
  constructor(private readonly questions: QuestionsService) {}

  @Get()
  @Roles(...READ_ROLES)
  @ApiOkResponse({ type: QuestionPageDto })
  list(@Query() query: ListQuestionsQuery) {
    return this.questions.list(query);
  }

  @Get(':id')
  @Roles(...READ_ROLES)
  @ApiOkResponse({ type: QuestionDetailDto })
  get(@Id() id: string) {
    return this.questions.get(id);
  }

  @Post()
  @Roles(...ACTIONS.edit.roles)
  @ApiOperation({ summary: 'Create a question as a draft (version 1)' })
  @ApiCreatedResponse({ type: QuestionDetailDto })
  create(@CurrentActor() actor: Actor, @Body() body: CreateQuestionDto) {
    return this.questions.create(actor, body);
  }

  @Patch(':id')
  @Roles(...ACTIONS.edit.roles)
  @ApiOperation({
    summary:
      'Edit the latest version while it is a draft or has changes requested',
  })
  @ApiOkResponse({ type: QuestionDetailDto })
  update(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: UpdateQuestionDto,
  ) {
    return this.questions.update(actor, id, body);
  }

  @Post('bulk')
  @HttpCode(200)
  @Roles(
    ...new Set([
      ...ACTIONS.submit.roles,
      ...ACTIONS.approve.roles,
      ...ACTIONS.publish.roles,
    ]),
  )
  @ApiOperation({
    summary:
      'Submit, approve or publish many questions; each is checked and run on its own',
  })
  @ApiOkResponse({ type: BulkResultDto })
  bulk(
    @CurrentActor() actor: Actor,
    @CurrentUser() user: AuthUser,
    @Body() body: BulkActionDto,
  ) {
    const roles: readonly Role[] = ACTIONS[body.action].roles;
    if (!roles.some((r) => user.roles.includes(r))) throw ApiError.forbidden();
    return this.questions.bulk(actor, body);
  }

  @Post(':id/submit')
  @HttpCode(200)
  @Roles(...ACTIONS.submit.roles)
  @ApiOperation({ summary: 'Send the latest version for legal review' })
  @ApiOkResponse({ type: QuestionDetailDto })
  submit(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.questions.submit(actor, id);
  }

  @Post(':id/request-changes')
  @HttpCode(200)
  @Roles(...ACTIONS.request_changes.roles)
  @ApiOkResponse({ type: QuestionDetailDto })
  requestChanges(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: ReasonDto,
  ) {
    return this.questions.requestChanges(actor, id, body.reason);
  }

  @Post(':id/approve')
  @HttpCode(200)
  @Roles(...ACTIONS.approve.roles)
  @ApiOperation({ summary: 'Approve the version under review (not your own)' })
  @ApiOkResponse({ type: QuestionDetailDto })
  approve(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: ApproveDto,
  ) {
    return this.questions.approve(actor, id, body.note);
  }

  @Post(':id/publish')
  @HttpCode(200)
  @Roles(...ACTIONS.publish.roles)
  @ApiOperation({
    summary:
      'Publish the approved version; the previous live version is superseded',
  })
  @ApiOkResponse({ type: QuestionDetailDto })
  publish(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.questions.publish(actor, id);
  }

  @Post(':id/revise')
  @HttpCode(200)
  @Roles(...ACTIONS.revise.roles)
  @ApiOperation({
    summary: 'Start a new draft version from the published (or retired) one',
  })
  @ApiOkResponse({ type: QuestionDetailDto })
  revise(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: ReviseDto,
  ) {
    return this.questions.revise(actor, id, body.change_note);
  }

  @Post(':id/retire')
  @HttpCode(200)
  @Roles('publisher', 'admin')
  @ApiOperation({ summary: 'Take the live version down' })
  @ApiOkResponse({ type: QuestionDetailDto })
  retire(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: ReasonDto,
  ) {
    return this.questions.retire(actor, id, body.reason);
  }
}
