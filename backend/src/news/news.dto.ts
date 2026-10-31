import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
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
  NEWS_CATEGORIES,
  NEWS_STATUSES,
  type NewsCategory,
  type NewsStatus,
} from '../db/schema.js';
import { MAX_KEY_POINTS } from './workflow.js';

/** A draft may be incomplete; completeness is checked on submit and publish. */
export class CreateNewsDto {
  @ApiProperty({ enum: NEWS_CATEGORIES })
  @IsIn(NEWS_CATEGORIES)
  category: NewsCategory;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  title?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(1500)
  summary?: string;

  @ApiPropertyOptional({ type: [String], maxItems: MAX_KEY_POINTS })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(MAX_KEY_POINTS)
  @IsString({ each: true })
  @MaxLength(400, { each: true })
  key_points?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(800)
  why_it_matters?: string;

  @ApiPropertyOptional({ example: 'Supreme Court of India, 8 April 2025' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  source?: string;

  @ApiPropertyOptional({ type: String, nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  source_url?: string | null;

  @ApiPropertyOptional({ type: String, format: 'date', nullable: true })
  @IsOptional()
  @IsISO8601({ strict: true })
  event_date?: string | null;

  @ApiPropertyOptional({ minimum: 1, maximum: 30, default: 3 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(30)
  read_minutes?: number;
}

export class UpdateNewsDto extends PartialType(CreateNewsDto) {}

export class NewsReasonDto {
  @ApiProperty({ minLength: 3 })
  @IsString()
  @MinLength(3)
  @MaxLength(2000)
  reason: string;
}

export class ListNewsQuery {
  @ApiPropertyOptional({ enum: NEWS_STATUSES })
  @IsOptional()
  @IsIn(NEWS_STATUSES)
  status?: NewsStatus;

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

/** What the app shows: published articles only. */
export class PublicNewsDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ enum: NEWS_CATEGORIES }) category: NewsCategory;
  @ApiProperty() title: string;
  @ApiProperty() summary: string;
  @ApiProperty({ type: [String] }) key_points: string[];
  @ApiProperty() why_it_matters: string;
  @ApiProperty() source: string;
  @ApiProperty({ type: String, nullable: true }) source_url: string | null;
  @ApiProperty({ format: 'date' }) date: string;
  @ApiProperty() read_minutes: number;
}

export class PublicNewsListDto {
  @ApiProperty({ type: [PublicNewsDto] }) items: PublicNewsDto[];
}

export class NewsListItemDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ enum: NEWS_STATUSES }) status: NewsStatus;
  @ApiProperty({ enum: NEWS_CATEGORIES }) category: NewsCategory;
  @ApiProperty() title: string;
  @ApiProperty({ type: String, format: 'date', nullable: true })
  event_date: string | null;
  @ApiProperty({ format: 'date-time' }) updated_at: string;
}

export class NewsPageDto {
  @ApiProperty({ type: [NewsListItemDto] }) items: NewsListItemDto[];
  @ApiProperty({ type: String, nullable: true }) next_cursor: string | null;
}

export class NewsDetailDto extends NewsListItemDto {
  @ApiProperty({ type: String, nullable: true }) external_ref: string | null;
  @ApiProperty() summary: string;
  @ApiProperty({ type: [String] }) key_points: string[];
  @ApiProperty() why_it_matters: string;
  @ApiProperty() source: string;
  @ApiProperty({ type: String, nullable: true }) source_url: string | null;
  @ApiProperty() read_minutes: number;
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
