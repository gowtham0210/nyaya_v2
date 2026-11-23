import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
  IsBoolean,
} from 'class-validator';
import {
  EXAM_ATTEMPT_KINDS,
  EXAM_ATTEMPT_MODES,
  EXAM_ATTEMPT_STATUSES,
  type ExamAttemptKind,
  type ExamAttemptMode,
  type ExamAttemptStatus,
} from '../db/schema.js';

export class StartAttemptDto {
  @ApiProperty({ enum: EXAM_ATTEMPT_KINDS })
  @IsIn(EXAM_ATTEMPT_KINDS)
  kind: ExamAttemptKind;

  @ApiPropertyOptional({
    format: 'uuid',
    description: 'Required for fixed_paper: a published paper of this exam',
  })
  @IsOptional()
  @IsUUID()
  paper_id?: string;

  @ApiPropertyOptional({
    enum: EXAM_ATTEMPT_MODES,
    default: 'practice',
    description:
      'practice has no deadline. timed gets a server deadline and is only allowed when the rules are officially confirmed.',
  })
  @IsOptional()
  @IsIn(EXAM_ATTEMPT_MODES)
  mode?: ExamAttemptMode;

  @ApiPropertyOptional({
    default: false,
    description:
      "fixed_paper in practice mode only: run the paper's practice timer (a server deadline). It is practice timing, not the official timed mode, and needs no confirmed rules.",
  })
  @IsOptional()
  @IsBoolean()
  practice_timer?: boolean;

  @ApiPropertyOptional({ default: 'en', description: 'random_mock only' })
  @IsOptional()
  @IsString()
  @MaxLength(8)
  language?: string;
}

export class AnswerInputDto {
  @ApiProperty({ minimum: 1 }) @IsInt() @Min(1) @Max(1000) position: number;

  @ApiProperty({
    type: [String],
    description: 'The chosen option ids; empty clears the answer',
  })
  @IsArray()
  @ArrayMaxSize(6)
  @IsString({ each: true })
  @Matches(/^[a-z0-9]{1,8}$/, { each: true })
  selected_option_ids: string[];

  @ApiProperty({
    minimum: 1,
    description:
      'A counter the client raises with every change to this answer. The server keeps the answer with the highest counter, so a late or repeated request never overwrites a newer one.',
  })
  @IsInt()
  @Min(1)
  @Max(2_000_000_000)
  seq: number;
}

export class SaveAnswersDto {
  @ApiProperty({ type: [AnswerInputDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => AnswerInputDto)
  answers: AnswerInputDto[];
}

export class SaveOneAnswerDto {
  @ApiProperty({ type: [String] })
  @IsArray()
  @ArrayMaxSize(6)
  @IsString({ each: true })
  @Matches(/^[a-z0-9]{1,8}$/, { each: true })
  selected_option_ids: string[];

  @ApiProperty({ minimum: 1 })
  @IsInt()
  @Min(1)
  @Max(2_000_000_000)
  seq: number;
}

export class ListAttemptsQuery {
  @ApiPropertyOptional({ description: 'Exam slug, e.g. aibe' })
  @IsOptional()
  @IsString()
  @MaxLength(32)
  exam?: string;

  @ApiPropertyOptional({ enum: EXAM_ATTEMPT_STATUSES })
  @IsOptional()
  @IsIn(EXAM_ATTEMPT_STATUSES)
  status?: ExamAttemptStatus;

  @ApiPropertyOptional({ minimum: 1, maximum: 50, default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;

  @ApiPropertyOptional() @IsOptional() @IsString() cursor?: string;
}

/** A question as the learner sees it during an attempt: no key, no explanation. */
export class AttemptQuestionDto {
  @ApiProperty() position: number;
  @ApiProperty({ type: String, nullable: true }) section_code: string | null;
  @ApiProperty({ type: String, nullable: true }) original_ref: string | null;
  @ApiProperty({
    description: 'A withdrawn position is a placeholder, not a question',
  })
  withdrawn: boolean;
  @ApiProperty({ type: String, nullable: true }) question_version_id:
    string | null;
  @ApiProperty({ type: String, nullable: true }) stem: string | null;
  @ApiProperty({ type: [Object], nullable: true })
  options: { id: string; text: string }[] | null;
  @ApiProperty({ type: [String], nullable: true }) selected_option_ids:
    string[] | null;
  @ApiProperty() answer_seq: number;
}

export class AttemptDto {
  @ApiProperty() id: string;
  @ApiProperty({ enum: EXAM_ATTEMPT_KINDS }) kind: ExamAttemptKind;
  @ApiProperty({ enum: EXAM_ATTEMPT_MODES }) mode: ExamAttemptMode;
  @ApiProperty({ enum: EXAM_ATTEMPT_STATUSES }) status: ExamAttemptStatus;
  @ApiProperty() exam: string;
  @ApiProperty({ type: Object, nullable: true }) paper: {
    id: string;
    code: string;
    title: string;
    revision: number;
  } | null;
  @ApiProperty() language: string;
  @ApiProperty() started_at: string;
  @ApiProperty({
    type: String,
    nullable: true,
    description: 'Set by the server; the app only displays it',
  })
  deadline_at: string | null;
  @ApiProperty({ description: 'The server clock, to correct for device skew' })
  server_now: string;
  @ApiProperty({ type: Number, nullable: true })
  remaining_seconds: number | null;
  @ApiProperty({ enum: ['free', 'locked_order'] }) section_navigation:
    'free' | 'locked_order';
  @ApiProperty({ type: Number, nullable: true })
  current_section_position: number | null;
  @ApiProperty({ type: [Object] }) sections: {
    code: string;
    position: number;
    question_count: number;
  }[];
  @ApiProperty() total_questions: number;
  @ApiProperty() answered_count: number;
  @ApiProperty({ type: String, nullable: true }) submitted_at: string | null;
  @ApiProperty({
    description: 'True once finalised: results can now be fetched',
  })
  result_available: boolean;
  @ApiProperty({ type: [AttemptQuestionDto] }) questions: AttemptQuestionDto[];
}

export class SaveAnswersResultDto {
  @ApiProperty() attempt_id: string;
  @ApiProperty() server_now: string;
  @ApiProperty({ type: String, nullable: true }) deadline_at: string | null;
  @ApiProperty({ type: Number, nullable: true })
  remaining_seconds: number | null;
  @ApiProperty({
    type: [Object],
    description:
      'Per answer: applied, or why it was ignored (stale, duplicate, conflict), with what the server holds',
  })
  results: {
    position: number;
    applied: boolean;
    reason: 'stale' | 'duplicate' | 'conflict' | null;
    selected_option_ids: string[] | null;
    seq: number;
  }[];
}

export class AttemptResultDto {
  @ApiProperty() attempt_id: string;
  @ApiProperty({ enum: ['submitted', 'expired'] }) status: string;
  @ApiProperty({ enum: ['learner', 'expiry', 'sweep'] }) finalised_by: string;
  @ApiProperty() submitted_at: string;
  @ApiProperty({ type: Object }) result: Record<string, unknown>;
}

export class AttemptSummaryDto {
  @ApiProperty() id: string;
  @ApiProperty({ enum: EXAM_ATTEMPT_KINDS }) kind: ExamAttemptKind;
  @ApiProperty({ enum: EXAM_ATTEMPT_MODES }) mode: ExamAttemptMode;
  @ApiProperty({ enum: EXAM_ATTEMPT_STATUSES }) status: ExamAttemptStatus;
  @ApiProperty() exam: string;
  @ApiProperty({ type: String, nullable: true }) paper_title: string | null;
  @ApiProperty() started_at: string;
  @ApiProperty({ type: String, nullable: true }) submitted_at: string | null;
  @ApiProperty({ type: Number, nullable: true }) marks_obtained: number | null;
  @ApiProperty({ type: Number, nullable: true }) max_marks: number | null;
  @ApiProperty({ type: Number, nullable: true }) percentage: number | null;
  @ApiProperty({ type: Boolean, nullable: true }) provisional: boolean | null;
}

export class AttemptPageDto {
  @ApiProperty({ type: [AttemptSummaryDto] }) items: AttemptSummaryDto[];
  @ApiProperty({ type: String, nullable: true }) next_cursor: string | null;
}

export class AttemptStatsDto {
  @ApiProperty({ type: [Object] }) exams: {
    exam: string;
    attempts: number;
    with_marks: number;
    average_percentage: number | null;
    best_percentage: number | null;
    last_attempt_at: string | null;
  }[];
}
