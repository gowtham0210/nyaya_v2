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
  CreateImportDto,
  ExportQuery,
  ImportJobListDto,
  ImportReportDto,
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
