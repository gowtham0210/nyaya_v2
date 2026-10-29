CREATE TYPE "public"."quiz_mode" AS ENUM('case_path', 'daily_docket', 'duel', 'exam');--> statement-breakpoint
CREATE TABLE "chest_openings" (
	"user_id" uuid NOT NULL,
	"subject_id" uuid NOT NULL,
	"opened_at" timestamp with time zone NOT NULL,
	CONSTRAINT "chest_openings_user_id_subject_id_pk" PRIMARY KEY("user_id","subject_id")
);
--> statement-breakpoint
CREATE TABLE "quiz_session_topics" (
	"session_id" uuid NOT NULL,
	"topic_id" uuid NOT NULL,
	CONSTRAINT "quiz_session_topics_session_id_topic_id_pk" PRIMARY KEY("session_id","topic_id")
);
--> statement-breakpoint
ALTER TABLE "quiz_sessions" ADD COLUMN "mode" "quiz_mode";--> statement-breakpoint
-- Existing sessions: an exam reveals at the end, a daily set is the docket, a
-- single difficulty is a Case Path level, anything else a duel.
UPDATE "quiz_sessions" SET "mode" = CASE
	WHEN "feedback_mode" = 'end' THEN 'exam'::"quiz_mode"
	WHEN "daily" IS NOT NULL THEN 'daily_docket'::"quiz_mode"
	WHEN "difficulty" IS NOT NULL THEN 'case_path'::"quiz_mode"
	ELSE 'duel'::"quiz_mode"
END;--> statement-breakpoint
ALTER TABLE "quiz_sessions" ALTER COLUMN "mode" SET NOT NULL;--> statement-breakpoint
UPDATE "quiz_sessions" SET "min_difficulty" = "difficulty", "max_difficulty" = "difficulty" WHERE "difficulty" IS NOT NULL;--> statement-breakpoint
ALTER TABLE "quiz_sessions" ADD COLUMN "xp_awarded" integer;--> statement-breakpoint
-- Server progress starts fresh: earlier attempts carry no XP.
UPDATE "quiz_sessions" SET "xp_awarded" = 0 WHERE "submitted_at" IS NOT NULL;--> statement-breakpoint
ALTER TABLE "chest_openings" ADD CONSTRAINT "chest_openings_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "chest_openings" ADD CONSTRAINT "chest_openings_subject_id_subjects_id_fk" FOREIGN KEY ("subject_id") REFERENCES "public"."subjects"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "quiz_session_topics" ADD CONSTRAINT "quiz_session_topics_session_id_quiz_sessions_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."quiz_sessions"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "quiz_session_topics" ADD CONSTRAINT "quiz_session_topics_topic_id_topics_id_fk" FOREIGN KEY ("topic_id") REFERENCES "public"."topics"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
INSERT INTO "quiz_session_topics" ("session_id", "topic_id")
	SELECT DISTINCT "id", unnest("topic_ids") FROM "quiz_sessions";
