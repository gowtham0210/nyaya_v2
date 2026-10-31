import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
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
import { CurrentActor, CurrentUser, Public } from '../auth/decorators.js';
import type { Actor } from '../core/audit.service.js';
import {
  AllTimeDto,
  AnswerDto,
  AnswerResultDto,
  AttemptPageDto,
  AttemptsQuery,
  CatalogDto,
  CatalogQuery,
  LeagueDto,
  ProgressDto,
  ResultDto,
  SessionDto,
  SettingsDto,
  StartSessionDto,
} from './learn.dto.js';
import { LeaderboardService } from './leaderboard.service.js';
import { LeagueService } from './league.service.js';
import { LearnService } from './learn.service.js';

const Id = () => Param('id', new ParseUUIDPipe());

@ApiTags('learn')
@Controller()
export class LearnController {
  constructor(
    private readonly learn: LearnService,
    private readonly league: LeagueService,
    private readonly leaderboard: LeaderboardService,
  ) {}

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
  @Post('quiz-sessions/:id/abandon')
  @HttpCode(204)
  @ApiOperation({
    summary:
      'Leave before the first answer: the quiz is removed and its energy comes back',
  })
  abandon(@CurrentUser() user: AuthUser, @Id() id: string) {
    return this.learn.abandon(user.id, id);
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

  @ApiBearerAuth()
  @Get('me/league')
  @ApiOperation({
    summary:
      "This week's league group (real learners, topped up with practice players) and last week's result",
  })
  @ApiOkResponse({ type: LeagueDto })
  leagueView(@CurrentUser() user: AuthUser) {
    return this.league.view(user.id);
  }

  @ApiBearerAuth()
  @Get('me/leaderboard/all-time')
  @ApiOperation({
    summary:
      'All-time board: the top 50 learners by total XP, and where the learner stands',
  })
  @ApiOkResponse({ type: AllTimeDto })
  allTime(@CurrentUser() user: AuthUser) {
    return this.leaderboard.allTime(user.id);
  }

  @ApiBearerAuth()
  @Post('me/energy/refill')
  @HttpCode(200)
  @ApiOperation({ summary: 'Spend 30 coins on 1 energy for today' })
  @ApiOkResponse({ type: ProgressDto })
  refill(@CurrentUser() user: AuthUser) {
    return this.learn.refillEnergy(user.id);
  }

  @ApiBearerAuth()
  @Post('me/streak-freezes')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Spend 100 coins on a streak freeze (at most 2 held)',
  })
  @ApiOkResponse({ type: ProgressDto })
  buyStreakFreeze(@CurrentUser() user: AuthUser) {
    return this.learn.buyStreakFreeze(user.id);
  }

  @ApiBearerAuth()
  @Post('me/premium')
  @HttpCode(200)
  @ApiOperation({
    summary:
      'Turn on demo premium (testing only; replaced by store receipt checks before launch)',
  })
  @ApiOkResponse({ type: ProgressDto })
  startPremium(@CurrentActor() actor: Actor) {
    return this.learn.setPremium(actor, true);
  }

  @ApiBearerAuth()
  @Delete('me/premium')
  @ApiOperation({ summary: 'Turn off demo premium' })
  @ApiOkResponse({ type: ProgressDto })
  endPremium(@CurrentActor() actor: Actor) {
    return this.learn.setPremium(actor, false);
  }

  @ApiBearerAuth()
  @Get('me/settings')
  @ApiOperation({ summary: 'Learning settings; null until saved once' })
  @ApiOkResponse({ type: SettingsDto })
  getSettings(@CurrentUser() user: AuthUser) {
    return this.learn.settings(this.learn.database, user.id);
  }

  @ApiBearerAuth()
  @Put('me/settings')
  @ApiOperation({
    summary:
      'Save learning settings (name, persona, language, daily goal, onboarded)',
  })
  @ApiOkResponse({ type: SettingsDto })
  saveSettings(@CurrentUser() user: AuthUser, @Body() body: SettingsDto) {
    return this.learn.saveSettings(user.id, body);
  }
}
