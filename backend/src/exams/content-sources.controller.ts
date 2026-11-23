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
import { CurrentActor, Roles } from '../auth/decorators.js';
import type { Actor } from '../core/audit.service.js';
import { READ_ROLES } from '../questions/workflow.js';
import {
  ContentSourceDto,
  ContentSourcePageDto,
  CreateContentSourceDto,
  ListContentSourcesQuery,
  UpdateContentSourceDto,
} from './content-sources.dto.js';
import { ContentSourcesService } from './content-sources.service.js';

const Id = () => Param('id', new ParseUUIDPipe());

@ApiTags('admin')
@ApiBearerAuth()
@Controller('admin/content-sources')
export class ContentSourcesController {
  constructor(private readonly sources: ContentSourcesService) {}

  @Get()
  @Roles(...READ_ROLES)
  @ApiOperation({ summary: 'Where content came from (attribution)' })
  @ApiOkResponse({ type: ContentSourcePageDto })
  list(@Query() query: ListContentSourcesQuery) {
    return this.sources.list(query);
  }

  @Get(':id')
  @Roles(...READ_ROLES)
  @ApiOkResponse({ type: ContentSourceDto })
  get(@Id() id: string) {
    return this.sources.get(id);
  }

  @Post()
  @Roles('admin')
  @HttpCode(201)
  @ApiOperation({
    summary: 'Record where content came from (attribution only)',
  })
  @ApiCreatedResponse({ type: ContentSourceDto })
  create(@CurrentActor() actor: Actor, @Body() body: CreateContentSourceDto) {
    return this.sources.create(actor, body);
  }

  @Patch(':id')
  @Roles('admin')
  @ApiOperation({
    summary: "Change a source's details",
  })
  @ApiOkResponse({ type: ContentSourceDto })
  update(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: UpdateContentSourceDto,
  ) {
    return this.sources.update(actor, id, body);
  }
}
