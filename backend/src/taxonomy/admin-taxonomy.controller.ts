import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
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
  AdminTaxonomyDto,
  CreateActDto,
  CreateSubjectDto,
  CreateTopicDto,
  UpdateActDto,
  UpdateSubjectDto,
  UpdateTopicDto,
} from './admin-taxonomy.dto.js';
import { AdminTaxonomyService } from './admin-taxonomy.service.js';

const Id = () => Param('id', new ParseUUIDPipe());

/**
 * Subjects shape the learners' Case Path road, so only admins change them.
 * Editors manage topics and acts. Every change returns the whole taxonomy.
 */
@ApiTags('admin')
@ApiBearerAuth()
@Controller('admin')
export class AdminTaxonomyController {
  constructor(private readonly taxonomy: AdminTaxonomyService) {}

  @Get('taxonomy')
  @Roles(...READ_ROLES)
  @ApiOperation({
    summary:
      'Every subject, topic and act, hidden ones included, with question counts',
  })
  @ApiOkResponse({ type: AdminTaxonomyDto })
  overview() {
    return this.taxonomy.overview();
  }

  @Post('subjects')
  @Roles('admin')
  @ApiOperation({ summary: 'Add a subject; it starts hidden from learners' })
  @ApiCreatedResponse({ type: AdminTaxonomyDto })
  createSubject(@CurrentActor() actor: Actor, @Body() body: CreateSubjectDto) {
    return this.taxonomy.createSubject(actor, body);
  }

  @Patch('subjects/:id')
  @Roles('admin')
  @ApiOkResponse({ type: AdminTaxonomyDto })
  updateSubject(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: UpdateSubjectDto,
  ) {
    return this.taxonomy.updateSubject(actor, id, body);
  }

  @Post('topics')
  @Roles('content_editor', 'admin')
  @ApiCreatedResponse({ type: AdminTaxonomyDto })
  createTopic(@CurrentActor() actor: Actor, @Body() body: CreateTopicDto) {
    return this.taxonomy.createTopic(actor, body);
  }

  @Patch('topics/:id')
  @Roles('content_editor', 'admin')
  @ApiOkResponse({ type: AdminTaxonomyDto })
  updateTopic(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: UpdateTopicDto,
  ) {
    return this.taxonomy.updateTopic(actor, id, body);
  }

  @Post('acts')
  @Roles('content_editor', 'admin')
  @ApiCreatedResponse({ type: AdminTaxonomyDto })
  createAct(@CurrentActor() actor: Actor, @Body() body: CreateActDto) {
    return this.taxonomy.createAct(actor, body);
  }

  @Patch('acts/:id')
  @Roles('content_editor', 'admin')
  @ApiOkResponse({ type: AdminTaxonomyDto })
  updateAct(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: UpdateActDto,
  ) {
    return this.taxonomy.updateAct(actor, id, body);
  }
}
