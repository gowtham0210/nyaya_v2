import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsBoolean, IsIn, IsOptional, IsUUID } from 'class-validator';
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
      'created: a new draft (or would be, in a test run); skipped: already in the bank; failed: has errors',
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
