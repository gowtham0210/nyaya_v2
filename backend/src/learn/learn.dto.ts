import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
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
  QUIZ_MODES,
  type FeedbackMode,
  type QuizMode,
} from '../db/schema.js';

export const SESSION_STATUSES = ['in_progress', 'submitted'] as const;
export type SessionStatus = (typeof SESSION_STATUSES)[number];
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
  @ApiProperty() topic_slug: string;
  @ApiProperty() topic_name: string;
  @ApiProperty({ format: 'uuid' }) subject_id: string;
  @ApiProperty() subject_slug: string;
  @ApiProperty() subject_name: string;
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

/** Which questions to draw. With no topic given, every topic is used. */
export class StartSessionDto {
  @ApiProperty({
    enum: QUIZ_MODES,
    description:
      "case_path: one level (one subject, one difficulty). daily_docket: today's set, the same for everyone, once a day. duel: practice against the clock. exam: answers revealed at the end. Decides feedback and rewards.",
  })
  @IsIn(QUIZ_MODES)
  mode: QuizMode;

  @ApiPropertyOptional({
    default: true,
    description: 'Exam only: take 0.25 off for each wrong answer',
  })
  @IsOptional()
  @IsBoolean()
  negative_marking?: boolean;

  @ApiPropertyOptional({ format: 'uuid', description: 'A single topic' })
  @IsOptional()
  @IsUUID()
  topic_id?: string;

  @ApiPropertyOptional({
    type: [String],
    format: 'uuid',
    description: 'Several topics',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @IsUUID('all', { each: true })
  topic_ids?: string[];

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

  @ApiPropertyOptional({ minimum: 1, maximum: 3 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(3)
  min_difficulty?: number;

  @ApiPropertyOptional({ minimum: 1, maximum: 3 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(3)
  max_difficulty?: number;

  @ApiPropertyOptional({ enum: SUPPORTED_LANGUAGES, default: 'en' })
  @IsOptional()
  @IsIn(SUPPORTED_LANGUAGES)
  language?: string;
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
  @ApiProperty({ format: 'uuid' }) topic_id: string;
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
  @ApiProperty({ enum: QUIZ_MODES }) mode: QuizMode;
  @ApiProperty({ type: [String], description: 'Empty means every topic' })
  topic_ids: string[];
  @ApiProperty({ type: String, format: 'date', nullable: true }) daily:
    string | null;
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

export class XpBreakdownDto {
  @ApiProperty() question_xp: number;
  @ApiProperty() completion_bonus: number;
  @ApiProperty() perfect_bonus: number;
  @ApiProperty({
    description:
      '1.25 for the docket, 0.5 for replaying a 3-star level, else 1',
  })
  mode_multiplier: number;
  @ApiProperty() streak_multiplier: number;
  @ApiProperty() total: number;
}

/** What this session earned, worked out by the server. */
export class RewardsDto {
  @ApiProperty({ type: XpBreakdownDto }) xp: XpBreakdownDto;
  @ApiProperty({
    type: String,
    nullable: true,
    description: 'Case Path level, e.g. constitution_2',
  })
  level_id: string | null;
  @ApiProperty({ type: Number, nullable: true, description: 'Case Path only' })
  stars: number | null;
  @ApiProperty({ description: 'Best stars on this level before this session' })
  best_stars_before: number;
  @ApiProperty({ description: 'Stars added to the level best' })
  new_stars: number;
  @ApiProperty({ description: 'Streak after this session' }) streak: number;
  @ApiProperty({
    description: "True when this was today's first finished quiz",
  })
  streak_extended: boolean;
  @ApiProperty({ type: Number, nullable: true, description: '3, 7, 14 … days' })
  streak_milestone: number | null;
}

export class ResultDto {
  @ApiProperty({ format: 'uuid' }) session_id: string;
  @ApiProperty({ enum: QUIZ_MODES }) mode: QuizMode;
  @ApiProperty({ type: [String] }) topic_ids: string[];
  @ApiProperty() scoring_version: string;
  @ApiProperty() score: number;
  @ApiProperty() total: number;
  @ApiProperty() correct_count: number;
  @ApiProperty() answered_count: number;
  @ApiProperty({ format: 'date-time' }) started_at: string;
  @ApiProperty({ format: 'date-time' }) submitted_at: string;
  @ApiProperty() duration_seconds: number;
  @ApiProperty({ type: [SessionQuestionDto] }) questions: SessionQuestionDto[];
  @ApiProperty({ type: RewardsDto }) rewards: RewardsDto;
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
  @ApiProperty({ enum: QUIZ_MODES }) mode: QuizMode;
  @ApiProperty({ type: [String] }) topic_ids: string[];
  @ApiProperty() score: number;
  @ApiProperty() total: number;
  @ApiProperty() xp: number;
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

export class StreakDto {
  @ApiProperty({ description: 'Current streak today; 0 once it has lapsed' })
  current: number;
  @ApiProperty() longest: number;
  @ApiProperty({ description: 'Free freezes left (earned at 7, 30, 100 days)' })
  freezes: number;
  @ApiProperty({ type: String, format: 'date', nullable: true })
  last_active_day: string | null;
  @ApiProperty({
    type: [String],
    description: 'Days with a finished quiz, last 21, India dates',
  })
  active_days: string[];
  @ApiProperty({
    type: [String],
    description: 'Missed days a freeze covered, last 21',
  })
  frozen_days: string[];
}

export class WeekXpDto {
  @ApiProperty({ example: '2026-W44' }) week_id: string;
  @ApiProperty() xp: number;
}

export class ProgressDto {
  @ApiProperty({
    format: 'date',
    description: 'India date the figures are for',
  })
  today: string;
  @ApiProperty() total_xp: number;
  @ApiProperty({
    type: WeekXpDto,
    description: 'This week (Monday–Sunday, India)',
  })
  week: WeekXpDto;
  @ApiProperty({
    type: WeekXpDto,
    description: 'Last week, for closing the league',
  })
  last_week: WeekXpDto;
  @ApiProperty({ type: StreakDto }) streak: StreakDto;
  @ApiProperty({
    description: 'Best Case Path stars per level id',
    example: { constitution_1: 3, constitution_2: 1 },
  })
  stars: Record<string, number>;
  @ApiProperty({ type: [String], example: ['constitution_chest'] })
  opened_chests: string[];
  @ApiProperty() quizzes_completed: number;
  @ApiProperty() quizzes_today: number;
  @ApiProperty() docket_done_today: boolean;
  @ApiProperty() attempts: number;
  @ApiProperty() questions_answered: number;
  @ApiProperty() correct: number;
  @ApiProperty({ type: [TopicProgressDto] }) topics: TopicProgressDto[];
}
