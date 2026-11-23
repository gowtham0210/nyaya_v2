CREATE TYPE "public"."exam_attempt_kind" AS ENUM('fixed_paper', 'random_mock');--> statement-breakpoint
CREATE TYPE "public"."exam_attempt_mode" AS ENUM('practice', 'timed');--> statement-breakpoint
CREATE TYPE "public"."exam_attempt_status" AS ENUM('in_progress', 'submitted', 'expired');--> statement-breakpoint
CREATE TABLE "exam_attempt_questions" (
	"id" uuid PRIMARY KEY NOT NULL,
	"attempt_id" uuid NOT NULL,
	"position" integer NOT NULL,
	"section_code" text,
	"section_position" integer,
	"question_id" uuid,
	"question_version_id" uuid,
	"topic_id" uuid,
	"answer_status" "paper_answer_status" NOT NULL,
	"question_type" text DEFAULT 'single_select' NOT NULL,
	"option_order" jsonb,
	"original_ref" text,
	"original_label_scheme" text,
	"accepted_option_ids" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"marks_correct" numeric(5, 2),
	"selected_option_ids" jsonb,
	"answer_seq" integer DEFAULT 0 NOT NULL,
	"answered_at" timestamp with time zone,
	CONSTRAINT "exam_attempt_questions_position_check" CHECK ("exam_attempt_questions"."position" >= 1),
	CONSTRAINT "exam_attempt_questions_withdrawn_check" CHECK (("exam_attempt_questions"."answer_status" = 'withdrawn') = ("exam_attempt_questions"."question_version_id" is null)),
	CONSTRAINT "exam_attempt_questions_seq_check" CHECK ("exam_attempt_questions"."answer_seq" >= 0)
);
--> statement-breakpoint
CREATE TABLE "exam_attempts" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"exam_id" uuid NOT NULL,
	"kind" "exam_attempt_kind" NOT NULL,
	"mode" "exam_attempt_mode" NOT NULL,
	"status" "exam_attempt_status" DEFAULT 'in_progress' NOT NULL,
	"paper_id" uuid,
	"paper_revision" integer,
	"blueprint_id" uuid,
	"language" text DEFAULT 'en' NOT NULL,
	"seed" text,
	"algorithm_version" integer,
	"started_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deadline_at" timestamp with time zone,
	"duration_seconds" integer,
	"submitted_at" timestamp with time zone,
	"finalised_by" text,
	"current_section_position" integer,
	"section_navigation" "section_navigation" DEFAULT 'free' NOT NULL,
	"marks_correct" numeric(5, 2),
	"negative_marks" numeric(5, 2),
	"marks_unanswered" numeric(5, 2),
	"withdrawn_policy" "withdrawn_policy" DEFAULT 'unscored' NOT NULL,
	"withdrawn_policy_confirmed" boolean DEFAULT false NOT NULL,
	"rules_verified" boolean DEFAULT false NOT NULL,
	"pass_percent_general" numeric(5, 2),
	"pass_percent_reserved" numeric(5, 2),
	"result" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "exam_attempts_deadline_check" CHECK (("exam_attempts"."mode" = 'timed') = ("exam_attempts"."deadline_at" is not null)),
	CONSTRAINT "exam_attempts_closed_check" CHECK (("exam_attempts"."status" = 'in_progress') = ("exam_attempts"."submitted_at" is null)),
	CONSTRAINT "exam_attempts_paper_check" CHECK (("exam_attempts"."kind" = 'fixed_paper') = ("exam_attempts"."paper_id" is not null))
);
--> statement-breakpoint
ALTER TABLE "exam_attempt_questions" ADD CONSTRAINT "exam_attempt_questions_attempt_id_exam_attempts_id_fk" FOREIGN KEY ("attempt_id") REFERENCES "public"."exam_attempts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_attempt_questions" ADD CONSTRAINT "exam_attempt_questions_question_id_questions_id_fk" FOREIGN KEY ("question_id") REFERENCES "public"."questions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_attempt_questions" ADD CONSTRAINT "exam_attempt_questions_question_version_id_question_versions_id_fk" FOREIGN KEY ("question_version_id") REFERENCES "public"."question_versions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_attempts" ADD CONSTRAINT "exam_attempts_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_attempts" ADD CONSTRAINT "exam_attempts_exam_id_exams_id_fk" FOREIGN KEY ("exam_id") REFERENCES "public"."exams"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_attempts" ADD CONSTRAINT "exam_attempts_paper_id_exam_papers_id_fk" FOREIGN KEY ("paper_id") REFERENCES "public"."exam_papers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_attempts" ADD CONSTRAINT "exam_attempts_blueprint_id_exam_blueprints_id_fk" FOREIGN KEY ("blueprint_id") REFERENCES "public"."exam_blueprints"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "exam_attempt_questions_position_idx" ON "exam_attempt_questions" USING btree ("attempt_id","position");--> statement-breakpoint
CREATE INDEX "exam_attempt_questions_question_idx" ON "exam_attempt_questions" USING btree ("question_id");--> statement-breakpoint
CREATE UNIQUE INDEX "exam_attempts_open_idx" ON "exam_attempts" USING btree ("user_id","exam_id") WHERE "exam_attempts"."status" = 'in_progress';--> statement-breakpoint
CREATE INDEX "exam_attempts_user_idx" ON "exam_attempts" USING btree ("user_id","id");--> statement-breakpoint
CREATE INDEX "exam_attempts_deadline_idx" ON "exam_attempts" USING btree ("deadline_at") WHERE "exam_attempts"."status" = 'in_progress';