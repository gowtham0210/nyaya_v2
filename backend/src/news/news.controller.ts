import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
  Res,
  StreamableFile,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiBearerAuth,
  ApiBody,
  ApiConsumes,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiOperation,
  ApiProduces,
  ApiTags,
} from '@nestjs/swagger';
import type { Response } from 'express';
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
import { MAX_PICTURE_BYTES } from './card-picture.js';
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

  @Public()
  @Get(':id/image')
  @ApiOperation({ summary: "A published article's card picture (WebP)" })
  @ApiProduces('image/webp')
  @ApiOkResponse({ schema: { type: 'string', format: 'binary' } })
  async image(@Id() id: string, @Res({ passthrough: true }) res: Response) {
    const p = await this.news.picture(id, { publishedOnly: true });
    // The address carries the version, so a cached copy never goes stale.
    res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    res.setHeader('ETag', `"${p.version}"`);
    return new StreamableFile(p.data, { type: 'image/webp' });
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

  @Get(':id/image')
  @Roles(...NEWS_READ_ROLES)
  @ApiOperation({
    summary: "The article's card picture (WebP), whatever its status",
  })
  @ApiProduces('image/webp')
  @ApiOkResponse({ schema: { type: 'string', format: 'binary' } })
  async image(@Id() id: string, @Res({ passthrough: true }) res: Response) {
    const p = await this.news.picture(id, { publishedOnly: false });
    res.setHeader('Cache-Control', 'private, max-age=3600');
    res.setHeader('ETag', `"${p.version}"`);
    return new StreamableFile(p.data, { type: 'image/webp' });
  }

  @Put(':id/image')
  @Roles(...NEWS_ACTIONS.edit.roles)
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: MAX_PICTURE_BYTES, files: 1 },
    }),
  )
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file'],
      properties: {
        file: {
          type: 'string',
          format: 'binary',
          description:
            'JPEG, PNG or WebP, at most 5 MB and at least 480 pixels wide; stored as WebP, at most 1200 pixels',
        },
      },
    },
  })
  @ApiOperation({
    summary: 'Set the card picture of a draft, or one with changes requested',
  })
  @ApiOkResponse({ type: NewsDetailDto })
  setImage(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @UploadedFile() file: { buffer: Buffer } | undefined,
  ) {
    return this.news.setPicture(actor, id, file?.buffer);
  }

  @Delete(':id/image')
  @Roles(...NEWS_ACTIONS.edit.roles)
  @ApiOperation({
    summary:
      'Remove the card picture of a draft, or one with changes requested',
  })
  @ApiOkResponse({ type: NewsDetailDto })
  removeImage(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.news.removePicture(actor, id);
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
