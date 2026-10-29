import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import {
  REPORT_OUTCOMES,
  REPORT_REASONS,
  type ReportOutcome,
  type ReportReason,
} from '../db/schema.js';

const trimmed = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

export class CreateReportDto {
  @ApiProperty({
    format: 'uuid',
    description: 'The version you were shown',
  })
  @IsUUID()
  question_version_id: string;

  @ApiProperty({ enum: REPORT_REASONS })
  @IsIn(REPORT_REASONS)
  reason: ReportReason;

  @ApiPropertyOptional({ maxLength: 500 })
  @IsOptional()
  @Transform(trimmed)
  @IsString()
  @MaxLength(500)
  comment?: string;
}

export class ReportReceiptDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ format: 'date-time' }) created_at: string;
}

export class ListReportsQuery {
  @ApiPropertyOptional({ enum: ['open', 'closed'], default: 'open' })
  @IsOptional()
  @IsIn(['open', 'closed'])
  status?: 'open' | 'closed';

  @ApiPropertyOptional({ format: 'uuid', description: 'Only this question' })
  @IsOptional()
  @IsUUID()
  question_id?: string;

  @ApiPropertyOptional({ minimum: 1, maximum: 100, default: 50 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}

export class ReportDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ format: 'uuid' }) question_id: string;
  @ApiProperty({ format: 'uuid' }) question_version_id: string;
  @ApiProperty() version_no: number;
  @ApiProperty({ description: 'Question text of the reported version' })
  stem: string;
  @ApiProperty({ enum: REPORT_REASONS }) reason: ReportReason;
  @ApiProperty({
    description: 'Wrong answer and outdated law are legal errors: handle first',
  })
  urgent: boolean;
  @ApiProperty({ type: String, nullable: true }) comment: string | null;
  @ApiProperty({ format: 'date-time' }) created_at: string;
  @ApiProperty({ enum: REPORT_OUTCOMES, nullable: true })
  outcome: ReportOutcome | null;
  @ApiProperty({ type: String, nullable: true }) resolution_note: string | null;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  resolved_at: string | null;
  @ApiProperty({ type: String, nullable: true, description: 'Staff name' })
  resolved_by: string | null;
}

export class ReportListDto {
  @ApiProperty({ type: [ReportDto] }) items: ReportDto[];
}

export class ResolveReportDto {
  @ApiProperty({
    enum: REPORT_OUTCOMES,
    description:
      'fixed: the question was revised; retired: taken out; no_change: the question is right',
  })
  @IsIn(REPORT_OUTCOMES)
  outcome: ReportOutcome;

  @ApiProperty({ maxLength: 1000 })
  @Transform(trimmed)
  @IsString()
  @MinLength(1)
  @MaxLength(1000)
  note: string;
}
