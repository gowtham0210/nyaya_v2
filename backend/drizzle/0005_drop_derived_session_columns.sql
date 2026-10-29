ALTER TABLE "quiz_sessions" DROP CONSTRAINT "quiz_sessions_topic_id_topics_id_fk";
--> statement-breakpoint
ALTER TABLE "quiz_sessions" DROP COLUMN "topic_id";--> statement-breakpoint
ALTER TABLE "quiz_sessions" DROP COLUMN "topic_ids";--> statement-breakpoint
ALTER TABLE "quiz_sessions" DROP COLUMN "difficulty";--> statement-breakpoint
ALTER TABLE "quiz_sessions" DROP COLUMN "daily";--> statement-breakpoint
ALTER TABLE "quiz_sessions" DROP COLUMN "feedback_mode";--> statement-breakpoint
ALTER TABLE "quiz_sessions" DROP COLUMN "status";--> statement-breakpoint
ALTER TABLE "quiz_sessions" DROP COLUMN "expires_at";--> statement-breakpoint
ALTER TABLE "quiz_sessions" DROP COLUMN "score";--> statement-breakpoint
DROP TYPE "public"."quiz_feedback_mode";--> statement-breakpoint
DROP TYPE "public"."quiz_session_status";