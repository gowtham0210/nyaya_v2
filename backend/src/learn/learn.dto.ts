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
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import {
  FEEDBACK_MODES,
  SESSION_STATUSES,
  type FeedbackMode,
  type SessionStatus,
} from '../db/schema.js';
import { OptionDto } from '../questions/questions.dto.js';
import { SUPPORTED_LANGUAGES } from '../questions/workflow.js';
import { MAX_QUESTIONS } from './scoring.js';

export class CatalogQuery {
  @ApiPropertyOptional({ enum: SUPPORTED_LANGUAGES, default: 'en' })
  @IsOptional()
  @IsIn(SUPPORTED_LANGUAGES)
  language?: string;
}

export class TopicQuizDto {
  @ApiProperty({ format: 'uuid' }) topic_id: string;
  @ApiProperty({ format: 'uuid' }) subject_id: string;
  @ApiProperty() subject_name: string;
  @ApiProperty() topic_name: string;
  @ApiProperty({ description: 'Published questions currently in force' })
  available: number;
  @ApiProperty({
    description: 'Available questions per difficulty (1–3)',
    example: { '1': 4, '2': 2, '3': 0 },
  })
  by_difficulty: Record<string, number>;
}

export class CatalogDto {
  @ApiProperty() language: string;
  @ApiProperty({ type: [TopicQuizDto] }) topics: TopicQuizDto[];
  @ApiProperty() max_questions: number;
}

export class StartSessionDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  topic_id: string;

  @ApiPropertyOptional({ minimum: 1, maximum: MAX_QUESTIONS, default: 10 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(MAX_QUESTIONS)
  question_count?: number;

  @ApiPropertyOptional({
    minimum: 1,
    maximum: 3,
    description: 'Only this difficulty; any when omitted',
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(3)
  difficulty?: number;

  @ApiPropertyOptional({ enum: SUPPORTED_LANGUAGES, default: 'en' })
  @IsOptional()
  @IsIn(SUPPORTED_LANGUAGES)
  language?: string;

  @ApiPropertyOptional({
    enum: FEEDBACK_MODES,
    default: 'immediate',
    description:
      'immediate: each answer is final and explained at once. end: answers can change; nothing is revealed until submit.',
  })
  @IsOptional()
  @IsIn(FEEDBACK_MODES)
  feedback_mode?: FeedbackMode;
}

export class AnswerDto {
  @ApiProperty({ minimum: 1 })
  @IsInt()
  @Min(1)
  @Max(MAX_QUESTIONS)
  position: number;

  @ApiProperty({ type: [String], example: ['a'] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(6)
  @IsString({ each: true })
  @MaxLength(8, { each: true })
  selected_option_ids: string[];
}

export class FeedbackDto {
  @ApiProperty() correct: boolean;
  @ApiProperty({ type: [String] }) correct_option_ids: string[];
  @ApiProperty() explanation: string;
  @ApiProperty({ type: String, nullable: true }) source_title: string | null;
  @ApiProperty({ type: String, nullable: true }) source_url: string | null;
  @ApiProperty({ type: String, nullable: true }) provision_reference:
    string | null;
}

export class SessionQuestionDto {
  @ApiProperty() position: number;
  @ApiProperty({ format: 'uuid' }) question_version_id: string;
  @ApiProperty() difficulty: number;
  @ApiProperty() stem: string;
  @ApiProperty({ type: [OptionDto], description: 'In the order to show them' })
  options: OptionDto[];
  @ApiProperty({ type: [String], nullable: true }) selected_option_ids:
    string[] | null;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  answered_at: string | null;
  @ApiProperty({
    type: FeedbackDto,
    nullable: true,
    description:
      'Only after this question is answered (immediate mode) or the session is submitted',
  })
  feedback: FeedbackDto | null;
}

export class SessionDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ format: 'uuid' }) topic_id: string;
  @ApiProperty() language: string;
  @ApiProperty({ type: Number, nullable: true }) difficulty: number | null;
  @ApiProperty({ enum: FEEDBACK_MODES }) feedback_mode: FeedbackMode;
  @ApiProperty({ enum: SESSION_STATUSES }) status: SessionStatus;
  @ApiProperty() scoring_version: string;
  @ApiProperty() question_count: number;
  @ApiProperty({ format: 'date-time' }) started_at: string;
  @ApiProperty({
    format: 'date-time',
    description: 'Answers are refused after this; submitting is still allowed',
  })
  expires_at: string;
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  submitted_at: string | null;
  @ApiProperty({ type: [SessionQuestionDto] }) questions: SessionQuestionDto[];
}

export class AnswerResultDto {
  @ApiProperty() position: number;
  @ApiProperty({ type: [String] }) selected_option_ids: string[];
  @ApiProperty({ format: 'date-time' }) answered_at: string;
  @ApiProperty({
    type: FeedbackDto,
    nullable: true,
    description: 'Immediate mode only',
  })
  feedback: FeedbackDto | null;
}

export class ResultDto {
  @ApiProperty({ format: 'uuid' }) session_id: string;
  @ApiProperty({ format: 'uuid' }) topic_id: string;
  @ApiProperty() scoring_version: string;
  @ApiProperty() score: number;
  @ApiProperty() total: number;
  @ApiProperty() correct_count: number;
  @ApiProperty() answered_count: number;
  @ApiProperty({ format: 'date-time' }) started_at: string;
  @ApiProperty({ format: 'date-time' }) submitted_at: string;
  @ApiProperty() duration_seconds: number;
  @ApiProperty({ type: [SessionQuestionDto] }) questions: SessionQuestionDto[];
}

export class AttemptsQuery {
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

export class AttemptDto {
  @ApiProperty({ format: 'uuid' }) session_id: string;
  @ApiProperty({ format: 'uuid' }) topic_id: string;
  @ApiProperty() score: number;
  @ApiProperty() total: number;
  @ApiProperty() scoring_version: string;
  @ApiProperty({ enum: FEEDBACK_MODES }) feedback_mode: FeedbackMode;
  @ApiProperty({ format: 'date-time' }) submitted_at: string;
}

export class AttemptPageDto {
  @ApiProperty({ type: [AttemptDto] }) items: AttemptDto[];
  @ApiProperty({ type: String, nullable: true }) next_cursor: string | null;
}

export class TopicProgressDto {
  @ApiProperty({ format: 'uuid' }) topic_id: string;
  @ApiProperty() attempts: number;
  @ApiProperty() questions_answered: number;
  @ApiProperty() correct: number;
  @ApiProperty({ description: 'correct / questions shown, 0–1' })
  accuracy: number;
  @ApiProperty({
    description: 'Best score as a fraction of the session total, 0–1',
  })
  best: number;
  @ApiProperty({ format: 'date-time' }) last_attempt_at: string;
}

export class ProgressDto {
  @ApiProperty() attempts: number;
  @ApiProperty() questions_answered: number;
  @ApiProperty() correct: number;
  @ApiProperty({ type: [TopicProgressDto] }) topics: TopicProgressDto[];
}
