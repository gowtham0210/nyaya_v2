import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import {
  LAW_REGIMES,
  QUESTION_TYPES,
  VERSION_STATUSES,
  type LawRegime,
  type QuestionType,
  type VersionStatus,
} from '../db/schema.js';

export class OptionDto {
  @ApiProperty({ example: 'a', description: 'Stable within the question' })
  @Matches(/^[a-z0-9]{1,8}$/)
  id: string;

  @ApiProperty({ example: '26 January 1950' })
  @IsString()
  @MaxLength(500)
  text: string;
}

/** A draft may be incomplete; completeness is checked on submit and publish. */
export class CreateQuestionDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  topic_id: string;

  @ApiPropertyOptional({ enum: QUESTION_TYPES, default: 'single_select' })
  @IsOptional()
  @IsIn(QUESTION_TYPES)
  question_type?: QuestionType;

  @ApiPropertyOptional({ minimum: 1, maximum: 3, default: 1 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(3)
  difficulty?: number;

  @ApiPropertyOptional({ default: 'IN' })
  @IsOptional()
  @IsString()
  @MaxLength(8)
  jurisdiction?: string;

  @ApiPropertyOptional({ default: 'en' })
  @IsOptional()
  @IsString()
  @MaxLength(8)
  language?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(7000)
  stem?: string;

  @ApiPropertyOptional({ type: [OptionDto] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(6)
  @ValidateNested({ each: true })
  @Type(() => OptionDto)
  options?: OptionDto[];

  @ApiPropertyOptional({
    type: [String],
    description: 'Never sent to learners before they answer',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(6)
  @IsString({ each: true })
  correct_option_ids?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(5000)
  explanation?: string;

  @ApiPropertyOptional({ type: String, nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  source_title?: string | null;

  @ApiPropertyOptional({
    type: String,
    nullable: true,
    example: 'https://www.indiacode.nic.in/',
  })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  source_url?: string | null;

  @ApiPropertyOptional({ type: String, nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  citation?: string | null;

  @ApiPropertyOptional({
    type: String,
    nullable: true,
    example: 'Article 394, Constitution of India',
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  provision_reference?: string | null;

  @ApiPropertyOptional({ type: String, format: 'date', nullable: true })
  @IsOptional()
  @IsISO8601({ strict: true })
  valid_from?: string | null;

  @ApiPropertyOptional({ type: String, format: 'date', nullable: true })
  @IsOptional()
  @IsISO8601({ strict: true })
  valid_to?: string | null;

  @ApiPropertyOptional({
    type: String,
    format: 'uuid',
    nullable: true,
    description:
      'Where the content comes from (attribution only; it never blocks publishing).',
  })
  @IsOptional()
  @IsUUID()
  content_source_id?: string | null;

  @ApiPropertyOptional({ enum: LAW_REGIMES, default: 'neutral' })
  @IsOptional()
  @IsIn(LAW_REGIMES)
  law_regime?: LawRegime;

  @ApiPropertyOptional({
    type: String,
    nullable: true,
    description:
      'Questions testing the same concept share a key; a mock uses at most one of them',
  })
  @IsOptional()
  @IsString()
  @Matches(/^[a-z0-9][a-z0-9._-]{0,118}[a-z0-9]$/)
  concept_key?: string | null;

  @ApiPropertyOptional({
    type: [String],
    description:
      'Further options an official key also accepts; never one of correct_option_ids',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5)
  @IsString({ each: true })
  alternate_correct_option_ids?: string[];

  @ApiPropertyOptional({
    description: 'Show the options in the stored order, never shuffled',
  })
  @IsOptional()
  @IsBoolean()
  lock_option_order?: boolean;

  @ApiPropertyOptional({
    default: false,
    description:
      'Exam-only questions are never used by the learning games. Can only be changed before the first publish.',
  })
  @IsOptional()
  @IsBoolean()
  exam_only?: boolean;

  @ApiPropertyOptional({
    type: [String],
    description:
      'The exams this question may be used in. An exam-only question needs at least one to be published.',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @ArrayUnique()
  @IsUUID('all', { each: true })
  exam_ids?: string[];
}

export class UpdateQuestionDto extends PartialType(CreateQuestionDto) {}

/** Exam tags are not part of a version, so they can change at any stage. */
export class SetExamTagsDto {
  @ApiProperty({ type: [String], description: 'The full set of exams' })
  @IsArray()
  @ArrayMaxSize(10)
  @ArrayUnique()
  @IsUUID('all', { each: true })
  exam_ids: string[];
}

export class ReasonDto {
  @ApiProperty({ minLength: 3 })
  @IsString()
  @MinLength(3)
  @MaxLength(2000)
  reason: string;
}

export class ApproveDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  note?: string;
}

export class ReviseDto {
  @ApiProperty({
    description: 'Why the published question is changing',
    minLength: 3,
  })
  @IsString()
  @MinLength(3)
  @MaxLength(2000)
  change_note: string;
}

/** Lifecycle steps that can run on many questions at once (no per-question reason). */
export const BULK_ACTIONS = ['submit', 'approve', 'publish'] as const;
export type BulkAction = (typeof BULK_ACTIONS)[number];

export class BulkActionDto {
  @ApiProperty({ enum: BULK_ACTIONS })
  @IsIn(BULK_ACTIONS)
  action: BulkAction;

  @ApiProperty({
    type: [String],
    format: 'uuid',
    minItems: 1,
    maxItems: 100,
    description: 'Questions to act on; each is checked and run on its own',
  })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(100)
  @ArrayUnique()
  @IsUUID('all', { each: true })
  question_ids: string[];

  @ApiPropertyOptional({ description: 'Approval note, for approve only' })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  note?: string;
}

export class ListQuestionsQuery {
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

  @ApiPropertyOptional({ description: 'Searches question text' })
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

// ------------------------------------------------------------ responses

export class VersionDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() version_no: number;
  @ApiProperty({ enum: VERSION_STATUSES }) status: VersionStatus;
  @ApiProperty({ format: 'uuid' }) topic_id: string;
  @ApiProperty() jurisdiction: string;
  @ApiProperty() language: string;
  @ApiProperty({ enum: QUESTION_TYPES }) question_type: QuestionType;
  @ApiProperty() difficulty: number;
  @ApiProperty() stem: string;
  @ApiProperty({ type: [OptionDto] }) options: OptionDto[];
  @ApiProperty({ type: [String] }) correct_option_ids: string[];
  @ApiProperty() explanation: string;
  @ApiProperty({ type: String, nullable: true }) source_title: string | null;
  @ApiProperty({ type: String, nullable: true }) source_url: string | null;
  @ApiProperty({ type: String, nullable: true }) citation: string | null;
  @ApiProperty({ type: String, nullable: true }) provision_reference:
    string | null;
  @ApiProperty({ type: String, format: 'date', nullable: true }) valid_from:
    string | null;
  @ApiProperty({ type: String, format: 'date', nullable: true }) valid_to:
    string | null;
  @ApiProperty({ type: String, format: 'uuid', nullable: true })
  content_source_id: string | null;
  @ApiProperty({ enum: LAW_REGIMES }) law_regime: LawRegime;
  @ApiProperty({ type: String, nullable: true }) concept_key: string | null;
  @ApiProperty({ type: [String] }) alternate_correct_option_ids: string[];
  @ApiProperty() lock_option_order: boolean;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  verified_at: string | null;
  @ApiProperty({ type: String, format: 'uuid', nullable: true }) reviewer_id:
    string | null;
  @ApiProperty({ type: String, nullable: true }) change_note: string | null;
  @ApiProperty({ type: String, format: 'uuid', nullable: true }) created_by:
    string | null;
  @ApiProperty({ type: String, format: 'uuid', nullable: true }) updated_by:
    string | null;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  submitted_at: string | null;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  approved_at: string | null;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  published_at: string | null;
  @ApiProperty({ type: String, format: 'uuid', nullable: true }) published_by:
    string | null;
  @ApiProperty({ type: String, format: 'date-time', nullable: true }) ended_at:
    string | null;
  @ApiProperty({ format: 'date-time' }) created_at: string;
  @ApiProperty({ format: 'date-time' }) updated_at: string;
}

export class VersionSummaryDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() version_no: number;
  @ApiProperty({ enum: VERSION_STATUSES }) status: VersionStatus;
  @ApiProperty({ type: String, nullable: true }) change_note: string | null;
  @ApiProperty({ format: 'date-time' }) created_at: string;
}

export class ReviewDecisionDto {
  @ApiProperty({ format: 'uuid' }) version_id: string;
  @ApiProperty({ format: 'uuid' }) reviewer_id: string;
  @ApiProperty({ enum: ['approved', 'changes_requested'] }) decision: string;
  @ApiProperty({ type: String, nullable: true }) reason: string | null;
  @ApiProperty({ format: 'date-time' }) created_at: string;
}

export class ListLatestDto extends VersionSummaryDto {
  @ApiProperty() stem: string;
  @ApiProperty({ format: 'uuid' }) topic_id: string;
}

export class QuestionListItemDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ type: String, nullable: true }) external_ref: string | null;
  @ApiProperty({ type: String, format: 'uuid', nullable: true })
  live_version_id: string | null;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  retired_at: string | null;
  @ApiProperty({ type: () => ListLatestDto }) latest: ListLatestDto;
}

export class QuestionPageDto {
  @ApiProperty({ type: [QuestionListItemDto] }) items: QuestionListItemDto[];
  @ApiProperty({ type: String, nullable: true }) next_cursor: string | null;
}

export class QuestionDetailDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ type: String, nullable: true }) external_ref: string | null;
  @ApiProperty({ type: String, format: 'uuid', nullable: true })
  live_version_id: string | null;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  retired_at: string | null;
  @ApiProperty({ format: 'date-time' }) created_at: string;
  @ApiProperty() exam_only: boolean;
  @ApiProperty({ type: [String] }) exam_ids: string[];
  @ApiProperty({
    type: VersionDto,
    description: 'The newest version, which is the one actions apply to',
  })
  latest: VersionDto;
  @ApiProperty({ type: [VersionSummaryDto] }) versions: VersionSummaryDto[];
  @ApiProperty({ type: [ReviewDecisionDto] }) reviews: ReviewDecisionDto[];
}

export class BulkErrorDetailDto {
  @ApiPropertyOptional() field?: string;
  @ApiProperty() reason: string;
}

export class BulkErrorDto {
  @ApiProperty() code: string;
  @ApiProperty() message: string;
  @ApiPropertyOptional({ type: [BulkErrorDetailDto] })
  details?: BulkErrorDetailDto[];
}

export class BulkItemResultDto {
  @ApiProperty({ format: 'uuid' }) question_id: string;
  @ApiProperty() ok: boolean;
  @ApiPropertyOptional({
    enum: VERSION_STATUSES,
    description: 'Status of the latest version after the step, when ok',
  })
  status?: VersionStatus;
  @ApiPropertyOptional({ type: BulkErrorDto }) error?: BulkErrorDto;
}

export class BulkResultDto {
  @ApiProperty({ type: [BulkItemResultDto], description: 'In request order' })
  results: BulkItemResultDto[];
  @ApiProperty() succeeded: number;
  @ApiProperty() failed: number;
}
