CREATE TYPE "public"."quiz_feedback_mode" AS ENUM('immediate', 'end');--> statement-breakpoint
CREATE TYPE "public"."quiz_session_status" AS ENUM('in_progress', 'submitted');--> statement-breakpoint
CREATE TABLE "quiz_session_questions" (
	"session_id" uuid NOT NULL,
	"position" smallint NOT NULL,
	"question_version_id" uuid NOT NULL,
	"option_order" text[] NOT NULL,
	"selected_option_ids" text[],
	"answered_at" timestamp with time zone,
	"is_correct" boolean,
	CONSTRAINT "quiz_session_questions_session_id_position_pk" PRIMARY KEY("session_id","position")
);
--> statement-breakpoint
CREATE TABLE "quiz_sessions" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"topic_id" uuid NOT NULL,
	"language" text NOT NULL,
	"difficulty" smallint,
	"feedback_mode" "quiz_feedback_mode" NOT NULL,
	"status" "quiz_session_status" DEFAULT 'in_progress' NOT NULL,
	"scoring_version" text NOT NULL,
	"question_count" integer NOT NULL,
	"started_at" timestamp with time zone NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"submitted_at" timestamp with time zone,
	"score" integer,
	"correct_count" integer,
	"answered_count" integer
);
--> statement-breakpoint
ALTER TABLE "quiz_session_questions" ADD CONSTRAINT "quiz_session_questions_session_id_quiz_sessions_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."quiz_sessions"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "quiz_session_questions" ADD CONSTRAINT "quiz_session_questions_question_version_id_question_versions_id_fk" FOREIGN KEY ("question_version_id") REFERENCES "public"."question_versions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "quiz_sessions" ADD CONSTRAINT "quiz_sessions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "quiz_sessions" ADD CONSTRAINT "quiz_sessions_topic_id_topics_id_fk" FOREIGN KEY ("topic_id") REFERENCES "public"."topics"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "quiz_session_questions_version_idx" ON "quiz_session_questions" USING btree ("session_id","question_version_id");--> statement-breakpoint
CREATE INDEX "quiz_sessions_user_idx" ON "quiz_sessions" USING btree ("user_id","id");