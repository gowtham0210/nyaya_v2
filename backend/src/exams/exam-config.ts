/**
 * The exams the app plans to offer. A slug outside this list cannot be
 * created. Adding an exam later means adding its slug here.
 */
export const EXAM_SLUGS = ['aibe', 'clat', 'ailet'] as const;
export type ExamSlug = (typeof EXAM_SLUGS)[number];
