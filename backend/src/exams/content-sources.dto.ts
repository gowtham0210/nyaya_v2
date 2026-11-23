import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { CONTENT_SOURCE_KINDS, type ContentSourceKind } from '../db/schema.js';

const HTTPS = /^https:\/\/\S+$/;
const DAY = /^\d{4}-\d{2}-\d{2}$/;
const SHA256 = /^[0-9a-f]{64}$/;

export class CreateContentSourceDto {
  @ApiProperty({ enum: CONTENT_SOURCE_KINDS })
  @IsIn(CONTENT_SOURCE_KINDS)
  kind: ContentSourceKind;

  @ApiProperty({ maxLength: 300 })
  @IsString()
  @MinLength(1)
  @MaxLength(300)
  title: string;

  @ApiPropertyOptional({ nullable: true, maxLength: 300 })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  publisher?: string | null;

  @ApiPropertyOptional({ nullable: true, description: 'An https address' })
  @IsOptional()
  @Matches(HTTPS, { message: 'url must be an https address' })
  @MaxLength(2000)
  url?: string | null;

  @ApiPropertyOptional({ nullable: true, example: '2026-11-18' })
  @IsOptional()
  @Matches(DAY, { message: 'retrieved_on must be YYYY-MM-DD' })
  retrieved_on?: string | null;

  @ApiPropertyOptional({
    nullable: true,
    description: 'SHA-256 of the source document, lower-case hex',
  })
  @IsOptional()
  @Matches(SHA256, { message: 'sha256 must be 64 lower-case hex characters' })
  sha256?: string | null;

  @ApiPropertyOptional({
    type: [String],
    description: 'What the source may be used for, e.g. "practice questions"',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @MaxLength(200, { each: true })
  allowed_uses?: string[];
}

/** Details of a source: attribution and provenance. */
export class UpdateContentSourceDto {
  @ApiPropertyOptional({ maxLength: 300 })
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(300)
  title?: string;

  @ApiPropertyOptional({ nullable: true, maxLength: 300 })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  publisher?: string | null;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @Matches(HTTPS, { message: 'url must be an https address' })
  @MaxLength(2000)
  url?: string | null;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @Matches(DAY, { message: 'retrieved_on must be YYYY-MM-DD' })
  retrieved_on?: string | null;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @Matches(SHA256, { message: 'sha256 must be 64 lower-case hex characters' })
  sha256?: string | null;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @MaxLength(200, { each: true })
  allowed_uses?: string[];
}

export class ListContentSourcesQuery {
  @ApiPropertyOptional({ enum: CONTENT_SOURCE_KINDS })
  @IsOptional()
  @IsIn(CONTENT_SOURCE_KINDS)
  kind?: ContentSourceKind;

  @ApiPropertyOptional({ minimum: 1, maximum: 100, default: 50 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  cursor?: string;
}

export class ContentSourceDto {
  @ApiProperty() id: string;
  @ApiProperty({ enum: CONTENT_SOURCE_KINDS }) kind: ContentSourceKind;
  @ApiProperty() title: string;
  @ApiProperty({ type: String, nullable: true }) publisher: string | null;
  @ApiProperty({ type: String, nullable: true }) url: string | null;
  @ApiProperty({ type: String, format: 'date', nullable: true })
  retrieved_on: string | null;
  @ApiProperty({ type: String, nullable: true }) sha256: string | null;
  @ApiProperty({ type: [String] }) allowed_uses: string[];
  @ApiProperty({ type: String, nullable: true }) created_by: string | null;
  @ApiProperty() created_at: string;
  @ApiProperty() updated_at: string;
}

export class ContentSourcePageDto {
  @ApiProperty({ type: [ContentSourceDto] }) items: ContentSourceDto[];
  @ApiProperty({ type: String, nullable: true }) next_cursor: string | null;
}
