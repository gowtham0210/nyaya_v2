import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
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
  ValidateIf,
} from 'class-validator';
import {
  CONFIG_STATUSES,
  KEY_HISTORY_KINDS,
  PAPER_ANSWER_STATUSES,
  PAPER_STATUSES,
  WITHDRAWN_POLICIES,
  type ConfigStatus,
  type KeyHistoryKind,
  type PaperAnswerStatus,
  type PaperStatus,
  type WithdrawnPolicy,
} from '../db/schema.js';

const MARKS = { minimum: 0, maximum: 999 };

export class CreatePaperDto {
  @ApiProperty({ format: 'uuid' }) @IsUUID() exam_id: string;

  @ApiProperty({ example: 'aibe-xviii-set-a' })
  @IsString()
  @Matches(/^[a-z0-9][a-z0-9-]{1,78}[a-z0-9]$/, {
    message: 'Use lowercase letters, digits and hyphens',
  })
  code: string;

  @ApiProperty() @IsString() @MinLength(3) @MaxLength(200) title: string;

  @ApiPropertyOptional({ example: 'XVIII' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  edition?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(1990)
  @Max(2100)
  year?: number;

  @ApiPropertyOptional({ example: 'A' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  set_label?: string;

  @ApiPropertyOptional({ format: 'uuid' })
  @IsOptional()
  @IsUUID()
  blueprint_id?: string;

  @ApiProperty({ minimum: 1, maximum: 500 })
  @IsInt()
  @Min(1)
  @Max(500)
  total_questions: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(60)
  @Max(86_400)
  duration_seconds?: number;

  @ApiPropertyOptional({
    nullable: true,
    description:
      'Optional practice clock in seconds (60 to 86400), shown to learners as practice timing that BCI has not confirmed. It does not enable the official timed mode. Null removes it.',
  })
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsInt()
  @Min(60)
  @Max(86_400)
  practice_timer_seconds?: number | null;

  @ApiPropertyOptional(MARKS)
  @IsOptional()
  @Type(() => Number)
  @Min(0)
  @Max(999)
  marks_correct?: number;

  @ApiPropertyOptional(MARKS)
  @IsOptional()
  @Type(() => Number)
  @Min(0)
  @Max(999)
  negative_marks?: number;

  @ApiPropertyOptional(MARKS)
  @IsOptional()
  @Type(() => Number)
  @Min(0)
  @Max(999)
  marks_unanswered?: number;

  @ApiPropertyOptional({
    enum: WITHDRAWN_POLICIES,
    default: 'unscored',
    description:
      'Interim rule for withdrawn questions: unscored leaves them out of the marks',
  })
  @IsOptional()
  @IsIn(WITHDRAWN_POLICIES)
  withdrawn_policy?: WithdrawnPolicy;

  @ApiPropertyOptional({
    description:
      'True only when the rule has been confirmed from the exam body. award_all needs it.',
  })
  @IsOptional()
  @IsBoolean()
  withdrawn_policy_confirmed?: boolean;

  @ApiPropertyOptional({ enum: CONFIG_STATUSES, default: 'unverified' })
  @IsOptional()
  @IsIn(CONFIG_STATUSES)
  config_status?: ConfigStatus;

  @ApiPropertyOptional({ type: String, nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  source_note?: string | null;
}

export class UpdatePaperDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  title?: string;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(20)
  edition?: string;
  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(1990)
  @Max(2100)
  year?: number;
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(20)
  set_label?: string;
  @ApiPropertyOptional({ format: 'uuid' })
  @IsOptional()
  @IsUUID()
  blueprint_id?: string;
  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(500)
  total_questions?: number;
  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(60)
  @Max(86_400)
  duration_seconds?: number;
  @ApiPropertyOptional({
    nullable: true,
    description:
      'Optional practice clock in seconds (60 to 86400), shown to learners as practice timing that BCI has not confirmed. It does not enable the official timed mode. Null removes it.',
  })
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsInt()
  @Min(60)
  @Max(86_400)
  practice_timer_seconds?: number | null;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @Min(0)
  @Max(999)
  marks_correct?: number;
  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @Min(0)
  @Max(999)
  negative_marks?: number;
  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @Min(0)
  @Max(999)
  marks_unanswered?: number;
  @ApiPropertyOptional({ enum: WITHDRAWN_POLICIES })
  @IsOptional()
  @IsIn(WITHDRAWN_POLICIES)
  withdrawn_policy?: WithdrawnPolicy;
  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  withdrawn_policy_confirmed?: boolean;
  @ApiPropertyOptional({ enum: CONFIG_STATUSES })
  @IsOptional()
  @IsIn(CONFIG_STATUSES)
  config_status?: ConfigStatus;
  @ApiPropertyOptional({ type: String, nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  source_note?: string | null;
}

export class PositionInputDto {
  @ApiProperty({ minimum: 1 }) @IsInt() @Min(1) @Max(500) position: number;

  @ApiPropertyOptional({
    type: String,
    format: 'uuid',
    nullable: true,
    description:
      'The exact question version to pin. Omit (or null) for a withdrawn question, which is kept as a placeholder.',
  })
  @IsOptional()
  @IsUUID()
  question_version_id?: string | null;

  @ApiPropertyOptional({ description: 'The number in the original paper' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  original_ref?: string;

  @ApiPropertyOptional({
    type: [String],
    description:
      "Option ids in the order shown; leave out to use the version's own order",
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(6)
  @IsString({ each: true })
  option_order?: string[];

  @ApiPropertyOptional({ example: 'A-D' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  original_label_scheme?: string;

  @ApiPropertyOptional({ description: 'The key as the exam body printed it' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  official_key_text?: string;

  @ApiPropertyOptional({ description: 'Where this position came from' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  source_ref?: string;

  @ApiPropertyOptional({
    description: 'Why a withdrawn question was withdrawn',
  })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  withdrawn_note?: string;
}

export class ReplacePositionsDto {
  @ApiProperty({ type: [PositionInputDto] })
  @IsArray()
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => PositionInputDto)
  positions: PositionInputDto[];
}

export class AddKeyHistoryDto {
  @ApiProperty({ enum: KEY_HISTORY_KINDS })
  @IsIn(KEY_HISTORY_KINDS)
  kind: KeyHistoryKind;

  @ApiProperty({
    type: [String],
    description:
      'Every option the body accepted; empty for a withdrawn question',
  })
  @IsArray()
  @ArrayMaxSize(6)
  @IsString({ each: true })
  accepted_option_ids: string[];

  @ApiPropertyOptional({ format: 'uuid' })
  @IsOptional()
  @IsUUID()
  content_source_id?: string;

  @ApiPropertyOptional({ description: 'Document title, notice number, page' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  source_document_ref?: string;

  @ApiPropertyOptional({ type: String, format: 'date' })
  @IsOptional()
  @IsISO8601({ strict: true })
  retrieved_on?: string;

  @ApiPropertyOptional({
    description: 'SHA-256 of the document, lowercase hex',
  })
  @IsOptional()
  @Matches(/^[0-9a-f]{64}$/)
  source_sha256?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;
}

export class ListPapersQuery {
  @ApiPropertyOptional({ enum: PAPER_STATUSES })
  @IsOptional()
  @IsIn(PAPER_STATUSES)
  status?: PaperStatus;

  @ApiPropertyOptional({ format: 'uuid' })
  @IsOptional()
  @IsUUID()
  exam_id?: string;

  @ApiPropertyOptional({ minimum: 1, maximum: 100, default: 50 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;

  @ApiPropertyOptional() @IsOptional() @IsString() cursor?: string;
}

export class LearnerListPapersQuery {
  @ApiPropertyOptional({ minimum: 1, maximum: 100, default: 50 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;

  @ApiPropertyOptional() @IsOptional() @IsString() cursor?: string;
}

export class PaperDto {
  @ApiProperty() id: string;
  @ApiProperty() exam_id: string;
  @ApiProperty() code: string;
  @ApiProperty() revision: number;
  @ApiProperty({ type: String, nullable: true }) supersedes_id: string | null;
  @ApiProperty() title: string;
  @ApiProperty({ type: String, nullable: true }) edition: string | null;
  @ApiProperty({ type: Number, nullable: true }) year: number | null;
  @ApiProperty({ type: String, nullable: true }) set_label: string | null;
  @ApiProperty({ enum: PAPER_STATUSES }) status: PaperStatus;
  @ApiProperty({ type: String, nullable: true }) frozen_at: string | null;
  @ApiProperty({ type: String, nullable: true }) blueprint_id: string | null;
  @ApiProperty() total_questions: number;
  @ApiProperty({ type: Number, nullable: true }) duration_seconds:
    number | null;
  @ApiProperty({ type: Number, nullable: true }) practice_timer_seconds:
    number | null;
  @ApiProperty({ type: Number, nullable: true }) marks_correct: number | null;
  @ApiProperty({ type: Number, nullable: true }) negative_marks: number | null;
  @ApiProperty({ type: Number, nullable: true }) marks_unanswered:
    number | null;
  @ApiProperty({ enum: WITHDRAWN_POLICIES }) withdrawn_policy: WithdrawnPolicy;
  @ApiProperty() withdrawn_policy_confirmed: boolean;
  @ApiProperty({ enum: CONFIG_STATUSES }) config_status: ConfigStatus;
  @ApiProperty({ type: String, nullable: true }) source_note: string | null;
  @ApiProperty() created_at: string;
  @ApiProperty() updated_at: string;
}

export class PaperPageDto {
  @ApiProperty({ type: [PaperDto] }) items: PaperDto[];
  @ApiProperty({ type: String, nullable: true }) next_cursor: string | null;
}

export class KeyHistoryEntryDto {
  @ApiProperty() id: string;
  @ApiProperty({ enum: KEY_HISTORY_KINDS }) kind: KeyHistoryKind;
  @ApiProperty({ type: [String] }) accepted_option_ids: string[];
  @ApiProperty({ type: String, nullable: true }) content_source_id:
    string | null;
  @ApiProperty({ type: String, nullable: true }) source_document_ref:
    string | null;
  @ApiProperty({ type: String, nullable: true }) retrieved_on: string | null;
  @ApiProperty({ type: String, nullable: true }) source_sha256: string | null;
  @ApiProperty({ type: String, nullable: true }) note: string | null;
  @ApiProperty({ type: String, nullable: true }) recorded_by: string | null;
  @ApiProperty() created_at: string;
}

export class StaffPositionDto {
  @ApiProperty() id: string;
  @ApiProperty() position: number;
  @ApiProperty({ enum: PAPER_ANSWER_STATUSES })
  answer_status: PaperAnswerStatus;
  @ApiProperty({ type: String, nullable: true }) question_id: string | null;
  @ApiProperty({ type: String, nullable: true }) question_version_id:
    string | null;
  @ApiProperty({ type: String, nullable: true }) original_ref: string | null;
  @ApiProperty({ type: [String], nullable: true }) option_order:
    string[] | null;
  @ApiProperty({ type: String, nullable: true }) original_label_scheme:
    string | null;
  @ApiProperty({ type: String, nullable: true }) official_key_text:
    string | null;
  @ApiProperty({ type: String, nullable: true }) source_ref: string | null;
  @ApiProperty({ type: String, nullable: true }) withdrawn_note: string | null;
  @ApiProperty({
    type: [String],
    description: 'The effective key (staff only)',
  })
  accepted_option_ids: string[];
  @ApiProperty({ type: [KeyHistoryEntryDto] })
  key_history: KeyHistoryEntryDto[];
}

export class PaperDetailDto extends PaperDto {
  @ApiProperty({ type: [StaffPositionDto] }) positions: StaffPositionDto[];
}

export class PaperReadinessDto {
  @ApiProperty() ready: boolean;
  @ApiProperty({ type: [Object] }) problems: {
    field?: string;
    reason: string;
  }[];
}

/** What a learner sees of an option or question: never a key or explanation. */
export class LearnerOptionDto {
  @ApiProperty() id: string;
  @ApiProperty() text: string;
}

export class LearnerPositionDto {
  @ApiProperty() position: number;
  @ApiProperty({ type: String, nullable: true }) original_ref: string | null;
  @ApiProperty({
    description:
      'withdrawn positions are placeholders with no question text; they are not questions',
  })
  withdrawn: boolean;
  @ApiProperty({ type: String, nullable: true }) question_version_id:
    string | null;
  @ApiProperty({ type: String, nullable: true }) stem: string | null;
  @ApiProperty({ type: [LearnerOptionDto], nullable: true })
  options: LearnerOptionDto[] | null;
}

export class LearnerPaperDto {
  @ApiProperty() id: string;
  @ApiProperty() code: string;
  @ApiProperty() revision: number;
  @ApiProperty() title: string;
  @ApiProperty({ type: String, nullable: true }) edition: string | null;
  @ApiProperty({ type: Number, nullable: true }) year: number | null;
  @ApiProperty({ type: String, nullable: true }) set_label: string | null;
  @ApiProperty() total_questions: number;
  @ApiProperty({ type: Number, nullable: true }) duration_seconds:
    number | null;
  @ApiProperty({ type: Number, nullable: true }) practice_timer_seconds:
    number | null;
  @ApiProperty({ enum: CONFIG_STATUSES }) config_status: ConfigStatus;
}

export class LearnerPaperPageDto {
  @ApiProperty({ type: [LearnerPaperDto] }) items: LearnerPaperDto[];
  @ApiProperty({ type: String, nullable: true }) next_cursor: string | null;
}

export class LearnerPaperDetailDto extends LearnerPaperDto {
  @ApiProperty({ type: [LearnerPositionDto] }) positions: LearnerPositionDto[];
}

export class MockPlanRequestDto {
  @ApiPropertyOptional({
    description:
      'Reuse a seed to get the same plan again. Without it the server picks one and returns it.',
  })
  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z0-9_-]{8,64}$/)
  seed?: string;

  @ApiPropertyOptional({ default: 'en' })
  @IsOptional()
  @IsString()
  @MaxLength(8)
  language?: string;

  @ApiPropertyOptional({
    type: [String],
    description:
      'Question ids the learner has already met; unseen ones are preferred',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5000)
  @IsUUID('all', { each: true })
  seen_question_ids?: string[];
}
