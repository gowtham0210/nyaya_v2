import { Controller, Get, Inject } from '@nestjs/common';
import {
  ApiOkResponse,
  ApiProperty,
  ApiPropertyOptional,
  ApiTags,
} from '@nestjs/swagger';
import { asc, eq } from 'drizzle-orm';
import { Public } from '../auth/decorators.js';
import { DB, type Db } from '../core/db.js';
import { acts, subjects, topics } from '../db/schema.js';

class TopicDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() slug: string;
  @ApiProperty() name: string;
  @ApiPropertyOptional({ type: String, nullable: true }) description:
    string | null;
  @ApiPropertyOptional({ type: String, format: 'uuid', nullable: true })
  act_id: string | null;
}

class SubjectDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() slug: string;
  @ApiProperty() name: string;
  @ApiPropertyOptional({ type: String, nullable: true }) description:
    string | null;
  @ApiProperty({ type: [TopicDto] }) topics: TopicDto[];
}

class ActDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() slug: string;
  @ApiProperty() name: string;
  @ApiPropertyOptional({ type: String, nullable: true }) short_name:
    string | null;
  @ApiPropertyOptional({ type: Number, nullable: true }) year: number | null;
  @ApiProperty({ example: 'IN' }) jurisdiction: string;
}

class TaxonomyDto {
  @ApiProperty({ type: [SubjectDto] }) subjects: SubjectDto[];
  @ApiProperty({ type: [ActDto] }) acts: ActDto[];
}

@ApiTags('taxonomy')
@Controller('taxonomy')
export class TaxonomyController {
  constructor(@Inject(DB) private readonly db: Db) {}

  /** Active subjects with their active topics, and active acts. */
  @Public()
  @Get()
  @ApiOkResponse({ type: TaxonomyDto })
  async get(): Promise<TaxonomyDto> {
    const [subjectRows, topicRows, actRows] = await Promise.all([
      this.db
        .select()
        .from(subjects)
        .where(eq(subjects.isActive, true))
        .orderBy(asc(subjects.sortOrder), asc(subjects.name)),
      this.db
        .select()
        .from(topics)
        .where(eq(topics.isActive, true))
        .orderBy(asc(topics.sortOrder), asc(topics.name)),
      this.db
        .select()
        .from(acts)
        .where(eq(acts.isActive, true))
        .orderBy(asc(acts.name)),
    ]);
    return {
      subjects: subjectRows.map((s) => ({
        id: s.id,
        slug: s.slug,
        name: s.name,
        description: s.description,
        topics: topicRows
          .filter((t) => t.subjectId === s.id)
          .map((t) => ({
            id: t.id,
            slug: t.slug,
            name: t.name,
            description: t.description,
            act_id: t.actId,
          })),
      })),
      acts: actRows.map((a) => ({
        id: a.id,
        slug: a.slug,
        name: a.name,
        short_name: a.shortName,
        year: a.year,
        jurisdiction: a.jurisdiction,
      })),
    };
  }
}
