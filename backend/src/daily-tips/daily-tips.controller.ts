import {
  Body,
  Controller,
  Get,
  Header,
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
import { CurrentActor, CurrentUser, Public, Roles } from '../auth/decorators.js';
import type { Actor } from '../core/audit.service.js';
import {
  CreateDailyTipDto,
  DailyTipDetailDto,
  DailyTipPageDto,
  ListTipsQuery,
  PublicDailyTipDto,
  TipReasonDto,
  TodayTipDto,
  TodayTipQuery,
  UpdateDailyTipDto,
} from './daily-tips.dto.js';
import { DailyTipsService } from './daily-tips.service.js';
import { TIP_ACTIONS, TIP_READ_ROLES } from './workflow.js';

const Id = () => Param('id', new ParseUUIDPipe());

/** The Home screen's Daily Tip. Public: no account needed to read it. */
@ApiTags('daily-tips')
@Controller('daily-tips')
export class DailyTipsController {
  constructor(private readonly tips: DailyTipsService) {}

  // Declared before ':id' so "today" is not read as an id.
  @Public()
  @Get('today')
  // The answer changes at midnight in India, so no cache may keep yesterday's;
  // clients and proxies must check again (the ETag still saves the bytes).
  @Header('Cache-Control', 'no-cache')
  @ApiOperation({
    summary: "Today's published tip (India date); tip is null when there is none",
  })
  @ApiOkResponse({ type: TodayTipDto })
  today(@Query() query: TodayTipQuery) {
    return this.tips.today(query.language);
  }

  @Public()
  @Get(':id')
  @ApiOperation({ summary: 'One published tip whose day has come' })
  @ApiOkResponse({ type: PublicDailyTipDto })
  get(@Id() id: string) {
    return this.tips.published(id);
  }
}

@ApiTags('editor')
@ApiBearerAuth()
@Controller('editor/daily-tips')
export class EditorDailyTipsController {
  constructor(private readonly tips: DailyTipsService) {}

  @Get()
  @Roles(...TIP_READ_ROLES)
  @ApiOkResponse({ type: DailyTipPageDto })
  list(@Query() query: ListTipsQuery) {
    return this.tips.list(query);
  }

  @Get(':id')
  @Roles(...TIP_READ_ROLES)
  @ApiOkResponse({ type: DailyTipDetailDto })
  get(@Id() id: string) {
    return this.tips.get(id);
  }

  @Post()
  @Roles(...TIP_ACTIONS.edit.roles)
  @ApiOperation({ summary: 'Start a daily tip as a draft' })
  @ApiCreatedResponse({ type: DailyTipDetailDto })
  create(@CurrentActor() actor: Actor, @Body() body: CreateDailyTipDto) {
    return this.tips.create(actor, body);
  }

  @Patch(':id')
  @Roles(...TIP_ACTIONS.edit.roles)
  @ApiOperation({ summary: 'Edit a draft, or one with changes requested' })
  @ApiOkResponse({ type: DailyTipDetailDto })
  update(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: UpdateDailyTipDto,
  ) {
    return this.tips.update(actor, id, body);
  }

  @Post(':id/submit')
  @HttpCode(200)
  @Roles(...TIP_ACTIONS.submit.roles)
  @ApiOperation({ summary: 'Send the tip for legal review' })
  @ApiOkResponse({ type: DailyTipDetailDto })
  submit(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.tips.submit(actor, id);
  }

  @Post(':id/request-changes')
  @HttpCode(200)
  @Roles(...TIP_ACTIONS.request_changes.roles)
  @ApiOkResponse({ type: DailyTipDetailDto })
  requestChanges(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: TipReasonDto,
  ) {
    return this.tips.requestChanges(actor, id, body.reason);
  }

  @Post(':id/approve')
  @HttpCode(200)
  @Roles(...TIP_ACTIONS.approve.roles)
  @ApiOperation({
    summary:
      'Approve the tip under review (not your own, unless you are an admin)',
  })
  @ApiOkResponse({ type: DailyTipDetailDto })
  approve(
    @CurrentActor() actor: Actor,
    @CurrentUser() user: AuthUser,
    @Id() id: string,
  ) {
    return this.tips.approve(actor, id, user.roles.includes('admin'));
  }

  @Post(':id/publish')
  @HttpCode(200)
  @Roles(...TIP_ACTIONS.publish.roles)
  @ApiOperation({
    summary: 'Publish the approved tip; the app shows it on its publish date',
  })
  @ApiOkResponse({ type: DailyTipDetailDto })
  publish(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.tips.publish(actor, id);
  }

  @Post(':id/revise')
  @HttpCode(200)
  @Roles(...TIP_ACTIONS.revise.roles)
  @ApiOperation({
    summary:
      'Take a published or retired tip back to draft to correct it; it leaves the app until published again',
  })
  @ApiOkResponse({ type: DailyTipDetailDto })
  revise(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: TipReasonDto,
  ) {
    return this.tips.revise(actor, id, body.reason);
  }

  @Post(':id/retire')
  @HttpCode(200)
  @Roles(...TIP_ACTIONS.retire.roles)
  @ApiOperation({ summary: 'Take a published tip off the app' })
  @ApiOkResponse({ type: DailyTipDetailDto })
  retire(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: TipReasonDto,
  ) {
    return this.tips.retire(actor, id, body.reason);
  }
}
