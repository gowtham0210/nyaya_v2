import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
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
import { CurrentActor, Roles } from '../auth/decorators.js';
import type { Actor } from '../core/audit.service.js';
import { READ_ROLES } from '../questions/workflow.js';
import { MAX_IMPORT_BYTES } from './format.js';
import {
  CreateExamImportDto,
  CreateImportDto,
  ExamImportReportDto,
  ExportQuery,
  ImportJobListDto,
  ImportReportDto,
  PaperPositionsDto,
  TemplateQuery,
} from './imports.dto.js';
import { ImportsService } from './imports.service.js';

@ApiTags('admin')
@ApiBearerAuth()
@Controller('admin')
export class ImportsController {
  constructor(private readonly imports: ImportsService) {}

  @Post('import-jobs')
  @Roles('content_editor', 'admin')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: MAX_IMPORT_BYTES, files: 1 },
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
          description: '.csv (UTF-8) or .xlsx, at most 2 MB and 500 questions',
        },
        dry_run: {
          type: 'boolean',
          default: true,
          description:
            'Check the file and report what would happen, without saving anything',
        },
      },
    },
  })
  @ApiOperation({
    summary:
      'Check a .csv or .xlsx file of questions and, unless dry_run, import the valid new rows as drafts',
  })
  @ApiCreatedResponse({ type: ImportReportDto })
  create(
    @CurrentActor() actor: Actor,
    @UploadedFile() file: { originalname: string; buffer: Buffer } | undefined,
    @Body() body: CreateImportDto,
  ) {
    return this.imports.run(actor, file, body.dry_run ?? true);
  }

  @Post('exam-import-jobs')
  @Roles('content_editor', 'admin')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: MAX_IMPORT_BYTES, files: 1 },
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
            '.csv (UTF-8) or .xlsx with the usual question columns plus exam, exam_only, law_regime, concept_key, alternate_correct, lock_option_order',
        },
        dry_run: { type: 'boolean', default: true },
        exam: {
          type: 'string',
          example: 'aibe',
          description:
            'Exam slug for the whole file; fills blank exam cells and rejects rows naming another exam',
        },
        content_source_id: {
          type: 'string',
          format: 'uuid',
          description: 'Optional; recorded for attribution',
        },
      },
    },
  })
  @ApiOperation({
    summary:
      'Check a file of exam questions (row by row) and, unless dry_run, import the valid new rows as exam-only drafts. A content source can be named for attribution.',
  })
  @ApiCreatedResponse({ type: ExamImportReportDto })
  createExam(
    @CurrentActor() actor: Actor,
    @UploadedFile() file: { originalname: string; buffer: Buffer } | undefined,
    @Body() body: CreateExamImportDto,
  ) {
    return this.imports.runExam(
      actor,
      file,
      body.dry_run ?? true,
      body.content_source_id,
      body.exam,
    );
  }

  @Get('import-jobs')
  @Roles(...READ_ROLES)
  @ApiOkResponse({ type: ImportJobListDto })
  list() {
    return this.imports.list();
  }

  @Get('import-jobs/:id')
  @Roles(...READ_ROLES)
  @ApiOkResponse({ type: ImportReportDto })
  get(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.imports.report(id);
  }

  @Get('import-jobs/:id/paper-positions')
  @Roles(...READ_ROLES)
  @ApiOperation({
    summary:
      'Which rows of an import can be pinned in a fixed paper now (read only). Papers still accept only published questions.',
  })
  @ApiOkResponse({ type: PaperPositionsDto })
  paperPositions(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.imports.paperPositions(id);
  }

  @Get('import-templates')
  @Roles(...READ_ROLES)
  @ApiOperation({
    summary:
      'A blank import file (.xlsx with instructions and topic list, or .csv) for the general or the exam import',
  })
  @ApiProduces(
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/csv',
  )
  @ApiOkResponse({ schema: { type: 'string', format: 'binary' } })
  async template(@Query() query: TemplateQuery) {
    const f = await this.imports.templateFile(query);
    return new StreamableFile(f.body, {
      type: f.type,
      disposition: `attachment; filename="${f.fileName}"`,
    });
  }

  @Get('question-export')
  @Roles(...READ_ROLES)
  @ApiOperation({
    summary:
      "Each question's latest version in the import columns (answer keys included: staff only)",
  })
  @ApiProduces(
    'text/csv',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  )
  @ApiOkResponse({ schema: { type: 'string', format: 'binary' } })
  async export(@Query() query: ExportQuery) {
    const f = await this.imports.exportFile(query);
    return new StreamableFile(f.body, {
      type: f.type,
      disposition: `attachment; filename="${f.fileName}"`,
    });
  }
}
