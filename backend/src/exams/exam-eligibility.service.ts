import { Inject, Injectable } from '@nestjs/common';
import { and, count, eq } from 'drizzle-orm';
import { DB, type Db } from '../core/db.js';
import { indiaToday } from '../learn/scoring.js';
import {
  examQuestionTags,
  questions,
  questionVersions,
  subjects,
  topics,
  type LawRegime,
} from '../db/schema.js';
import {
  examEligible,
  examPool,
  INELIGIBLE_MESSAGES,
  lawRegimeVerdict,
  type ExamEligibilityOptions,
  type ExamIneligibleCode,
} from './exam-eligibility.js';

export interface ExamEligibilityResult {
  eligible: boolean;
  examOnly: boolean | null;
  lawRegime: LawRegime | null;
  reasons: { code: ExamIneligibleCode; message: string }[];
}

@Injectable()
export class ExamEligibilityService {
  constructor(@Inject(DB) private readonly db: Db) {}

  /** How many questions a randomised mock for [examId] could draw from. */
  async poolSize(
    examId: string,
    options: ExamEligibilityOptions,
  ): Promise<number> {
    const [row] = await examPool(this.db, { n: count() }).where(
      examEligible(examId, options),
    );
    return Number((row as unknown as { n: number }).n);
  }

  /**
   * Whether one question could be drawn for [examId], and every reason it
   * could not. It applies the same rules as the pool query (`examEligible`);
   * the tests compare the two.
   */
  async explain(
    examId: string,
    questionId: string,
    options: ExamEligibilityOptions,
  ): Promise<ExamEligibilityResult> {
    const [q] = await this.db
      .select()
      .from(questions)
      .where(eq(questions.id, questionId))
      .limit(1);
    if (!q)
      return {
        eligible: false,
        examOnly: null,
        lawRegime: null,
        reasons: [reason('question_not_found')],
      };

    const reasons: ExamEligibilityResult['reasons'] = [];
    const [tag] = await this.db
      .select({ id: examQuestionTags.questionId })
      .from(examQuestionTags)
      .where(
        and(
          eq(examQuestionTags.questionId, questionId),
          eq(examQuestionTags.examId, examId),
        ),
      )
      .limit(1);
    if (!tag) reasons.push(reason('no_exam_tag'));
    if (q.retiredAt) reasons.push(reason('retired'));

    const [v] = q.liveVersionId
      ? await this.db
          .select({
            version: questionVersions,
            topicActive: topics.isActive,
            subjectActive: subjects.isActive,
          })
          .from(questionVersions)
          .innerJoin(topics, eq(topics.id, questionVersions.topicId))
          .innerJoin(subjects, eq(subjects.id, topics.subjectId))
          .where(eq(questionVersions.id, q.liveVersionId))
          .limit(1)
      : [];
    if (!v || v.version.status !== 'published') {
      reasons.push(reason('not_published'));
      return {
        eligible: false,
        examOnly: q.examOnly,
        lawRegime: v?.version.lawRegime ?? null,
        reasons,
      };
    }

    const { version } = v;
    if (version.language !== options.language)
      reasons.push(reason('language_mismatch'));
    if (version.jurisdiction !== 'IN')
      reasons.push(reason('jurisdiction_mismatch'));
    if (!version.validFrom || version.validFrom > indiaToday(options.now))
      reasons.push(reason('not_yet_valid'));
    if (!v.topicActive || !v.subjectActive)
      reasons.push(reason('topic_inactive'));
    const regime = lawRegimeVerdict(options.lawRegimeFilter, version.lawRegime);
    if (!regime.allowed) reasons.push(reason(regime.code));

    return {
      eligible: reasons.length === 0,
      examOnly: q.examOnly,
      lawRegime: version.lawRegime,
      reasons,
    };
  }
}

const reason = (code: ExamIneligibleCode) => ({
  code,
  message: INELIGIBLE_MESSAGES[code],
});
