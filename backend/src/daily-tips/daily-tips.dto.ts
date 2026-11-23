import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import {
  DAILY_TIP_CATEGORIES,
  DAILY_TIP_LANGUAGES,
  DAILY_TIP_STATUSES,
  type DailyTipCategory,
  type DailyTipStatus,
} from '../db/schema.js';

/** A draft may be incomplete; completeness is checked on submit and publish. */
export class CreateDailyTipDto {
  @ApiProperty({ enum: DAILY_TIP_CATEGORIES })
  @IsIn(DAILY_TIP_CATEGORIES)
  category: DailyTipCategory;

  @ApiPropertyOptional({ enum: DAILY_TIP_LANGUAGES, default: 'en' })
  @IsOptional()
  @IsIn(DAILY_TIP_LANGUAGES)
  language?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(150)
  title?: string;

  @ApiPropertyOptional({ description: 'Shown on the Home card' })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  summary?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  explanation?: string;

  @ApiPropertyOptional({
    example: 'Consumer Protection Act, 2019, Section 35',
  })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  legal_reference?: string;

  @ApiPropertyOptional({ type: String, nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  source_url?: string | null;

  @ApiPropertyOptional({
    type: String,
    format: 'date',
    nullable: true,
    description: 'The India day the tip is shown on Home',
  })
  @IsOptional()
  @IsISO8601({ strict: true })
  publish_date?: string | null;

  @ApiPropertyOptional({ type: String, format: 'date', nullable: true })
  @IsOptional()
  @IsISO8601({ strict: true })
  last_verified_on?: string | null;
}

export class UpdateDailyTipDto extends PartialType(CreateDailyTipDto) {}

export class TipReasonDto {
  @ApiProperty({ minLength: 3 })
  @IsString()
  @MinLength(3)
  @MaxLength(2000)
  reason: string;
}

export class TodayTipQuery {
  @ApiPropertyOptional({ enum: DAILY_TIP_LANGUAGES, default: 'en' })
  @IsOptional()
  @IsIn(DAILY_TIP_LANGUAGES)
  language?: string;
}

export class ListTipsQuery {
  @ApiPropertyOptional({ enum: DAILY_TIP_STATUSES })
  @IsOptional()
  @IsIn(DAILY_TIP_STATUSES)
  status?: DailyTipStatus;

  @ApiPropertyOptional({ enum: DAILY_TIP_CATEGORIES })
  @IsOptional()
  @IsIn(DAILY_TIP_CATEGORIES)
  category?: DailyTipCategory;

  @ApiPropertyOptional({ description: 'Searches titles' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  q?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(100)
  cursor?: string;

  @ApiPropertyOptional({ minimum: 1, maximum: 100, default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}

/** The editor's attestation that the tip was checked against its source. */
export class VerifyTipDto {
  @ApiProperty({
    enum: [true],
    description:
      'Must be true: the editor opened the exact official source link and confirmed the tip matches it',
  })
  @IsIn([true])
  confirmed_against_source: true;
}

/** What the app shows: published tips only. */
export class PublicDailyTipDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ enum: DAILY_TIP_CATEGORIES }) category: DailyTipCategory;
  @ApiProperty() language: string;
  @ApiProperty() title: string;
  @ApiProperty() summary: string;
  @ApiProperty() explanation: string;
  @ApiProperty() legal_reference: string;
  @ApiProperty() source_url: string;
  @ApiProperty({ format: 'date' }) publish_date: string;
  @ApiProperty({ format: 'date' }) last_verified_on: string;
}

/** `tip` is null when nothing is published for today. */
export class TodayTipDto {
  @ApiProperty({ type: PublicDailyTipDto, nullable: true })
  tip: PublicDailyTipDto | null;
}

export class DailyTipListItemDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ enum: DAILY_TIP_STATUSES }) status: DailyTipStatus;
  @ApiProperty({ enum: DAILY_TIP_CATEGORIES }) category: DailyTipCategory;
  @ApiProperty() language: string;
  @ApiProperty() title: string;
  @ApiProperty({ type: String, format: 'date', nullable: true })
  publish_date: string | null;
  @ApiProperty({ format: 'date-time' }) updated_at: string;
  @ApiProperty() legal_reference: string;
  @ApiProperty({ type: String, nullable: true }) source_url: string | null;
  @ApiProperty({ type: String, format: 'date', nullable: true })
  last_verified_on: string | null;
}

export class DailyTipPageDto {
  @ApiProperty({ type: [DailyTipListItemDto] }) items: DailyTipListItemDto[];
  @ApiProperty({ type: String, nullable: true }) next_cursor: string | null;
}

export class DailyTipDetailDto extends DailyTipListItemDto {
  @ApiProperty() summary: string;
  @ApiProperty() explanation: string;
  @ApiProperty({ type: String, format: 'uuid', nullable: true })
  created_by: string | null;
  @ApiProperty({ type: String, format: 'uuid', nullable: true })
  updated_by: string | null;
  @ApiProperty({ type: String, format: 'uuid', nullable: true })
  reviewer_id: string | null;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  approved_at: string | null;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  published_at: string | null;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  retired_at: string | null;
  @ApiProperty({ format: 'date-time' }) created_at: string;
  @ApiProperty({
    type: String,
    nullable: true,
    description: 'Why changes were last requested, while they still are',
  })
  changes_reason: string | null;
}
