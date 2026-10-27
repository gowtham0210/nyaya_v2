ALTER TABLE "quiz_sessions" ALTER COLUMN "topic_id" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "quiz_sessions" ADD COLUMN "topic_ids" uuid[] DEFAULT '{}'::uuid[] NOT NULL;--> statement-breakpoint
ALTER TABLE "quiz_sessions" ADD COLUMN "min_difficulty" smallint;--> statement-breakpoint
ALTER TABLE "quiz_sessions" ADD COLUMN "max_difficulty" smallint;--> statement-breakpoint
ALTER TABLE "quiz_sessions" ADD COLUMN "daily" date;--> statement-breakpoint
UPDATE "quiz_sessions" SET "topic_ids" = ARRAY["topic_id"] WHERE "topic_id" IS NOT NULL;