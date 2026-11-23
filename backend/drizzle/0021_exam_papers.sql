CREATE TYPE "public"."key_history_kind" AS ENUM('provisional', 'final', 'revised', 'withdrawn');--> statement-breakpoint
CREATE TYPE "public"."paper_answer_status" AS ENUM('keyed', 'multi_accepted', 'withdrawn');--> statement-breakpoint
CREATE TYPE "public"."paper_status" AS ENUM('draft', 'published', 'retired');--> statement-breakpoint
CREATE TYPE "public"."withdrawn_policy" AS ENUM('unscored', 'award_all');--> statement-breakpoint
CREATE TABLE "exam_paper_key_history" (
	"id" uuid PRIMARY KEY NOT NULL,
	"paper_id" uuid NOT NULL,
	"paper_question_id" uuid NOT NULL,
	"kind" "key_history_kind" NOT NULL,
	"accepted_option_ids" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"content_source_id" uuid,
	"source_document_ref" text,
	"retrieved_on" date,
	"source_sha256" text,
	"note" text,
	"recorded_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "exam_paper_key_history_sha_check" CHECK ("exam_paper_key_history"."source_sha256" is null or "exam_paper_key_history"."source_sha256" ~ '^[0-9a-f]{64}$')
);
--> statement-breakpoint
CREATE TABLE "exam_paper_questions" (
	"id" uuid PRIMARY KEY NOT NULL,
	"paper_id" uuid NOT NULL,
	"position" integer NOT NULL,
	"question_id" uuid,
	"question_version_id" uuid,
	"answer_status" "paper_answer_status" NOT NULL,
	"original_ref" text,
	"option_order" jsonb,
	"original_label_scheme" text,
	"official_key_text" text,
	"source_ref" text,
	"withdrawn_note" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "exam_paper_questions_position_check" CHECK ("exam_paper_questions"."position" >= 1),
	CONSTRAINT "exam_paper_questions_withdrawn_check" CHECK (("exam_paper_questions"."answer_status" = 'withdrawn') = ("exam_paper_questions"."question_version_id" is null)
        and ("exam_paper_questions"."question_version_id" is null) = ("exam_paper_questions"."question_id" is null))
);
--> statement-breakpoint
CREATE TABLE "exam_papers" (
	"id" uuid PRIMARY KEY NOT NULL,
	"exam_id" uuid NOT NULL,
	"code" text NOT NULL,
	"revision" integer DEFAULT 1 NOT NULL,
	"supersedes_id" uuid,
	"title" text NOT NULL,
	"edition" text,
	"year" integer,
	"set_label" text,
	"status" "paper_status" DEFAULT 'draft' NOT NULL,
	"frozen_at" timestamp with time zone,
	"blueprint_id" uuid,
	"total_questions" integer NOT NULL,
	"duration_seconds" integer,
	"marks_correct" numeric(5, 2),
	"negative_marks" numeric(5, 2),
	"marks_unanswered" numeric(5, 2),
	"withdrawn_policy" "withdrawn_policy" DEFAULT 'unscored' NOT NULL,
	"withdrawn_policy_confirmed" boolean DEFAULT false NOT NULL,
	"config_status" "config_status" DEFAULT 'unverified' NOT NULL,
	"source_note" text,
	"created_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "exam_papers_total_check" CHECK ("exam_papers"."total_questions" > 0),
	CONSTRAINT "exam_papers_marks_check" CHECK (("exam_papers"."marks_correct" is null or "exam_papers"."marks_correct" >= 0)
        and ("exam_papers"."negative_marks" is null or "exam_papers"."negative_marks" >= 0)
        and ("exam_papers"."marks_unanswered" is null or "exam_papers"."marks_unanswered" >= 0)),
	CONSTRAINT "exam_papers_duration_check" CHECK ("exam_papers"."duration_seconds" is null or "exam_papers"."duration_seconds" > 0),
	CONSTRAINT "exam_papers_frozen_check" CHECK (("exam_papers"."status" = 'draft') = ("exam_papers"."frozen_at" is null)),
	CONSTRAINT "exam_papers_award_all_check" CHECK ("exam_papers"."withdrawn_policy" <> 'award_all' or "exam_papers"."withdrawn_policy_confirmed")
);
--> statement-breakpoint
ALTER TABLE "exam_paper_key_history" ADD CONSTRAINT "exam_paper_key_history_paper_id_exam_papers_id_fk" FOREIGN KEY ("paper_id") REFERENCES "public"."exam_papers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_paper_key_history" ADD CONSTRAINT "exam_paper_key_history_paper_question_id_exam_paper_questions_id_fk" FOREIGN KEY ("paper_question_id") REFERENCES "public"."exam_paper_questions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_paper_key_history" ADD CONSTRAINT "exam_paper_key_history_content_source_id_content_sources_id_fk" FOREIGN KEY ("content_source_id") REFERENCES "public"."content_sources"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_paper_key_history" ADD CONSTRAINT "exam_paper_key_history_recorded_by_users_id_fk" FOREIGN KEY ("recorded_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_paper_questions" ADD CONSTRAINT "exam_paper_questions_paper_id_exam_papers_id_fk" FOREIGN KEY ("paper_id") REFERENCES "public"."exam_papers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_paper_questions" ADD CONSTRAINT "exam_paper_questions_question_id_questions_id_fk" FOREIGN KEY ("question_id") REFERENCES "public"."questions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_paper_questions" ADD CONSTRAINT "exam_paper_questions_question_version_id_question_versions_id_fk" FOREIGN KEY ("question_version_id") REFERENCES "public"."question_versions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_papers" ADD CONSTRAINT "exam_papers_exam_id_exams_id_fk" FOREIGN KEY ("exam_id") REFERENCES "public"."exams"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_papers" ADD CONSTRAINT "exam_papers_supersedes_id_exam_papers_id_fk" FOREIGN KEY ("supersedes_id") REFERENCES "public"."exam_papers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_papers" ADD CONSTRAINT "exam_papers_blueprint_id_exam_blueprints_id_fk" FOREIGN KEY ("blueprint_id") REFERENCES "public"."exam_blueprints"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_papers" ADD CONSTRAINT "exam_papers_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "exam_paper_key_history_pq_idx" ON "exam_paper_key_history" USING btree ("paper_question_id","created_at");--> statement-breakpoint
CREATE INDEX "exam_paper_key_history_paper_idx" ON "exam_paper_key_history" USING btree ("paper_id");--> statement-breakpoint
CREATE UNIQUE INDEX "exam_paper_questions_position_idx" ON "exam_paper_questions" USING btree ("paper_id","position");--> statement-breakpoint
CREATE INDEX "exam_paper_questions_version_idx" ON "exam_paper_questions" USING btree ("question_version_id");--> statement-breakpoint
CREATE UNIQUE INDEX "exam_papers_code_revision_idx" ON "exam_papers" USING btree ("exam_id","code","revision");--> statement-breakpoint
CREATE UNIQUE INDEX "exam_papers_published_idx" ON "exam_papers" USING btree ("exam_id","code") WHERE "exam_papers"."status" = 'published';--> statement-breakpoint
CREATE INDEX "exam_papers_exam_idx" ON "exam_papers" USING btree ("exam_id","status");