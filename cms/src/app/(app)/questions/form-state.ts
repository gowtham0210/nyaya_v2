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

export const OPTION_IDS = ['a', 'b', 'c', 'd', 'e', 'f'];
