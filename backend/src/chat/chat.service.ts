import { HttpStatus, Inject, Injectable, Logger } from '@nestjs/common';
import { and, eq, gt, sql } from 'drizzle-orm';
import { APP_CONFIG, type AppConfig } from '../core/config.js';
import { DB, type Db } from '../core/db.js';
import { ApiError } from '../core/errors.js';
import { chatUsage } from '../db/schema.js';
import { indiaToday } from '../learn/scoring.js';
import { isPremium } from '../learn/wallet.js';
import { azureChat } from './azure-chat.js';
import type { ChatReplyDto, ChatRequestDto } from './chat.dto.js';
import {
  DECLINED_REPLY,
  OFF_TOPIC_REPLY,
  asksForCode,
  looksLikeCode,
  systemPrompt,
} from './chat.prompt.js';

@Injectable()
export class ChatService {
  private readonly logger = new Logger('Chat');

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  async reply(userId: string, body: ChatRequestDto): Promise<ChatReplyDto> {
    const azure = this.config.azureOpenAi;
    if (!azure)
      throw new ApiError(
        HttpStatus.SERVICE_UNAVAILABLE,
        'chat_unavailable',
        'AI chat is not configured on this server',
      );
    const last = body.messages[body.messages.length - 1];
    if (last.role !== 'user')
      throw new ApiError(
        HttpStatus.BAD_REQUEST,
        'validation_failed',
        'The last message must be the question',
        [{ field: 'messages', reason: 'must end with a user message' }],
      );

    const day = indiaToday(new Date());
    const limit = (await isPremium(this.db, userId, {
      demo: this.config.demoPremium,
    }))
      ? this.config.chatDailyLimit
      : this.config.chatFreeDailyLimit;
    // Taken before the model call, so parallel requests can't pass the limit.
    const used = await this.reserve(userId, day, limit);
    if (used === null)
      throw new ApiError(
        HttpStatus.TOO_MANY_REQUESTS,
        'chat_limit_reached',
        `You have used today's ${limit} AI answers`,
      );

    // Not a legal question: no model call, and nothing counted.
    if (asksForCode(last.content)) {
      await this.release(userId, day);
      return { reply: OFF_TOPIC_REPLY, remaining_today: limit - used + 1 };
    }

    const result = await azureChat(
      azure,
      systemPrompt(body.language, body.persona),
      body.messages.map((m) => ({ role: m.role, content: m.content })),
    );
    // A code block is never a legal answer, whatever the question was.
    const offTopic = result.kind === 'answer' && looksLikeCode(result.text);
    // Failed and declined questions are free. An answer counts even when it is
    // code we refuse to show: the model call was paid for, so it stays capped.
    if (result.kind !== 'answer') await this.release(userId, day);
    if (result.kind === 'failed') {
      this.logger.warn(`Azure chat failed: ${result.reason}`);
      throw new ApiError(
        HttpStatus.BAD_GATEWAY,
        'chat_failed',
        'The AI service did not answer; try again',
      );
    }
    if (result.kind === 'filtered')
      return { reply: DECLINED_REPLY, remaining_today: limit - used + 1 };
    if (offTopic)
      return { reply: OFF_TOPIC_REPLY, remaining_today: limit - used };
    return { reply: result.text, remaining_today: limit - used };
  }

  /** Counts one answer for today, or returns null when the limit is used up. */
  private async reserve(
    userId: string,
    day: string,
    limit: number,
  ): Promise<number | null> {
    const [row] = await this.db
      .insert(chatUsage)
      .values({ userId, day, answers: 1 })
      .onConflictDoUpdate({
        target: [chatUsage.userId, chatUsage.day],
        set: { answers: sql`${chatUsage.answers} + 1` },
        setWhere: sql`${chatUsage.answers} < ${limit}`,
      })
      .returning({ answers: chatUsage.answers });
    return row?.answers ?? null;
  }

  private async release(userId: string, day: string): Promise<void> {
    await this.db
      .update(chatUsage)
      .set({ answers: sql`${chatUsage.answers} - 1` })
      .where(
        and(
          eq(chatUsage.userId, userId),
          eq(chatUsage.day, day),
          gt(chatUsage.answers, 0),
        ),
      );
  }
}
