/** What a question form edits; every value is a string so inputs stay controlled. */
export interface QuestionInput {
  topic_id: string;
  difficulty: string;
  stem: string;
  options: { id: string; text: string }[];
  correct: string;
  explanation: string;
  source_title: string;
  source_url: string;
  citation: string;
  provision_reference: string;
  valid_from: string;
  valid_to: string;
}

export interface ActionState {
  ok?: boolean;
  message?: string;
  error?: string;
  /** Problems keyed by form field (options, stem, source_title, …). */
  fieldErrors?: Record<string, string[]>;
  /** Problems that do not belong to one field. */
  otherErrors?: string[];
}

/** What a bulk step reports back to the question list. */
export interface BulkState {
  error?: string;
  succeeded?: number;
  /** Questions the step could not be run on, with the API's reasons. */
  failures?: { questionId: string; message: string; reasons: string[] }[];
}

export const OPTION_IDS = ['a', 'b', 'c', 'd', 'e', 'f'];
