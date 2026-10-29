import {
  ApiProperty,
  ApiPropertyOptional,
  OmitType,
  PartialType,
} from '@nestjs/swagger';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';

const SLUG = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const SLUG_HELP =
  'Lower-case letters, digits and single hyphens. Fixed once created: the app, progress and import files refer to it.';

class NamedDto {
  @ApiProperty({ minLength: 2, maxLength: 120 })
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  name: string;

  @ApiPropertyOptional({ type: String, nullable: true, maxLength: 1000 })
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsString()
  @MaxLength(1000)
  description?: string | null;

  @ApiPropertyOptional({ minimum: 0, maximum: 10000 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(10000)
  sort_order?: number;
}

export class CreateSubjectDto extends NamedDto {
  @ApiProperty({ example: 'family-law', description: SLUG_HELP })
  @Matches(SLUG)
  @MaxLength(60)
  slug: string;
}

export class UpdateSubjectDto extends PartialType(
  OmitType(CreateSubjectDto, ['slug'] as const),
) {
  @ApiPropertyOptional({
    description:
      'Shown to learners. Showing a subject adds a chapter to the Case Path road; hiding it removes its questions from quizzes.',
  })
  @IsOptional()
  @IsBoolean()
  is_active?: boolean;
}

export class CreateTopicDto extends NamedDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  subject_id: string;

  @ApiProperty({ example: 'marriage-and-divorce', description: SLUG_HELP })
  @Matches(SLUG)
  @MaxLength(60)
  slug: string;

  @ApiPropertyOptional({ type: String, format: 'uuid', nullable: true })
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsUUID()
  act_id?: string | null;
}

/** A topic stays in its subject: moving it would move its questions to another chapter. */
export class UpdateTopicDto extends PartialType(
  OmitType(CreateTopicDto, ['slug', 'subject_id'] as const),
) {
  @ApiPropertyOptional({
    description: 'Hiding a topic removes its questions from quizzes at once',
  })
  @IsOptional()
  @IsBoolean()
  is_active?: boolean;
}

export class CreateActDto {
  @ApiProperty({ example: 'hindu-marriage-act-1955', description: SLUG_HELP })
  @Matches(SLUG)
  @MaxLength(60)
  slug: string;

  @ApiProperty({ minLength: 2, maxLength: 200 })
  @IsString()
  @MinLength(2)
  @MaxLength(200)
  name: string;

  @ApiPropertyOptional({ type: String, nullable: true, maxLength: 60 })
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsString()
  @MaxLength(60)
  short_name?: string | null;

  @ApiPropertyOptional({ type: Number, nullable: true })
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsInt()
  @Min(1800)
  @Max(2100)
  year?: number | null;
}

export class UpdateActDto extends PartialType(
  OmitType(CreateActDto, ['slug'] as const),
) {
  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  is_active?: boolean;
}

// ------------------------------------------------------------ responses

export class AdminTopicDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ format: 'uuid' }) subject_id: string;
  @ApiProperty() slug: string;
  @ApiProperty() name: string;
  @ApiProperty({ type: String, nullable: true }) description: string | null;
  @ApiProperty({ type: String, format: 'uuid', nullable: true })
  act_id: string | null;
  @ApiProperty() sort_order: number;
  @ApiProperty() is_active: boolean;
  @ApiProperty({
    description: 'Questions whose latest version is in this topic',
  })
  question_count: number;
  @ApiProperty({
    description: 'Questions with a live (published) version here',
  })
  live_count: number;
}

export class AdminSubjectDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() slug: string;
  @ApiProperty() name: string;
  @ApiProperty({ type: String, nullable: true }) description: string | null;
  @ApiProperty() sort_order: number;
  @ApiProperty() is_active: boolean;
  @ApiProperty({ type: [AdminTopicDto], description: 'Hidden ones included' })
  topics: AdminTopicDto[];
}

export class AdminActDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() slug: string;
  @ApiProperty() name: string;
  @ApiProperty({ type: String, nullable: true }) short_name: string | null;
  @ApiProperty({ type: Number, nullable: true }) year: number | null;
  @ApiProperty() jurisdiction: string;
  @ApiProperty() is_active: boolean;
  @ApiProperty({ description: 'Topics that name this act' })
  topic_count: number;
}

export class AdminTaxonomyDto {
  @ApiProperty({ type: [AdminSubjectDto] }) subjects: AdminSubjectDto[];
  @ApiProperty({ type: [AdminActDto] }) acts: AdminActDto[];
}
