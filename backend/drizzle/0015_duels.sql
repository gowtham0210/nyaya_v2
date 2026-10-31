CREATE TYPE "public"."duel_outcome" AS ENUM('won', 'lost', 'draw');--> statement-breakpoint
ALTER TYPE "public"."coin_reason" ADD VALUE 'duel_win';--> statement-breakpoint
CREATE TABLE "duel_matches" (
	"session_id" uuid PRIMARY KEY NOT NULL,
	"opponent_session_id" uuid,
	"opponent_name" text NOT NULL,
	"practice" boolean NOT NULL,
	"opponent_rating" integer NOT NULL,
	"opponent_answers" jsonb NOT NULL,
	"rating_before" integer NOT NULL,
	"player_points" integer,
	"opponent_points" integer,
	"outcome" "duel_outcome",
	"rating_after" integer
);
--> statement-breakpoint
ALTER TABLE "quiz_session_questions" ADD COLUMN "elapsed_ms" integer;--> statement-breakpoint
ALTER TABLE "duel_matches" ADD CONSTRAINT "duel_matches_session_id_quiz_sessions_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."quiz_sessions"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "duel_matches" ADD CONSTRAINT "duel_matches_opponent_session_id_quiz_sessions_id_fk" FOREIGN KEY ("opponent_session_id") REFERENCES "public"."quiz_sessions"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "duel_matches_opponent_idx" ON "duel_matches" USING btree ("opponent_session_id");