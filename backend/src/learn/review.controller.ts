import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import type { AuthUser } from '../auth/auth-user.js';
import { CurrentUser } from '../auth/decorators.js';
import {
  BookmarkDto,
  BookmarkListDto,
  MistakeListDto,
  SaveBookmarkDto,
} from './review.dto.js';
import { ReviewService } from './review.service.js';

@ApiTags('review')
@ApiBearerAuth()
@Controller('me')
export class ReviewController {
  constructor(private readonly review: ReviewService) {}

  @Get('mistakes')
  @ApiOperation({
    summary:
      'Questions whose latest answer was wrong, newest first; answering one right later removes it',
  })
  @ApiOkResponse({ type: MistakeListDto })
  mistakes(@CurrentUser() user: AuthUser) {
    return this.review.mistakes(user.id);
  }

  @Get('bookmarks')
  @ApiOperation({ summary: 'Saved questions, newest first' })
  @ApiOkResponse({ type: BookmarkListDto })
  bookmarks(@CurrentUser() user: AuthUser) {
    return this.review.bookmarks(user.id);
  }

  @Post('bookmarks')
  @HttpCode(201)
  @ApiOperation({
    summary: 'Save a question you have answered (saving again is harmless)',
  })
  @ApiOkResponse({ type: BookmarkDto })
  save(@CurrentUser() user: AuthUser, @Body() body: SaveBookmarkDto) {
    return this.review.save(user.id, body.question_id);
  }

  @Delete('bookmarks/:question_id')
  @HttpCode(204)
  @ApiOperation({ summary: 'Remove a saved question' })
  unsave(
    @CurrentUser() user: AuthUser,
    @Param('question_id', new ParseUUIDPipe()) questionId: string,
  ) {
    return this.review.unsave(user.id, questionId);
  }
}
