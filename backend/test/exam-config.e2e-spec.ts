import { eq } from 'drizzle-orm';
import { newId } from '../src/core/ids.js';
import { auditLog, subjects, topics } from '../src/db/schema.js';
import { ExamsService } from '../src/exams/exams.service.js';
import { startApp, type TestApp } from './helpers.js';

type Session = Awaited<ReturnType<TestApp['signInAs']>>;

describe('exam and blueprint configuration', () => {
  let t: TestApp;
  let admin: Session, editor: Session, analyst: Session, learner: Session;
  let topicA: string, topicB: string, inactiveTopic: string;

  const as = (s: Session) => ({
    get: (url: string) => t.http().get(url).auth(s.token, { type: 'bearer' }),
    post: (url: string, body: object = {}) =>
      t.http().post(url).auth(s.token, { type: 'bearer' }).send(body),
    patch: (url: string, body: object) =>
      t.http().patch(url).auth(s.token, { type: 'bearer' }).send(body),
    put: (url: string, body: object) =>
      t.http().put(url).auth(s.token, { type: 'bearer' }).send(body),
  });

  const createExam = async (slug = 'aibe') =>
    (
      await as(admin)
        .post('/v1/admin/exams', {
          slug,
          name: `${slug} exam`,
          short_name: slug.toUpperCase(),
        })
        .expect(201)
    ).body;

  const blueprintBody = (examId: string, over: object = {}) => ({
    exam_id: examId,
    code: `bp-${newId().slice(-8)}`,
    duration_seconds: 10_800,
    total_questions: 10,
    marks_correct: 1,
    ...over,
  });
  const createBlueprint = async (examId: string, over: object = {}) =>
    (
      await as(admin)
        .post('/v1/admin/exam-blueprints', blueprintBody(examId, over))
        .expect(201)
    ).body;

  const sectionsBody = (over: object = {}) => ({
    sections: [
      {
        code: 'constitution',
        name: 'Constitutional law',
        position: 1,
        question_count: 6,
        topics: [{ topic_id: topicA, min_count: 2, max_count: 6, weight: 2 }],
      },
      {
        code: 'cpc',
        name: 'CPC',
        position: 2,
        question_count: 4,
        topics: [{ topic_id: topicB }],
      },
    ],
    ...over,
  });

  /** A draft blueprint with sound sections, ready to publish. */
  const readyBlueprint = async (examId: string, over: object = {}) => {
    const bp = await createBlueprint(examId, over);
    await as(admin)
      .put(`/v1/admin/exam-blueprints/${bp.id}/sections`, sectionsBody())
      .expect(200);
    return bp;
  };
  const publish = (id: string) =>
    as(admin).post(`/v1/admin/exam-blueprints/${id}/publish`);

  const officialEvidence = {
    config_status: 'official_confirmed',
    config_source: 'BCI AIBE XXI question booklet instructions',
    config_checked_on: '2026-11-18',
  };

  beforeAll(async () => {
    t = await startApp();
    [admin, editor, analyst, learner] = await Promise.all([
      t.signInAs('admin'),
      t.signInAs('content_editor'),
      t.signInAs('analyst'),
      t.signInAs('learner'),
    ]);
    topicA = t.topicId;
    topicB = newId();
    inactiveTopic = newId();
    const subjectId = newId();
    await t.db
      .insert(subjects)
      .values({ id: subjectId, slug: 'procedure', name: 'Procedure' });
    await t.db.insert(topics).values([
      { id: topicB, subjectId, slug: 'cpc-basics', name: 'CPC' },
      {
        id: inactiveTopic,
        subjectId,
        slug: 'idle',
        name: 'Idle',
        isActive: false,
      },
    ]);
  });
  afterAll(() => t.close());

  describe('exams', () => {
    it('are created by admins, from the three planned exams, switched off', async () => {
      await t
        .http()
        .post('/v1/admin/exams')
        .send({ slug: 'aibe', name: 'x', short_name: 'x' })
        .expect(401);
      await as(editor)
        .post('/v1/admin/exams', { slug: 'aibe', name: 'x', short_name: 'x' })
        .expect(403);
      await as(admin)
        .post('/v1/admin/exams', { slug: 'upsc', name: 'x', short_name: 'x' })
        .expect(400);
      const aibe = await createExam('aibe');
      expect(aibe).toMatchObject({
        slug: 'aibe',
        is_active: false,
        instructions: '',
        sort_order: 0,
      });
      await createExam('clat');
      await createExam('ailet');
      const dup = await as(admin)
        .post('/v1/admin/exams', { slug: 'aibe', name: 'x', short_name: 'x' })
        .expect(409);
      expect(dup.body.code).toBe('exam_exists');
      const list = await as(analyst).get('/v1/admin/exams').expect(200);
      expect(list.body.items.map((e: { slug: string }) => e.slug)).toEqual(
        expect.arrayContaining(['aibe', 'clat', 'ailet']),
      );
      await as(learner).get('/v1/admin/exams').expect(403);
    });

    it('cannot be switched on without a published blueprint', async () => {
      const exam = (
        await as(analyst).get('/v1/admin/exams').expect(200)
      ).body.items.find((e: { slug: string }) => e.slug === 'clat');
      const res = await as(admin)
        .patch(`/v1/admin/exams/${exam.id}`, { is_active: true })
        .expect(409);
      expect(res.body.code).toBe('no_published_blueprint');
      // A draft is not enough.
      await readyBlueprint(exam.id);
      await as(admin)
        .patch(`/v1/admin/exams/${exam.id}`, { is_active: true })
        .expect(409);
      // Other details can change meanwhile, without switching it on.
      const renamed = await as(admin)
        .patch(`/v1/admin/exams/${exam.id}`, {
          name: 'CLAT (UG)',
          instructions: 'Read carefully',
          sort_order: 5,
        })
        .expect(200);
      expect(renamed.body).toMatchObject({
        name: 'CLAT (UG)',
        is_active: false,
        sort_order: 5,
      });
    });
  });

  describe('blueprints', () => {
    let examId: string;
    beforeAll(async () => {
      examId = (
        await as(analyst).get('/v1/admin/exams').expect(200)
      ).body.items.find((e: { slug: string }) => e.slug === 'aibe').id;
    });

    it('start as an unverified draft with the marking rules given', async () => {
      const bp = await createBlueprint(examId, {
        negative_marks: 0.25,
        marks_unanswered: 0,
        pass_percent_general: 45,
        pass_percent_reserved: 40,
      });
      expect(bp).toMatchObject({
        status: 'draft',
        version: 1,
        config_status: 'unverified',
        config_source: null,
        law_regime_filter: 'any',
        section_navigation: 'free',
        duration_seconds: 10_800,
        total_questions: 10,
        marks_correct: 1,
        negative_marks: 0.25,
        marks_unanswered: 0,
        pass_percent_general: 45,
        pass_percent_reserved: 40,
        timed_allowed: false,
        sections: [],
      });
      expect(bp.timed_blocked_reason).toMatch(/not published/);
      // A new blueprint is never chosen as "current" automatically.
      expect(bp.is_current).toBe(false);
    });

    it('are written by admins only; staff may read', async () => {
      const body = blueprintBody(examId);
      await t.http().post('/v1/admin/exam-blueprints').send(body).expect(401);
      await as(editor).post('/v1/admin/exam-blueprints', body).expect(403);
      await as(analyst).post('/v1/admin/exam-blueprints', body).expect(403);
      const bp = await createBlueprint(examId);
      await as(analyst).get(`/v1/admin/exam-blueprints/${bp.id}`).expect(200);
      await as(learner).get(`/v1/admin/exam-blueprints/${bp.id}`).expect(403);
      await as(editor)
        .patch(`/v1/admin/exam-blueprints/${bp.id}`, { duration_seconds: 600 })
        .expect(403);
      await as(editor)
        .post(`/v1/admin/exam-blueprints/${bp.id}/publish`)
        .expect(403);
    });

    it('reject invalid numbers and invalid choices, including an invalid law-regime rule', async () => {
      const bad = (over: object) =>
        as(admin)
          .post('/v1/admin/exam-blueprints', blueprintBody(examId, over))
          .expect(400);
      await bad({ law_regime_filter: 'bogus' });
      await bad({ law_regime_filter: 'old_only' });
      await bad({ config_status: 'confirmed' });
      await bad({ section_navigation: 'sideways' });
      await bad({ negative_marks: -0.25 });
      await bad({ marks_correct: 1000 });
      await bad({ marks_correct: 1.234 });
      await bad({ duration_seconds: 10 });
      await bad({ total_questions: 0 });
      await bad({ pass_percent_general: 101 });
      await bad({ code: 'Bad Code' });
      await bad({ config_checked_on: '18-11-2026' });
      // A blueprint cannot start out published.
      await bad({ status: 'published' });
      await as(admin)
        .post('/v1/admin/exam-blueprints', blueprintBody(newId()))
        .expect(404);
    });

    it('accept each valid law-regime rule, and refuse an invalid change to a draft', async () => {
      for (const rule of ['any', 'exclude_old', 'prefer_new', 'include_all']) {
        const bp = await createBlueprint(examId, { law_regime_filter: rule });
        expect(bp.law_regime_filter).toBe(rule);
      }
      const bp = await createBlueprint(examId);
      await as(admin)
        .patch(`/v1/admin/exam-blueprints/${bp.id}`, {
          law_regime_filter: 'nope',
        })
        .expect(400);
      const changed = await as(admin)
        .patch(`/v1/admin/exam-blueprints/${bp.id}`, {
          law_regime_filter: 'exclude_old',
        })
        .expect(200);
      expect(changed.body.law_regime_filter).toBe('exclude_old');
    });

    it('need evidence to be called official-confirmed', async () => {
      const res = await as(admin)
        .post(
          '/v1/admin/exam-blueprints',
          blueprintBody(examId, { config_status: 'official_confirmed' }),
        )
        .expect(422);
      expect(res.body.details.map((d: { field: string }) => d.field)).toEqual([
        'config_source',
        'config_checked_on',
      ]);
      const ok = await createBlueprint(examId, officialEvidence);
      expect(ok.config_status).toBe('official_confirmed');
      // Dropping the evidence from a draft is refused too.
      const draft = await createBlueprint(examId);
      await as(admin)
        .patch(`/v1/admin/exam-blueprints/${draft.id}`, {
          config_status: 'official_confirmed',
        })
        .expect(422);
      await as(admin)
        .patch(`/v1/admin/exam-blueprints/${draft.id}`, officialEvidence)
        .expect(200);
    });

    it('refuse a second blueprint with the same code', async () => {
      const first = await createBlueprint(examId, { code: 'same-code' });
      expect(first.version).toBe(1);
      const res = await as(admin)
        .post(
          '/v1/admin/exam-blueprints',
          blueprintBody(examId, { code: 'same-code' }),
        )
        .expect(409);
      expect(res.body.code).toBe('blueprint_exists');
    });

    it('hold sections with topic quotas, replaced as a whole', async () => {
      const bp = await createBlueprint(examId);
      const res = await as(admin)
        .put(`/v1/admin/exam-blueprints/${bp.id}/sections`, sectionsBody())
        .expect(200);
      expect(res.body.sections).toHaveLength(2);
      expect(res.body.sections[0]).toMatchObject({
        code: 'constitution',
        position: 1,
        question_count: 6,
        topics: [{ topic_id: topicA, min_count: 2, max_count: 6, weight: 2 }],
      });
      expect(res.body.sections[1].topics).toEqual([
        { topic_id: topicB, min_count: 0, max_count: null, weight: 1 },
      ]);
      const again = await as(admin)
        .put(`/v1/admin/exam-blueprints/${bp.id}/sections`, {
          sections: [
            {
              code: 'only',
              name: 'Only',
              position: 1,
              question_count: 10,
              topics: [{ topic_id: topicA }],
            },
          ],
        })
        .expect(200);
      expect(again.body.sections.map((s: { code: string }) => s.code)).toEqual([
        'only',
      ]);
    });

    it('refuse unknown topics and repeats when sections are saved', async () => {
      const bp = await createBlueprint(examId);
      const put = (sections: object[]) =>
        as(admin).put(`/v1/admin/exam-blueprints/${bp.id}/sections`, {
          sections,
        });
      const section = (over: object = {}) => ({
        code: 'a',
        name: 'A',
        position: 1,
        question_count: 5,
        topics: [{ topic_id: topicA }],
        ...over,
      });
      await put([section({ topics: [{ topic_id: newId() }] })]).expect(422);
      await put([section(), section({ position: 2 })]).expect(422);
      await put([section(), section({ code: 'b' })]).expect(422);
      await put([
        section({ topics: [{ topic_id: topicA }, { topic_id: topicA }] }),
      ]).expect(422);
      await put([section({ question_count: 0 })]).expect(400);
      await put([section({ topics: [{ topic_id: 'nope' }] })]).expect(400);
    });

    describe('publishing', () => {
      const problems = async (id: string) => {
        const res = await publish(id).expect(422);
        expect(res.body.code).toBe('blueprint_incomplete');
        return res.body.details
          .map((d: { reason: string }) => d.reason)
          .join(' | ');
      };

      it('needs sections that add up, with quotas that can be met, in active topics', async () => {
        const bp = await createBlueprint(examId);
        expect(await problems(bp.id)).toMatch(/at least one section/);

        const put = (sections: object[]) =>
          as(admin)
            .put(`/v1/admin/exam-blueprints/${bp.id}/sections`, { sections })
            .expect(200);
        const section = (over: object = {}) => ({
          code: 'a',
          name: 'A',
          position: 1,
          question_count: 10,
          topics: [{ topic_id: topicA }],
          ...over,
        });
        await put([section({ question_count: 8 })]);
        expect(await problems(bp.id)).toMatch(
          /add up to 8 questions but the blueprint has 10/,
        );
        await put([section({ topics: [{ topic_id: topicA, min_count: 11 }] })]);
        expect(await problems(bp.id)).toMatch(/minimums add up to 11/);
        await put([section({ topics: [{ topic_id: topicA, max_count: 4 }] })]);
        expect(await problems(bp.id)).toMatch(/maximums add up to 4/);
        await put([section({ topics: [{ topic_id: inactiveTopic }] })]);
        expect(await problems(bp.id)).toMatch(/inactive/);
        await put([section({ duration_seconds: 86_400 })]);
        expect(await problems(bp.id)).toMatch(/longer than the whole exam/);
        const [{ status }] = [
          (
            await as(admin)
              .get(`/v1/admin/exam-blueprints/${bp.id}`)
              .expect(200)
          ).body,
        ];
        expect(status).toBe('draft');
      });

      it('publishes a sound draft, audits it, and makes it read-only', async () => {
        const bp = await readyBlueprint(examId);
        const published = await publish(bp.id).expect(200);
        expect(published.body).toMatchObject({
          status: 'published',
          timed_allowed: false,
        });
        const entries = await t.db
          .select()
          .from(auditLog)
          .where(eq(auditLog.entityId, bp.id));
        expect(entries.map((e) => e.action)).toEqual(
          expect.arrayContaining([
            'exam_blueprint.created',
            'exam_blueprint.sections_replaced',
            'exam_blueprint.published',
          ]),
        );
        // Nothing may change any more.
        const locked = await as(admin)
          .patch(`/v1/admin/exam-blueprints/${bp.id}`, {
            duration_seconds: 600,
          })
          .expect(409);
        expect(locked.body.code).toBe('blueprint_not_draft');
        await as(admin)
          .put(`/v1/admin/exam-blueprints/${bp.id}/sections`, sectionsBody())
          .expect(409);
        await publish(bp.id).expect(409);
      });
    });

    describe('timed mocks', () => {
      const service = () => t.app.get(ExamsService);
      const verdict = async (id: string) => {
        try {
          await service().assertTimedAllowed(id);
          return 'allowed';
        } catch (e) {
          return (
            e as {
              getResponse: () => {
                code: string;
                details: { reason: string }[];
              };
            }
          ).getResponse().details[0].reason;
        }
      };

      it('are refused for a draft, and for a published blueprint that is unverified or inferred', async () => {
        const draftOfficial = await readyBlueprint(examId, officialEvidence);
        expect(await verdict(draftOfficial.id)).toBe('blueprint_not_published');

        const unverified = await readyBlueprint(examId);
        await publish(unverified.id).expect(200);
        expect(await verdict(unverified.id)).toBe(
          'config_not_official_confirmed',
        );

        const inferred = await readyBlueprint(examId, {
          config_status: 'inferred',
          config_source: 'Third-party summary',
        });
        const res = await publish(inferred.id).expect(200);
        expect(res.body).toMatchObject({
          status: 'published',
          timed_allowed: false,
        });
        expect(res.body.timed_blocked_reason).toMatch(/not official-confirmed/);
        expect(await verdict(inferred.id)).toBe(
          'config_not_official_confirmed',
        );
      });

      it('are allowed only for a published, official-confirmed blueprint', async () => {
        const bp = await readyBlueprint(examId, officialEvidence);
        const published = await publish(bp.id).expect(200);
        expect(published.body).toMatchObject({
          timed_allowed: true,
          timed_blocked_reason: null,
        });
        expect(await verdict(bp.id)).toBe('allowed');
      });

      it('are refused for an unknown blueprint', async () => {
        await expect(
          service().assertTimedAllowed(newId()),
        ).rejects.toMatchObject({ status: 404 });
      });
    });

    describe('versions and retiring', () => {
      it('copy a published blueprint into a new draft, leaving the original alone', async () => {
        const bp = await readyBlueprint(examId, officialEvidence);
        await publish(bp.id).expect(200);
        const next = (
          await as(admin)
            .post(`/v1/admin/exam-blueprints/${bp.id}/new-version`)
            .expect(201)
        ).body;
        expect(next).toMatchObject({
          code: bp.code,
          version: 2,
          status: 'draft',
          config_status: 'official_confirmed',
        });
        expect(next.id).not.toBe(bp.id);
        expect(next.sections.map((s: { code: string }) => s.code)).toEqual([
          'constitution',
          'cpc',
        ]);
        await as(admin)
          .patch(`/v1/admin/exam-blueprints/${next.id}`, {
            duration_seconds: 7200,
          })
          .expect(200);
        const original = (
          await as(admin).get(`/v1/admin/exam-blueprints/${bp.id}`).expect(200)
        ).body;
        expect(original).toMatchObject({
          status: 'published',
          duration_seconds: 10_800,
        });
        // A draft is edited directly, not versioned.
        await as(admin)
          .post(`/v1/admin/exam-blueprints/${next.id}/new-version`)
          .expect(409);
        // Publishing the new version selects nothing: both stay as they are.
        await publish(next.id).expect(200);
        expect(
          (
            await as(admin)
              .get(`/v1/admin/exam-blueprints/${bp.id}`)
              .expect(200)
          ).body.status,
        ).toBe('published');
      });

      it('retire a published blueprint only, and not the last one of an exam that is on', async () => {
        const ailet = (
          await as(analyst).get('/v1/admin/exams').expect(200)
        ).body.items.find((e: { slug: string }) => e.slug === 'ailet');
        const only = await readyBlueprint(ailet.id, officialEvidence);
        await as(admin)
          .post(`/v1/admin/exam-blueprints/${only.id}/retire`)
          .expect(409);
        await publish(only.id).expect(200);
        await as(admin)
          .patch(`/v1/admin/exams/${ailet.id}`, { is_active: true })
          .expect(200);
        const blocked = await as(admin)
          .post(`/v1/admin/exam-blueprints/${only.id}/retire`)
          .expect(409);
        expect(blocked.body.code).toBe('last_published_blueprint');
        const second = await readyBlueprint(ailet.id, officialEvidence);
        await publish(second.id).expect(200);
        const retired = await as(admin)
          .post(`/v1/admin/exam-blueprints/${only.id}/retire`)
          .expect(200);
        expect(retired.body.status).toBe('retired');
        const detail = await as(analyst)
          .get(`/v1/admin/exams/${ailet.id}`)
          .expect(200);
        expect(detail.body.is_active).toBe(true);
        expect(
          detail.body.blueprints
            .map((b: { status: string }) => b.status)
            .sort(),
        ).toEqual(['published', 'retired']);
        // Switching an exam on or off is audited.
        const entries = await t.db
          .select()
          .from(auditLog)
          .where(eq(auditLog.entityId, ailet.id));
        const switched = entries.find(
          (e) => e.action === 'exam.updated' && e.data?.is_active,
        );
        expect(switched?.data?.is_active).toEqual({ from: false, to: true });
      });
    });
  });

  describe('the current blueprint', () => {
    let aibeId: string;
    let clatId: string;
    const service = () => t.app.get(ExamsService);
    const examList = async () =>
      (await as(analyst).get('/v1/admin/exams').expect(200)).body.items as {
        id: string;
        slug: string;
      }[];
    const makeCurrent = (id: string) =>
      as(admin).post(`/v1/admin/exam-blueprints/${id}/make-current`);
    const clearCurrent = (id: string) =>
      as(admin).post(`/v1/admin/exam-blueprints/${id}/clear-current`);
    const published = async (examId: string, over: object = {}) => {
      const bp = await readyBlueprint(examId, over);
      await publish(bp.id).expect(200);
      return bp;
    };
    const currentOf = async (examId: string) => {
      const detail = (
        await as(analyst).get(`/v1/admin/exams/${examId}`).expect(200)
      ).body;
      return {
        id: detail.current_blueprint_id as string | null,
        marked: detail.blueprints
          .filter((b: { is_current: boolean }) => b.is_current)
          .map((b: { id: string }) => b.id) as string[],
      };
    };

    beforeAll(async () => {
      const all = await examList();
      aibeId = all.find((e) => e.slug === 'aibe')!.id;
      clatId = all.find((e) => e.slug === 'clat')!.id;
    });

    it('is refused for a draft: only a published blueprint can be current', async () => {
      const draft = await readyBlueprint(aibeId);
      const res = await makeCurrent(draft.id).expect(409);
      expect(res.body.code).toBe('blueprint_not_published');
      expect((await currentOf(aibeId)).marked).not.toContain(draft.id);
    });

    it('is set on purpose, and publishing alone never sets it', async () => {
      const bp = await published(aibeId);
      expect((await currentOf(aibeId)).marked).not.toContain(bp.id);
      const res = await makeCurrent(bp.id).expect(200);
      expect(res.body).toMatchObject({ id: bp.id, is_current: true });
      expect(await currentOf(aibeId)).toEqual({ id: bp.id, marked: [bp.id] });
    });

    it('is exactly one per exam: making another current moves the mark', async () => {
      const first = await published(aibeId);
      const second = await published(aibeId);
      await makeCurrent(first.id).expect(200);
      await makeCurrent(second.id).expect(200);
      expect(await currentOf(aibeId)).toEqual({
        id: second.id,
        marked: [second.id],
      });
      const again = await makeCurrent(second.id).expect(409);
      expect(again.body.code).toBe('already_current');
      // The audit entry names the blueprint it replaced.
      const entries = await t.db
        .select()
        .from(auditLog)
        .where(eq(auditLog.entityId, second.id));
      const made = entries.find(
        (e) => e.action === 'exam_blueprint.made_current',
      );
      expect(made?.actorId).toBe(admin.id);
      expect(made?.data).toMatchObject({
        exam_id: aibeId,
        previous_blueprint_id: first.id,
      });
    });

    it('is not shared between exams', async () => {
      const aibe = await published(aibeId);
      await makeCurrent(aibe.id).expect(200);
      expect((await currentOf(clatId)).marked).toEqual([]);
      const clat = await published(clatId);
      await makeCurrent(clat.id).expect(200);
      expect((await currentOf(aibeId)).id).toBe(aibe.id);
      expect((await currentOf(clatId)).id).toBe(clat.id);
      await clearCurrent(clat.id).expect(200);
      expect((await currentOf(aibeId)).id).toBe(aibe.id);
    });

    it('does not pass to a copy, and a new published version does not take it over', async () => {
      const bp = await published(aibeId, officialEvidence);
      await makeCurrent(bp.id).expect(200);
      const copy = (
        await as(admin)
          .post(`/v1/admin/exam-blueprints/${bp.id}/new-version`)
          .expect(201)
      ).body;
      expect(copy.is_current).toBe(false);
      await publish(copy.id).expect(200);
      expect(await currentOf(aibeId)).toEqual({ id: bp.id, marked: [bp.id] });
    });

    it('is cleared on purpose, and clearing is audited', async () => {
      const bp = await published(aibeId);
      const notCurrent = await clearCurrent(bp.id).expect(409);
      expect(notCurrent.body.code).toBe('not_current');
      await makeCurrent(bp.id).expect(200);
      const res = await clearCurrent(bp.id).expect(200);
      expect(res.body.is_current).toBe(false);
      expect((await currentOf(aibeId)).marked).toEqual([]);
      const entries = await t.db
        .select()
        .from(auditLog)
        .where(eq(auditLog.entityId, bp.id));
      expect(entries.map((e) => e.action)).toEqual(
        expect.arrayContaining([
          'exam_blueprint.made_current',
          'exam_blueprint.current_cleared',
        ]),
      );
    });

    it('blocks retiring a current blueprint until it is cleared', async () => {
      const bp = await published(aibeId);
      await makeCurrent(bp.id).expect(200);
      const blocked = await as(admin)
        .post(`/v1/admin/exam-blueprints/${bp.id}/retire`)
        .expect(409);
      expect(blocked.body.code).toBe('blueprint_is_current');
      await clearCurrent(bp.id).expect(200);
      await as(admin)
        .post(`/v1/admin/exam-blueprints/${bp.id}/retire`)
        .expect(200);
    });

    it('is written by admins only', async () => {
      const bp = await published(aibeId);
      await t
        .http()
        .post(`/v1/admin/exam-blueprints/${bp.id}/make-current`)
        .expect(401);
      for (const s of [editor, analyst, learner]) {
        await as(s)
          .post(`/v1/admin/exam-blueprints/${bp.id}/make-current`)
          .expect(403);
        await as(s)
          .post(`/v1/admin/exam-blueprints/${bp.id}/clear-current`)
          .expect(403);
      }
      await makeCurrent(newId()).expect(404);
    });

    it('is what a random mock must use, and a mock is refused clearly when there is none', async () => {
      const ailet = (await examList()).find((e) => e.slug === 'ailet')!.id;
      const refused = {
        status: 409,
        response: { code: 'no_current_blueprint' },
      };
      await expect(
        service().requireCurrentBlueprint(ailet),
      ).rejects.toMatchObject({
        ...refused,
        response: {
          code: 'no_current_blueprint',
          message: expect.stringMatching(/ailet exam has no current blueprint/),
        },
      });
      await expect(
        service().requireCurrentBlueprint(newId()),
      ).rejects.toMatchObject({ status: 404 });
      const bp = await published(ailet, officialEvidence);
      // Published is not enough.
      await expect(
        service().requireCurrentBlueprint(ailet),
      ).rejects.toMatchObject(refused);
      await makeCurrent(bp.id).expect(200);
      expect(await service().requireCurrentBlueprint(ailet)).toMatchObject({
        id: bp.id,
        is_current: true,
      });
      await clearCurrent(bp.id).expect(200);
      await expect(
        service().requireCurrentBlueprint(ailet),
      ).rejects.toMatchObject(refused);
    });
  });
});
