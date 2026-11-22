import { HttpStatus, Inject, Injectable } from '@nestjs/common';
import { randomBytes } from 'node:crypto';
import { and, inArray } from 'drizzle-orm';
import { DB, type Db } from '../core/db.js';
import { ApiError } from '../core/errors.js';
import { questions, questionVersions } from '../db/schema.js';
import { examEligible, examPool } from './exam-eligibility.js';
import {
  buildMockPlan,
  MockPlanError,
  type MockCandidate,
  type MockPlan,
  type SectionSpec,
} from './mock-engine.js';
import { ExamsService } from './exams.service.js';
import type { MockPlanRequestDto } from './papers.dto.js';

export interface MockReadiness {
  exam_id: string;
  blueprint_id: string;
  law_regime_filter: string;
  language: string;
  pool_size: number;
  ready: boolean;
  sections: {
    code: string;
    position: number;
    needed: number;
    topics: {
      topic_id: string;
      min_count: number;
      max_count: number | null;
      eligible: number;
      distinct_concepts: number;
    }[];
  }[];
  shortfalls: { section: string; topic_id: string | null; reason: string }[];
}

/** Builds randomised-mock plans from the exam's current blueprint. Nothing is saved. */
@Injectable()
export class MockPlanService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly exams: ExamsService,
  ) {}

  /** A plan of question ids and option orders (never keys or text). */
  async generate(
    examId: string,
    req: MockPlanRequestDto,
  ): Promise<
    MockPlan & { exam_id: string; blueprint_id: string; language: string }
  > {
    const language = req.language ?? 'en';
    const bp = await this.exams.requireCurrentBlueprint(examId);
    const sections = specsOf(bp);
    const candidates = await this.candidates(
      examId,
      language,
      bp.law_regime_filter,
      sections,
    );
    const seed = req.seed ?? randomBytes(12).toString('base64url');
    try {
      const plan = buildMockPlan({
        sections,
        candidates,
        seed,
        seen: new Set(req.seen_question_ids ?? []),
      });
      return { ...plan, exam_id: examId, blueprint_id: bp.id, language };
    } catch (e) {
      if (e instanceof MockPlanError)
        throw new ApiError(
          HttpStatus.UNPROCESSABLE_ENTITY,
          e.code,
          e.message,
          e.shortfalls.map((s) => ({
            field: s.topic_id ? `${s.section}/${s.topic_id}` : s.section,
            reason: s.reason,
          })),
        );
      throw e;
    }
  }

  /** Whether a mock could be built now, and per topic how many questions could fill it. */
  async readiness(examId: string, language = 'en'): Promise<MockReadiness> {
    const bp = await this.exams.requireCurrentBlueprint(examId);
    const sections = specsOf(bp);
    const candidates = await this.candidates(
      examId,
      language,
      bp.law_regime_filter,
      sections,
    );
    let shortfalls: MockReadiness['shortfalls'] = [];
    try {
      buildMockPlan({ sections, candidates, seed: 'readiness-check' });
    } catch (e) {
      if (!(e instanceof MockPlanError)) throw e;
      shortfalls = e.shortfalls;
    }
    return {
      exam_id: examId,
      blueprint_id: bp.id,
      law_regime_filter: bp.law_regime_filter,
      language,
      pool_size: new Set(candidates.map((c) => c.questionId)).size,
      ready: shortfalls.length === 0,
      sections: sections.map((s) => ({
        code: s.code,
        position: s.position,
        needed: s.questionCount,
        topics: s.topics.map((t) => {
          const mine = candidates.filter((c) => c.topicId === t.topicId);
          const concepts = new Set(
            mine.filter((c) => c.conceptKey).map((c) => c.conceptKey),
          );
          return {
            topic_id: t.topicId,
            min_count: t.min,
            max_count: t.max,
            eligible: mine.length,
            distinct_concepts:
              concepts.size + mine.filter((c) => !c.conceptKey).length,
          };
        }),
      })),
      shortfalls,
    };
  }

  private async candidates(
    examId: string,
    language: string,
    filter: Parameters<typeof examEligible>[1]['lawRegimeFilter'],
    sections: SectionSpec[],
  ): Promise<MockCandidate[]> {
    const topicIds = [
      ...new Set(sections.flatMap((s) => s.topics.map((t) => t.topicId))),
    ];
    if (topicIds.length === 0) return [];
    const rows = await examPool(this.db, {
      questionId: questions.id,
      versionId: questionVersions.id,
      topicId: questionVersions.topicId,
      conceptKey: questionVersions.conceptKey,
      lockOptionOrder: questionVersions.lockOptionOrder,
      options: questionVersions.options,
    }).where(
      and(
        examEligible(examId, {
          language,
          now: new Date(),
          lawRegimeFilter: filter,
        }),
        inArray(questionVersions.topicId, topicIds),
      ),
    );
    return rows.map((r) => {
      const x = r as unknown as {
        questionId: string;
        versionId: string;
        topicId: string;
        conceptKey: string | null;
        lockOptionOrder: boolean;
        options: { id: string }[];
      };
      return {
        questionId: x.questionId,
        versionId: x.versionId,
        topicId: x.topicId,
        conceptKey: x.conceptKey,
        lockOptionOrder: x.lockOptionOrder,
        optionIds: x.options.map((o) => o.id),
      };
    });
  }
}

function specsOf(bp: {
  sections: {
    code: string;
    position: number;
    question_count: number;
    topics: {
      topic_id: string;
      min_count: number;
      max_count: number | null;
      weight: number;
    }[];
  }[];
}): SectionSpec[] {
  return bp.sections.map((s) => ({
    code: s.code,
    position: s.position,
    questionCount: s.question_count,
    topics: s.topics.map((t) => ({
      topicId: t.topic_id,
      min: t.min_count,
      max: t.max_count,
      weight: t.weight,
    })),
  }));
}
