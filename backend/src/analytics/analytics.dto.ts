import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional } from 'class-validator';
import { QUIZ_MODES, type QuizMode } from '../db/schema.js';

export const PERIODS = [7, 30, 90] as const;

export class AnalyticsQuery {
  @ApiPropertyOptional({
    enum: PERIODS,
    default: 30,
    description: 'Days to show, ending today (India date)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @IsIn(PERIODS)
  days?: number;
}

export class LearnerTotalsDto {
  @ApiProperty({ description: 'Learner accounts today' }) total: number;
  @ApiProperty({ description: 'Signed up in the period' })
  new_in_period: number;
  @ApiProperty({ description: 'Finished the onboarding questions' })
  onboarded: number;
  @ApiProperty({ description: 'Finished at least one quiz' })
  finished_a_quiz: number;
}

export class ActiveLearnersDto {
  @ApiProperty({ description: 'Active today' }) today: number;
  @ApiProperty({ description: 'Active in the last 7 days' })
  last_7_days: number;
  @ApiProperty({ description: 'Active in the last 30 days' })
  last_30_days: number;
}

export class DailyUsageDto {
  @ApiProperty({ format: 'date' }) date: string;
  @ApiProperty() new_learners: number;
  @ApiProperty({ description: 'Opened the app, played a quiz or asked the AI' })
  active_learners: number;
  @ApiProperty() quizzes_started: number;
  @ApiProperty() quizzes_finished: number;
  @ApiProperty() ai_answers: number;
}

export class RetentionDto {
  @ApiProperty({ description: 'Days after sign-up: 1, 7 or 30' }) day: number;
  @ApiProperty({
    description: 'Sign-ups (last 90 days) old enough to be measured',
  })
  eligible: number;
  @ApiProperty({
    description: 'Of those, active exactly that many days after signing up',
  })
  retained: number;
}

export class ModeUsageDto {
  @ApiProperty({ enum: QUIZ_MODES }) mode: QuizMode;
  @ApiProperty() started: number;
  @ApiProperty() finished: number;
  @ApiProperty({
    type: Number,
    nullable: true,
    description: 'Average share of questions right in finished quizzes, 0–100',
  })
  average_score_percent: number | null;
}

export class HardQuestionDto {
  @ApiProperty({ format: 'uuid' }) question_id: string;
  @ApiProperty() stem: string;
  @ApiProperty() topic: string;
  @ApiProperty() answers: number;
  @ApiProperty({ description: 'Share of answers that were right, 0–100' })
  correct_percent: number;
}

export class ContentHealthDto {
  @ApiProperty({ description: 'Reports not yet closed by staff' })
  open_reports: number;
  @ApiProperty({ description: 'Reports sent in the period' })
  reports_in_period: number;
  @ApiProperty({ description: 'Answers needed before a question is ranked' })
  min_answers: number;
  @ApiProperty({
    type: [HardQuestionDto],
    description: 'Most often missed, worst first',
  })
  hardest_questions: HardQuestionDto[];
}

export class AnalyticsOverviewDto {
  @ApiProperty({ format: 'date', description: 'Today in India' }) as_of: string;
  @ApiProperty({ enum: PERIODS }) days: number;
  @ApiProperty({ type: LearnerTotalsDto }) learners: LearnerTotalsDto;
  @ApiProperty({ type: ActiveLearnersDto }) active: ActiveLearnersDto;
  @ApiProperty({
    type: [DailyUsageDto],
    description: 'One entry per day, oldest first',
  })
  daily: DailyUsageDto[];
  @ApiProperty({ type: [RetentionDto] }) retention: RetentionDto[];
  @ApiProperty({ type: [ModeUsageDto] }) modes: ModeUsageDto[];
  @ApiProperty({ type: ContentHealthDto }) content: ContentHealthDto;
}
