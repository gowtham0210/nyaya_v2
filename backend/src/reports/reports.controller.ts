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
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import type { AuthUser } from '../auth/auth-user.js';
import { CurrentActor, CurrentUser, Roles } from '../auth/decorators.js';
import type { Actor } from '../core/audit.service.js';
import {
  CreateReportDto,
  ListReportsQuery,
  ReportDto,
  ReportListDto,
  ReportReceiptDto,
  ResolveReportDto,
} from './reports.dto.js';
import { ReportsService } from './reports.service.js';

/** Staff who handle reports. */
const TRIAGE_ROLES = [
  'content_editor',
  'legal_reviewer',
  'publisher',
  'admin',
] as const;

@ApiTags('reports')
@ApiBearerAuth()
@Controller()
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  @Post('content-reports')
  @HttpCode(201)
  @ApiOperation({
    summary:
      'Report a problem with a question you were shown. Never changes the question; staff review it.',
  })
  @ApiOkResponse({ type: ReportReceiptDto })
  create(@CurrentUser() user: AuthUser, @Body() body: CreateReportDto) {
    return this.reports.create(user.id, body);
  }

  @Get('admin/content-reports')
  @Roles(...TRIAGE_ROLES)
  @ApiOperation({
    summary: 'Report queue: open (urgent first, then oldest) or closed',
  })
  @ApiOkResponse({ type: ReportListDto })
  list(@Query() query: ListReportsQuery) {
    return this.reports.list(query);
  }

  @Patch('admin/content-reports/:id')
  @Roles(...TRIAGE_ROLES)
  @ApiOperation({
    summary:
      'Close a report as fixed, retired or no change needed (revise or retire the question first)',
  })
  @ApiOkResponse({ type: ReportDto })
  resolve(
    @CurrentActor() actor: Actor,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() body: ResolveReportDto,
  ) {
    return this.reports.resolve(actor, id, body);
  }
}
