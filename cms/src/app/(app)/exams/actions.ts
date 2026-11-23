'use server';

import { refresh } from 'next/cache';
import { redirect } from 'next/navigation';
import { api, asApiError, type ApiError } from '@/lib/api';
import { SESSION_ENDED_URL } from '@/lib/session-cookies';

/*
 * Exam configuration as the signed-in user. The API decides who may do what
 * (admins everything; publishers may publish a paper or blueprint someone else
 * prepared) and checks the rules; this only sends the request and shows the
 * answer. Every change is in the API's audit log under the user's id.
 */

export interface ExamActionState {
  ok?: boolean;
  message?: string;
  error?: string;
}

function failed(err: unknown, status: number): ExamActionState {
  if (status === 401) redirect(SESSION_ENDED_URL);
  const e: ApiError = asApiError(err, status);
  const reasons = (e.details ?? []).map((d) => (d.field ? `${d.field}: ${d.reason}` : d.reason)).join('; ');
  return { error: reasons ? `${e.message}: ${reasons}` : e.message };
}

const text = (form: FormData, k: string) => {
  const v = form.get(k);
  return typeof v === 'string' ? v.trim() : '';
};
const num = (form: FormData, k: string) => {
  const v = text(form, k);
  return v === '' ? undefined : Number(v);
};
const done = (message: string): ExamActionState => {
  refresh();
  return { ok: true, message };
};

/** Parses a JSON box; a clear message instead of a crash when it is not JSON. */
function json(form: FormData, k: string): { value?: unknown; error?: string } {
  try {
    return { value: JSON.parse(text(form, k)) };
  } catch {
    return { error: 'That is not valid JSON' };
  }
}

export async function setExamActive(id: string, active: boolean): Promise<ExamActionState> {
  const { data, error, response } = await (await api()).PATCH('/v1/admin/exams/{id}', {
    params: { path: { id } },
    body: { is_active: active },
  });
  return data ? done(active ? 'Exam switched on' : 'Exam switched off') : failed(error, response.status);
}

export async function createPaper(_: ExamActionState, form: FormData): Promise<ExamActionState> {
  const { data, error, response } = await (await api()).POST('/v1/admin/exam-papers', {
    body: {
      exam_id: text(form, 'exam_id'),
      code: text(form, 'code'),
      title: text(form, 'title'),
      edition: text(form, 'edition') || undefined,
      year: num(form, 'year'),
      set_label: text(form, 'set_label') || undefined,
      total_questions: num(form, 'total_questions') ?? 0,
      duration_seconds: num(form, 'duration_seconds'),
      practice_timer_seconds: num(form, 'practice_timer_seconds') as never,
      source_note: text(form, 'source_note') || undefined,
    },
  });
  if (!data) return failed(error, response.status);
  redirect(`/exams/papers/${data.id}`);
}

/** The optional practice clock (not the official exam time). Empty removes it. */
export async function setPracticeTimer(id: string, _: ExamActionState, form: FormData): Promise<ExamActionState> {
  const seconds = num(form, 'practice_timer_seconds');
  const { data, error, response } = await (await api()).PATCH('/v1/admin/exam-papers/{id}', {
    params: { path: { id } },
    body: { practice_timer_seconds: (seconds ?? null) as never },
  });
  return data ? done(seconds ? 'Practice timer saved' : 'Practice timer removed') : failed(error, response.status);
}

export async function savePositions(id: string, _: ExamActionState, form: FormData): Promise<ExamActionState> {
  const parsed = json(form, 'positions');
  if (parsed.error) return { error: parsed.error };
  const { data, error, response } = await (await api()).PUT('/v1/admin/exam-papers/{id}/positions', {
    params: { path: { id } },
    body: { positions: parsed.value as never },
  });
  return data ? done('Positions saved') : failed(error, response.status);
}

export async function publishPaper(id: string): Promise<ExamActionState> {
  const { data, error, response } = await (await api()).POST('/v1/admin/exam-papers/{id}/publish', { params: { path: { id } } });
  return data ? done('Paper published and frozen') : failed(error, response.status);
}

export async function retirePaper(id: string): Promise<ExamActionState> {
  const { data, error, response } = await (await api()).POST('/v1/admin/exam-papers/{id}/retire', { params: { path: { id } } });
  return data ? done('Paper retired') : failed(error, response.status);
}

export async function revisePaper(id: string): Promise<ExamActionState> {
  const { data, error, response } = await (await api()).POST('/v1/admin/exam-papers/{id}/revise', { params: { path: { id } } });
  return data ? done('Draft revision created. Find it in the Papers list, check it, then publish it.') : failed(error, response.status);
}

export async function createBlueprint(_: ExamActionState, form: FormData): Promise<ExamActionState> {
  const { data, error, response } = await (await api()).POST('/v1/admin/exam-blueprints', {
    body: {
      exam_id: text(form, 'exam_id'),
      code: text(form, 'code'),
      duration_seconds: num(form, 'duration_seconds') ?? 0,
      total_questions: num(form, 'total_questions') ?? 0,
      marks_correct: num(form, 'marks_correct') ?? 0,
      negative_marks: num(form, 'negative_marks'),
      marks_unanswered: num(form, 'marks_unanswered'),
      pass_percent_general: num(form, 'pass_percent_general') as never,
      pass_percent_reserved: num(form, 'pass_percent_reserved') as never,
      law_regime_filter: (text(form, 'law_regime_filter') || undefined) as never,
      // Official-confirmed is set on the blueprint's own page, once the source is named.
      config_status: 'unverified',
    },
  });
  if (!data) return failed(error, response.status);
  redirect(`/exams/blueprints/${data.id}`);
}

export async function saveSections(id: string, _: ExamActionState, form: FormData): Promise<ExamActionState> {
  const parsed = json(form, 'sections');
  if (parsed.error) return { error: parsed.error };
  const { data, error, response } = await (await api()).PUT('/v1/admin/exam-blueprints/{id}/sections', {
    params: { path: { id } },
    body: { sections: parsed.value as never },
  });
  return data ? done('Sections saved') : failed(error, response.status);
}

export async function saveBlueprintSource(id: string, _: ExamActionState, form: FormData): Promise<ExamActionState> {
  const { data, error, response } = await (await api()).PATCH('/v1/admin/exam-blueprints/{id}', {
    params: { path: { id } },
    body: {
      config_status: text(form, 'config_status') as never,
      config_source: (text(form, 'config_source') || null) as never,
      config_checked_on: (text(form, 'config_checked_on') || null) as never,
    },
  });
  return data ? done('Saved') : failed(error, response.status);
}

type BlueprintStep = 'publish' | 'retire' | 'make-current' | 'clear-current';
const STEP_PATH = {
  publish: '/v1/admin/exam-blueprints/{id}/publish',
  retire: '/v1/admin/exam-blueprints/{id}/retire',
  'make-current': '/v1/admin/exam-blueprints/{id}/make-current',
  'clear-current': '/v1/admin/exam-blueprints/{id}/clear-current',
} as const;
const STEP_DONE: Record<BlueprintStep, string> = {
  publish: 'Blueprint published',
  retire: 'Blueprint retired',
  'make-current': 'Blueprint is now the current one',
  'clear-current': 'Blueprint is no longer current',
};

export async function blueprintStep(id: string, step: BlueprintStep): Promise<ExamActionState> {
  // Server actions take any argument a caller sends; only these become API paths.
  if (!(step in STEP_PATH)) return { error: 'Unknown step' };
  const { data, error, response } = await (await api()).POST(STEP_PATH[step], { params: { path: { id } } });
  return data ? done(STEP_DONE[step]) : failed(error, response.status);
}

/** Records where content came from (attribution only). */
export async function createContentSource(_: ExamActionState, form: FormData): Promise<ExamActionState> {
  const { data, error, response } = await (await api()).POST('/v1/admin/content-sources', {
    body: {
      kind: text(form, 'kind') as never,
      title: text(form, 'title'),
      // The generated types describe these nullable strings loosely.
      publisher: (text(form, 'publisher') || undefined) as never,
      url: (text(form, 'url') || undefined) as never,
    },
  });
  return data ? done('Content source added') : failed(error, response.status);
}
