import { Module } from '@nestjs/common';
import { EditorNewsController, NewsController } from './news.controller.js';
import { NewsService } from './news.service.js';

@Module({
  controllers: [NewsController, EditorNewsController],
  providers: [NewsService],
})
export class NewsModule {}
