import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsBoolean,
  IsIn,
  IsInt,
  IsNumber,
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
  BLUEPRINT_STATUSES,
  CONFIG_STATUSES,
  LAW_REGIME_FILTERS,
  SECTION_NAVIGATIONS,
  type BlueprintStatus,
  type ConfigStatus,
  type LawRegimeFilter,
} from '../db/schema.js';
import { EXAM_SLUGS, type ExamSlug } from './exam-config.js';

const CODE = /^[a-z0-9][a-z0-9-]{0,62}$/;
const DAY = /^\d{4}-\d{2}-\d{2}$/;
const marks = { maxDecimalPlaces: 2 } as const;

// ---------------------------------------------------------------- exams

export class CreateExamDto {
  @ApiProperty({ enum: EXAM_SLUGS })
  @IsIn(EXAM_SLUGS)
  slug: ExamSlug;

  @ApiProperty({ maxLength: 200 })
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  name: string;

  @ApiProperty({ maxLength: 40 })
  @IsString()
  @MinLength(1)
  @MaxLength(40)
  short_name: string;

  @ApiPropertyOptional({ maxLength: 10000 })
  @IsOptional()
  @IsString()
  @MaxLength(10000)
  instructions?: string;

  @ApiPropertyOptional({ minimum: 0, maximum: 1000 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1000)
  sort_order?: number;
}

export class UpdateExamDto {
  @ApiPropertyOptional({ maxLength: 200 })
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  name?: string;

  @ApiPropertyOptional({ maxLength: 40 })
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(40)
  short_name?: string;

  @ApiPropertyOptional({ maxLength: 10000 })
  @IsOptional()
  @IsString()
  @MaxLength(10000)
  instructions?: string;

  @ApiPropertyOptional({ minimum: 0, maximum: 1000 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1000)
  sort_order?: number;

  @ApiPropertyOptional({
    description:
      'Turning an exam on needs at least one published blueprint. New exams start off.',
  })
  @IsOptional()
  @IsBoolean()
  is_active?: boolean;
}

// ---------------------------------------------------------------- blueprints

export class BlueprintFieldsDto {
  @ApiProperty({ minimum: 60, maximum: 86400 })
  @IsInt()
  @Min(60)
  @Max(86_400)
  duration_seconds: number;

  @ApiProperty({ minimum: 1, maximum: 1000 })
  @IsInt()
  @Min(1)
  @Max(1000)
  total_questions: number;

  @ApiProperty({ minimum: 0, maximum: 999.99 })
  @IsNumber(marks)
  @Min(0)
  @Max(999.99)
  marks_correct: number;

  @ApiPropertyOptional({
    minimum: 0,
    description: 'Marks taken off a wrong answer, as a positive number',
  })
  @IsOptional()
  @IsNumber(marks)
  @Min(0)
  @Max(999.99)
  negative_marks?: number;

  @ApiPropertyOptional({ minimum: 0 })
  @IsOptional()
  @IsNumber(marks)
  @Min(0)
  @Max(999.99)
  marks_unanswered?: number;

  @ApiPropertyOptional({ nullable: true, minimum: 0, maximum: 100 })
  @IsOptional()
  @IsNumber(marks)
  @Min(0)
  @Max(100)
  pass_percent_general?: number | null;

  @ApiPropertyOptional({ nullable: true, minimum: 0, maximum: 100 })
  @IsOptional()
  @IsNumber(marks)
  @Min(0)
  @Max(100)
  pass_percent_reserved?: number | null;

  @ApiPropertyOptional({ enum: SECTION_NAVIGATIONS, default: 'free' })
  @IsOptional()
  @IsIn(SECTION_NAVIGATIONS)
  section_navigation?: (typeof SECTION_NAVIGATIONS)[number];

  @ApiPropertyOptional({
    enum: LAW_REGIME_FILTERS,
    default: 'any',
    description:
      'How randomised mocks treat questions only about the old codes (IPC, CrPC, Evidence Act). Random mocks test current law, so any (the default), exclude_old and prefer_new all leave them out; only include_all lets them in. Fixed historical papers are never filtered.',
  })
  @IsOptional()
  @IsIn(LAW_REGIME_FILTERS)
  law_regime_filter?: LawRegimeFilter;

  @ApiPropertyOptional({ enum: CONFIG_STATUSES, default: 'unverified' })
  @IsOptional()
  @IsIn(CONFIG_STATUSES)
  config_status?: ConfigStatus;

  @ApiPropertyOptional({
    nullable: true,
    description: 'The official document the rules come from',
  })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  config_source?: string | null;

  @ApiPropertyOptional({ nullable: true, example: '2026-11-18' })
  @IsOptional()
  @Matches(DAY, { message: 'config_checked_on must be YYYY-MM-DD' })
  config_checked_on?: string | null;
}

export class CreateBlueprintDto extends BlueprintFieldsDto {
  @ApiProperty()
  @IsUUID()
  exam_id: string;

  @ApiProperty({ example: 'aibe-xx' })
  @Matches(CODE, {
    message: 'code must be lower-case letters, digits and hyphens',
  })
  code: string;
}

export class UpdateBlueprintDto extends PartialType(BlueprintFieldsDto) {}

export class SectionTopicDto {
  @ApiProperty()
  @IsUUID()
  topic_id: string;

  @ApiPropertyOptional({ minimum: 0, default: 0 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1000)
  min_count?: number;

  @ApiPropertyOptional({ nullable: true, minimum: 0 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1000)
  max_count?: number | null;

  @ApiPropertyOptional({ minimum: 1, default: 1 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(1000)
  weight?: number;
}

export class SectionDto {
  @ApiProperty({ example: 'cpc' })
  @Matches(CODE, {
    message: 'code must be lower-case letters, digits and hyphens',
  })
  code: string;

  @ApiProperty({ maxLength: 200 })
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  name: string;

  @ApiProperty({ minimum: 1 })
  @IsInt()
  @Min(1)
  @Max(100)
  position: number;

  @ApiProperty({ minimum: 1 })
  @IsInt()
  @Min(1)
  @Max(1000)
  question_count: number;

  @ApiPropertyOptional({
    nullable: true,
    description: 'Only for a section with its own timer',
  })
  @IsOptional()
  @IsInt()
  @Min(60)
  @Max(86_400)
  duration_seconds?: number | null;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @IsNumber(marks)
  @Min(0)
  @Max(999.99)
  marks_correct?: number | null;

  @ApiProperty({ type: [SectionTopicDto] })
  @ValidateNested({ each: true })
  @Type(() => SectionTopicDto)
  @ArrayMaxSize(100)
  topics: SectionTopicDto[];
}

export class ReplaceSectionsDto {
  @ApiProperty({ type: [SectionDto] })
  @ValidateNested({ each: true })
  @Type(() => SectionDto)
  @ArrayMaxSize(50)
  sections: SectionDto[];
}

// ---------------------------------------------------------------- responses

export class ExamDto {
  @ApiProperty() id: string;
  @ApiProperty({ enum: EXAM_SLUGS }) slug: ExamSlug;
  @ApiProperty() name: string;
  @ApiProperty() short_name: string;
  @ApiProperty() is_active: boolean;
  @ApiProperty() sort_order: number;
  @ApiProperty() instructions: string;
  @ApiProperty() created_at: string;
  @ApiProperty() updated_at: string;
}

export class SectionTopicOutDto {
  @ApiProperty() topic_id: string;
  @ApiProperty() min_count: number;
  @ApiProperty({ type: Number, nullable: true }) max_count: number | null;
  @ApiProperty() weight: number;
}

export class SectionOutDto {
  @ApiProperty() id: string;
  @ApiProperty() code: string;
  @ApiProperty() name: string;
  @ApiProperty() position: number;
  @ApiProperty() question_count: number;
  @ApiProperty({ type: Number, nullable: true }) duration_seconds:
    number | null;
  @ApiProperty({ type: Number, nullable: true }) marks_correct: number | null;
  @ApiProperty({ type: [SectionTopicOutDto] }) topics: SectionTopicOutDto[];
}

export class BlueprintDto {
  @ApiProperty() id: string;
  @ApiProperty() exam_id: string;
  @ApiProperty() code: string;
  @ApiProperty() version: number;
  @ApiProperty({ enum: BLUEPRINT_STATUSES }) status: BlueprintStatus;
  @ApiProperty({
    description:
      'True for the one blueprint randomised mocks of this exam use. At most one per exam, and only a published one; it is set on purpose, never by publishing.',
  })
  is_current: boolean;
  @ApiProperty() duration_seconds: number;
  @ApiProperty() total_questions: number;
  @ApiProperty() marks_correct: number;
  @ApiProperty() negative_marks: number;
  @ApiProperty() marks_unanswered: number;
  @ApiProperty({ type: Number, nullable: true }) pass_percent_general:
    number | null;
  @ApiProperty({ type: Number, nullable: true }) pass_percent_reserved:
    number | null;
  @ApiProperty({ enum: SECTION_NAVIGATIONS }) section_navigation: string;
  @ApiProperty({ enum: LAW_REGIME_FILTERS }) law_regime_filter: LawRegimeFilter;
  @ApiProperty({ enum: CONFIG_STATUSES }) config_status: ConfigStatus;
  @ApiProperty({ type: String, nullable: true }) config_source: string | null;
  @ApiProperty({ type: String, format: 'date', nullable: true })
  config_checked_on: string | null;
  @ApiProperty({
    description:
      'Whether this blueprint may be used for timed mocks. False unless it is published and official-confirmed.',
  })
  timed_allowed: boolean;
  @ApiProperty({ type: String, nullable: true })
  timed_blocked_reason: string | null;
  @ApiProperty({ type: [SectionOutDto] }) sections: SectionOutDto[];
  @ApiProperty() created_at: string;
  @ApiProperty() updated_at: string;
}

export class ExamDetailDto extends ExamDto {
  @ApiProperty({ type: String, nullable: true })
  current_blueprint_id: string | null;
  @ApiProperty({ type: [BlueprintDto] }) blueprints: BlueprintDto[];
}

export class ExamListDto {
  @ApiProperty({ type: [ExamDto] }) items: ExamDto[];
}

export class ExamEligibilityReasonDto {
  @ApiProperty() code: string;
  @ApiProperty() message: string;
}

export class ExamEligibilityDto {
  @ApiProperty() eligible: boolean;
  @ApiProperty({ type: Boolean, nullable: true }) exam_only: boolean | null;
  @ApiProperty({ type: String, nullable: true }) law_regime: string | null;
  @ApiProperty({ enum: LAW_REGIME_FILTERS }) law_regime_filter: LawRegimeFilter;
  @ApiProperty({
    type: String,
    nullable: true,
    description: 'The blueprint whose rule was applied, if any',
  })
  blueprint_id: string | null;
  @ApiProperty({ type: [ExamEligibilityReasonDto] })
  reasons: ExamEligibilityReasonDto[];
}

export class ExamEligibilityQuery {
  @ApiPropertyOptional({
    description:
      "A blueprint of this exam, whose law-regime rule is applied. Without it the exam's current blueprint is used, and with no current blueprint the rule is 'any'.",
  })
  @IsOptional()
  @IsUUID()
  blueprint_id?: string;

  @ApiPropertyOptional({ default: 'en' })
  @IsOptional()
  @IsString()
  @MaxLength(8)
  language?: string;
}
