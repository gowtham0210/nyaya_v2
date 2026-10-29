import { ApiProperty } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';
import { OptionDto } from '../questions/questions.dto.js';

/**
 * A question the learner has already answered, shown as the version they
 * answered, with its answer. When it is retired or no longer in force it is
 * shown as unavailable, with only the text they saw.
 */
export class ReviewQuestionDto {
  @ApiProperty({ format: 'uuid' }) question_id: string;
  @ApiProperty({ description: 'False when retired or no longer in force' })
  available: boolean;
  @ApiProperty({
    description:
      'The question was revised after the learner answered it; this is the version they answered',
  })
  updated_since: boolean;
  @ApiProperty() stem: string;
  @ApiProperty({ type: [OptionDto] }) options: OptionDto[];
  @ApiProperty({ type: [String] }) correct_option_ids: string[];
  @ApiProperty({ type: String, nullable: true }) explanation: string | null;
  @ApiProperty({ type: String, nullable: true }) provision_reference:
    string | null;
  @ApiProperty({ type: String, nullable: true }) source_title: string | null;
  @ApiProperty({ type: String, format: 'uuid', nullable: true })
  topic_id: string | null;
}

export class MistakeDto {
  @ApiProperty({ type: ReviewQuestionDto }) question: ReviewQuestionDto;
  @ApiProperty({ description: 'Times answered wrong' }) wrong_count: number;
  @ApiProperty({ format: 'date-time' }) last_wrong_at: string;
  @ApiProperty({ description: 'Also saved by the learner' }) saved: boolean;
}

export class MistakeListDto {
  @ApiProperty({ type: [MistakeDto] }) items: MistakeDto[];
}

export class BookmarkDto {
  @ApiProperty({ type: ReviewQuestionDto }) question: ReviewQuestionDto;
  @ApiProperty({ format: 'date-time' }) saved_at: string;
}

export class BookmarkListDto {
  @ApiProperty({ type: [BookmarkDto] }) items: BookmarkDto[];
}

export class SaveBookmarkDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  question_id: string;
}
