import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
} from 'class-validator';
import {
  IMPORT_FORMATS,
  IMPORT_OUTCOMES,
  PROBLEM_LEVELS,
  VERSION_STATUSES,
  type ImportOutcome,
  type ProblemLevel,
  type VersionStatus,
} from '../db/schema.js';

/** The text fields of the upload form; the file itself is the `file` part. */
export class CreateImportDto {
  @ApiPropertyOptional({
    type: Boolean,
    default: true,
    description:
      'Check the file and report what would happen, without saving anything',
  })
  @IsOptional()
  @Transform(({ value }) =>
    value === 'true' ? true : value === 'false' ? false : value,
  )
  @IsBoolean()
  dry_run?: boolean;
}

export class ImportProblemDto {
  @ApiProperty({ enum: PROBLEM_LEVELS }) level: ProblemLevel;
  @ApiProperty({ type: String, nullable: true, description: 'Column name' })
  field: string | null;
  @ApiProperty() reason: string;
}

export class ImportRowDto {
  @ApiProperty({ description: 'Row number in the file; the header is row 1' })
  row: number;
  @ApiProperty({ type: String, nullable: true }) external_ref: string | null;
  @ApiProperty({
    enum: IMPORT_OUTCOMES,
    description:
      'created: a new draft (or would be, in a test run); skipped: already in the bank; failed: has errors; withdrawn: key says WITHDRAWN, so no question is made (exam import)',
  })
  outcome: ImportOutcome;
  @ApiProperty({
    type: String,
    format: 'uuid',
    nullable: true,
    description: 'The new draft, or the existing question it duplicates',
  })
  question_id: string | null;
  @ApiProperty({ type: [ImportProblemDto] }) problems: ImportProblemDto[];
}

export class ImportTotalsDto {
  @ApiProperty() created: number;
  @ApiProperty() skipped: number;
  @ApiProperty() failed: number;
  @ApiProperty({
    description:
      'Exam import only: rows the exam body withdrew. No question is made; each becomes a withdrawn paper position',
  })
  withdrawn: number;
  @ApiProperty({
    description: 'Created rows that still need something before review',
  })
  with_warnings: number;
}

export class ImportJobSummaryDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() file_name: string;
  @ApiProperty({ enum: IMPORT_FORMATS }) format: string;
  @ApiProperty({ format: 'date-time' }) created_at: string;
  @ApiProperty() created_by_name: string;
  @ApiProperty({ type: ImportTotalsDto }) totals: ImportTotalsDto;
}

export class ImportJobListDto {
  @ApiProperty({
    type: [ImportJobSummaryDto],
    description: 'Newest first, at most 50',
  })
  items: ImportJobSummaryDto[];
}

export class ImportReportDto {
  @ApiProperty({
    type: String,
    format: 'uuid',
    nullable: true,
    description: 'Null for a test run, which is not saved',
  })
  id: string | null;
  @ApiProperty() dry_run: boolean;
  @ApiProperty() file_name: string;
  @ApiProperty({ enum: IMPORT_FORMATS }) format: string;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  created_at: string | null;
  @ApiProperty({ type: ImportTotalsDto }) totals: ImportTotalsDto;
  @ApiProperty({ type: [ImportRowDto] }) rows: ImportRowDto[];
}

/** The text fields of the exam-import form; the file itself is the `file` part. */
export class CreateExamImportDto extends CreateImportDto {
  @ApiPropertyOptional({
    format: 'uuid',
    description:
      'Optional. The content source the questions come from, kept for attribution.',
  })
  @IsOptional()
  @IsUUID()
  content_source_id?: string;

  @ApiPropertyOptional({
    example: 'aibe',
    description:
      'The exam the whole file is for (its slug). It fills a blank exam cell, so the file needs no exam column; a row that names a different exam is rejected.',
  })
  @IsOptional()
  @IsString()
  @Matches(/^[a-z0-9][a-z0-9-]{0,40}$/, {
    message: 'Use the exam slug, e.g. aibe',
  })
  exam?: string;
}

export class ExamImportSourceDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() title: string;
}

export class ExamImportReportDto extends ImportReportDto {
  @ApiProperty({ type: ExamImportSourceDto, nullable: true })
  content_source: ExamImportSourceDto | null;
}

export class ExportQuery {
  @ApiPropertyOptional({ enum: ['csv', 'xlsx'], default: 'csv' })
  @IsOptional()
  @IsIn(['csv', 'xlsx'])
  format?: 'csv' | 'xlsx';

  @ApiPropertyOptional({
    enum: VERSION_STATUSES,
    description: "Status of each question's latest version",
  })
  @IsOptional()
  @IsIn(VERSION_STATUSES)
  status?: VersionStatus;

  @ApiPropertyOptional({ format: 'uuid' })
  @IsOptional()
  @IsUUID()
  topic_id?: string;
}

export const TEMPLATE_KINDS = ['general', 'exam'] as const;

export class TemplateQuery {
  @ApiProperty({
    enum: TEMPLATE_KINDS,
    description: 'general: the ordinary import; exam: adds the exam columns',
  })
  @IsIn(TEMPLATE_KINDS)
  kind: (typeof TEMPLATE_KINDS)[number];

  @ApiPropertyOptional({ enum: ['xlsx', 'csv'], default: 'xlsx' })
  @IsOptional()
  @IsIn(['xlsx', 'csv'])
  format?: 'xlsx' | 'csv';

  @ApiPropertyOptional({
    example: 'aibe',
    description: 'Exam template only: fills the exam column of the sample row',
  })
  @IsOptional()
  @IsString()
  @Matches(/^[a-z0-9][a-z0-9-]{0,40}$/)
  exam?: string;
}

export class PaperPositionDraftDto {
  @ApiProperty({ minimum: 1 }) position: number;
  @ApiProperty({
    type: String,
    format: 'uuid',
    nullable: true,
    description: 'Null for a withdrawn position, which pins no question',
  })
  question_version_id: string | null;
  @ApiPropertyOptional({ description: "The row's external_ref, if it had one" })
  original_ref?: string;
  @ApiPropertyOptional({ description: 'Set for a withdrawn position' })
  withdrawn_note?: string;
}

export class PaperCandidateDto {
  @ApiProperty({ description: 'Row number in the imported file' }) row: number;
  @ApiProperty({ description: 'The position this row would take (file order)' })
  position: number;
  @ApiProperty({ type: String, nullable: true }) external_ref: string | null;
  @ApiProperty({ enum: IMPORT_OUTCOMES }) outcome: ImportOutcome;
  @ApiProperty({ type: String, format: 'uuid', nullable: true })
  question_id: string | null;
  @ApiProperty({
    type: String,
    nullable: true,
    description: "The question's latest version status",
  })
  status: string | null;
  @ApiProperty({
    description: 'True when the question has a published version to pin',
  })
  ready: boolean;
  @ApiProperty({ type: String, nullable: true }) reason: string | null;
}

export class PaperPositionsDto {
  @ApiProperty({ format: 'uuid' }) job_id: string;
  @ApiProperty({ type: [PaperCandidateDto] }) rows: PaperCandidateDto[];
  @ApiProperty({ description: 'Rows with a published version to pin' })
  ready: number;
  @ApiProperty({ description: 'Rows kept as withdrawn positions' })
  withdrawn: number;
  @ApiProperty({ description: 'Rows still waiting on review or publishing' })
  not_ready: number;
  @ApiProperty({
    type: [PaperPositionDraftDto],
    description:
      'Positions for the rows that are ready, in the format of PUT /admin/exam-papers/{id}/positions. Read-only: nothing is saved.',
  })
  positions: PaperPositionDraftDto[];
}
