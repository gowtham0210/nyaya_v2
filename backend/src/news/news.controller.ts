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
import { CurrentActor, Public, Roles } from '../auth/decorators.js';
import type { Actor } from '../core/audit.service.js';
import {
  CreateNewsDto,
  ListNewsQuery,
  NewsDetailDto,
  NewsPageDto,
  NewsReasonDto,
  PublicNewsListDto,
  UpdateNewsDto,
} from './news.dto.js';
import { NewsService } from './news.service.js';
import { NEWS_ACTIONS, NEWS_READ_ROLES } from './workflow.js';

const Id = () => Param('id', new ParseUUIDPipe());

/** The app's Updates tab. Public: no account needed to read the news. */
@ApiTags('news')
@Controller('news')
export class NewsController {
  constructor(private readonly news: NewsService) {}

  @Public()
  @Get()
  @ApiOperation({ summary: 'Published legal news, newest first' })
  @ApiOkResponse({ type: PublicNewsListDto })
  list() {
    return this.news.published();
  }
}

@ApiTags('editor')
@ApiBearerAuth()
@Controller('editor/news')
export class EditorNewsController {
  constructor(private readonly news: NewsService) {}

  @Get()
  @Roles(...NEWS_READ_ROLES)
  @ApiOkResponse({ type: NewsPageDto })
  list(@Query() query: ListNewsQuery) {
    return this.news.list(query);
  }

  @Get(':id')
  @Roles(...NEWS_READ_ROLES)
  @ApiOkResponse({ type: NewsDetailDto })
  get(@Id() id: string) {
    return this.news.get(id);
  }

  @Post()
  @Roles(...NEWS_ACTIONS.edit.roles)
  @ApiOperation({ summary: 'Start a news article as a draft' })
  @ApiCreatedResponse({ type: NewsDetailDto })
  create(@CurrentActor() actor: Actor, @Body() body: CreateNewsDto) {
    return this.news.create(actor, body);
  }

  @Patch(':id')
  @Roles(...NEWS_ACTIONS.edit.roles)
  @ApiOperation({ summary: 'Edit a draft, or one with changes requested' })
  @ApiOkResponse({ type: NewsDetailDto })
  update(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: UpdateNewsDto,
  ) {
    return this.news.update(actor, id, body);
  }

  @Post(':id/submit')
  @HttpCode(200)
  @Roles(...NEWS_ACTIONS.submit.roles)
  @ApiOperation({ summary: 'Send the article for legal review' })
  @ApiOkResponse({ type: NewsDetailDto })
  submit(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.news.submit(actor, id);
  }

  @Post(':id/request-changes')
  @HttpCode(200)
  @Roles(...NEWS_ACTIONS.request_changes.roles)
  @ApiOkResponse({ type: NewsDetailDto })
  requestChanges(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: NewsReasonDto,
  ) {
    return this.news.requestChanges(actor, id, body.reason);
  }

  @Post(':id/approve')
  @HttpCode(200)
  @Roles(...NEWS_ACTIONS.approve.roles)
  @ApiOperation({ summary: 'Approve the article under review (not your own)' })
  @ApiOkResponse({ type: NewsDetailDto })
  approve(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.news.approve(actor, id);
  }

  @Post(':id/publish')
  @HttpCode(200)
  @Roles(...NEWS_ACTIONS.publish.roles)
  @ApiOperation({ summary: 'Show the approved article in the app' })
  @ApiOkResponse({ type: NewsDetailDto })
  publish(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.news.publish(actor, id);
  }

  @Post(':id/revise')
  @HttpCode(200)
  @Roles(...NEWS_ACTIONS.revise.roles)
  @ApiOperation({
    summary:
      'Take a published or retired article back to draft to correct it; it leaves the app until published again',
  })
  @ApiOkResponse({ type: NewsDetailDto })
  revise(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: NewsReasonDto,
  ) {
    return this.news.revise(actor, id, body.reason);
  }

  @Post(':id/retire')
  @HttpCode(200)
  @Roles(...NEWS_ACTIONS.retire.roles)
  @ApiOperation({ summary: 'Take a published article off the app' })
  @ApiOkResponse({ type: NewsDetailDto })
  retire(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: NewsReasonDto,
  ) {
    return this.news.retire(actor, id, body.reason);
  }
}
