ALTER TABLE "exam_attempts" DROP CONSTRAINT "exam_attempts_deadline_check";--> statement-breakpoint
ALTER TABLE "exam_papers" ADD COLUMN "practice_timer_seconds" integer;--> statement-breakpoint
ALTER TABLE "exam_attempts" ADD CONSTRAINT "exam_attempts_deadline_check" CHECK ("exam_attempts"."mode" <> 'timed' or "exam_attempts"."deadline_at" is not null);