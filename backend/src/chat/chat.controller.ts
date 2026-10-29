import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import type { AuthUser } from '../auth/auth-user.js';
import { CurrentUser } from '../auth/decorators.js';
import { ChatReplyDto, ChatRequestDto } from './chat.dto.js';
import { ChatService } from './chat.service.js';

@ApiTags('chat')
@Controller()
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  @ApiBearerAuth()
  @Post('chat')
  @HttpCode(200)
  @ApiOperation({
    summary:
      'Ask AI: answers a legal question about Indian law. Limited per learner per day.',
  })
  @ApiOkResponse({ type: ChatReplyDto })
  reply(@CurrentUser() user: AuthUser, @Body() body: ChatRequestDto) {
    return this.chat.reply(user.id, body);
  }
}
