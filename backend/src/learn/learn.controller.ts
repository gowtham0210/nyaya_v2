import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiHeader,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import type { AuthUser } from '../auth/auth-user.js';
import { CurrentUser, Public } from '../auth/decorators.js';
import {
  AnswerDto,
  AnswerResultDto,
  AttemptPageDto,
  AttemptsQuery,
  CatalogDto,
  CatalogQuery,
  ProgressDto,
  ResultDto,
  SessionDto,
  StartSessionDto,
} from './learn.dto.js';
import { LearnService } from './learn.service.js';

const Id = () => Param('id', new ParseUUIDPipe());

@ApiTags('learn')
@Controller()
export class LearnController {
  constructor(private readonly learn: LearnService) {}

  @Public()
  @Get('quizzes')
  @ApiOperation({
    summary: 'Topics with published questions in force today, and how many',
  })
  @ApiOkResponse({ type: CatalogDto })
  catalog(@Query() query: CatalogQuery) {
    return this.learn.catalog(query.language);
  }

  @ApiBearerAuth()
  @Post('quiz-sessions')
  @ApiOperation({
    summary:
      'Start a quiz. The server picks the questions; no answer keys are returned.',
  })
  @ApiOkResponse({ type: SessionDto })
  @HttpCode(201)
  start(@CurrentUser() user: AuthUser, @Body() body: StartSessionDto) {
    return this.learn.start(user.id, body);
  }

  @ApiBearerAuth()
  @Get('quiz-sessions/:id')
  @ApiOperation({ summary: 'Current state of a session, for resuming' })
  @ApiOkResponse({ type: SessionDto })
  get(@CurrentUser() user: AuthUser, @Id() id: string) {
    return this.learn.get(user.id, id);
  }

  @ApiBearerAuth()
  @Post('quiz-sessions/:id/answers')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Save an answer',
    description:
      'Immediate mode: final, and the explanation comes back. Re-sending the same answer is a safe retry.',
  })
  @ApiOkResponse({ type: AnswerResultDto })
  answer(
    @CurrentUser() user: AuthUser,
    @Id() id: string,
    @Body() body: AnswerDto,
  ) {
    return this.learn.answer(user.id, id, body);
  }

  @ApiBearerAuth()
  @Post('quiz-sessions/:id/submit')
  @HttpCode(200)
  @ApiOperation({
    summary:
      'Finish and score the quiz. Idempotent: submitting again returns the same result.',
  })
  @ApiHeader({
    name: 'Idempotency-Key',
    required: false,
    description: 'Accepted; submit is idempotent per session anyway',
  })
  @ApiOkResponse({ type: ResultDto })
  submit(@CurrentUser() user: AuthUser, @Id() id: string) {
    return this.learn.submit(user.id, id);
  }

  @ApiBearerAuth()
  @Get('quiz-sessions/:id/result')
  @ApiOkResponse({ type: ResultDto })
  result(@CurrentUser() user: AuthUser, @Id() id: string) {
    return this.learn.result(user.id, id);
  }

  @ApiBearerAuth()
  @Get('me/attempts')
  @ApiOkResponse({ type: AttemptPageDto })
  attempts(@CurrentUser() user: AuthUser, @Query() query: AttemptsQuery) {
    return this.learn.attempts(user.id, query);
  }

  @ApiBearerAuth()
  @Get('me/progress')
  @ApiOperation({
    summary:
      'XP, streak, Case Path stars and chests, worked out from submitted quizzes',
  })
  @ApiOkResponse({ type: ProgressDto })
  progress(@CurrentUser() user: AuthUser) {
    return this.learn.progress(user.id);
  }

  @ApiBearerAuth()
  @Post('me/chests/:chest_id/open')
  @HttpCode(200)
  @ApiOperation({
    summary:
      'Open a chapter chest (e.g. constitution_chest) once its levels are done',
  })
  @ApiOkResponse({ type: ProgressDto })
  openChest(@CurrentUser() user: AuthUser, @Param('chest_id') chestId: string) {
    return this.learn.openChest(user.id, chestId);
  }
}
