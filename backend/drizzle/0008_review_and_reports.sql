CREATE TYPE "public"."report_outcome" AS ENUM('fixed', 'retired', 'no_change');--> statement-breakpoint
CREATE TYPE "public"."report_reason" AS ENUM('wrong_answer', 'unclear', 'outdated_law', 'typo', 'other');--> statement-breakpoint
ALTER TYPE "public"."quiz_mode" ADD VALUE 'mistake_review';--> statement-breakpoint
CREATE TABLE "content_reports" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid,
	"question_version_id" uuid NOT NULL,
	"reason" "report_reason" NOT NULL,
	"comment" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"outcome" "report_outcome",
	"resolved_by" uuid,
	"resolved_at" timestamp with time zone,
	"resolution_note" text,
	CONSTRAINT "content_reports_resolution_check" CHECK (("content_reports"."outcome" is null) = ("content_reports"."resolved_at" is null) and ("content_reports"."outcome" is null) = ("content_reports"."resolved_by" is null))
);
--> statement-breakpoint
CREATE TABLE "question_bookmarks" (
	"user_id" uuid NOT NULL,
	"question_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "question_bookmarks_user_id_question_id_pk" PRIMARY KEY("user_id","question_id")
);
--> statement-breakpoint
ALTER TABLE "content_reports" ADD CONSTRAINT "content_reports_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "content_reports" ADD CONSTRAINT "content_reports_question_version_id_question_versions_id_fk" FOREIGN KEY ("question_version_id") REFERENCES "public"."question_versions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "content_reports" ADD CONSTRAINT "content_reports_resolved_by_users_id_fk" FOREIGN KEY ("resolved_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "question_bookmarks" ADD CONSTRAINT "question_bookmarks_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "question_bookmarks" ADD CONSTRAINT "question_bookmarks_question_id_questions_id_fk" FOREIGN KEY ("question_id") REFERENCES "public"."questions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "content_reports_open_idx" ON "content_reports" USING btree ("outcome","created_at");--> statement-breakpoint
CREATE INDEX "content_reports_version_idx" ON "content_reports" USING btree ("question_version_id");--> statement-breakpoint
CREATE UNIQUE INDEX "content_reports_open_per_user_idx" ON "content_reports" USING btree ("user_id","question_version_id") WHERE "content_reports"."outcome" is null;