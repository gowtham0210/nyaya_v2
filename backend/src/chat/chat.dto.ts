import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsIn,
  IsString,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { SUPPORTED_LANGUAGES } from '../questions/workflow.js';
import { PERSONAS, type Persona } from './chat.prompt.js';

export const MAX_TURNS = 20;
export const MAX_TURN_CHARS = 4000;

export class ChatTurnDto {
  @ApiProperty({ enum: ['user', 'assistant'] })
  @IsIn(['user', 'assistant'])
  role: 'user' | 'assistant';

  @ApiProperty({ maxLength: MAX_TURN_CHARS })
  @IsString()
  @MinLength(1)
  @MaxLength(MAX_TURN_CHARS)
  content: string;
}

export class ChatRequestDto {
  @ApiProperty({
    type: [ChatTurnDto],
    description: `The conversation so far, oldest first, ending with the learner's question (at most ${MAX_TURNS} turns)`,
  })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(MAX_TURNS)
  @ValidateNested({ each: true })
  @Type(() => ChatTurnDto)
  messages: ChatTurnDto[];

  @ApiProperty({ enum: SUPPORTED_LANGUAGES })
  @IsIn(SUPPORTED_LANGUAGES)
  language: string;

  @ApiProperty({ enum: PERSONAS })
  @IsIn(PERSONAS)
  persona: Persona;
}

export class ChatReplyDto {
  @ApiProperty() reply: string;
  @ApiProperty({ description: 'AI answers left today (India date)' })
  remaining_today: number;
}
