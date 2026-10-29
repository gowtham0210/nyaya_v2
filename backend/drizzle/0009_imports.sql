CREATE TYPE "public"."import_format" AS ENUM('csv', 'xlsx');--> statement-breakpoint
CREATE TYPE "public"."import_outcome" AS ENUM('created', 'skipped', 'failed');--> statement-breakpoint
CREATE TYPE "public"."problem_level" AS ENUM('error', 'warning');--> statement-breakpoint
CREATE TABLE "import_job_rows" (
	"job_id" uuid NOT NULL,
	"line" integer NOT NULL,
	"external_ref" text,
	"outcome" "import_outcome" NOT NULL,
	"question_id" uuid,
	CONSTRAINT "import_job_rows_job_id_line_pk" PRIMARY KEY("job_id","line"),
	CONSTRAINT "import_job_rows_question_check" CHECK (("import_job_rows"."outcome" <> 'created' or "import_job_rows"."question_id" is not null) and ("import_job_rows"."outcome" <> 'failed' or "import_job_rows"."question_id" is null))
);
--> statement-breakpoint
CREATE TABLE "import_jobs" (
	"id" uuid PRIMARY KEY NOT NULL,
	"created_by" uuid NOT NULL,
	"file_name" text NOT NULL,
	"file_sha256" text NOT NULL,
	"format" "import_format" NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "import_jobs_file_sha256_unique" UNIQUE("file_sha256")
);
--> statement-breakpoint
CREATE TABLE "import_row_problems" (
	"job_id" uuid NOT NULL,
	"line" integer NOT NULL,
	"position" smallint NOT NULL,
	"level" "problem_level" NOT NULL,
	"field" text,
	"reason" text NOT NULL,
	CONSTRAINT "import_row_problems_job_id_line_position_pk" PRIMARY KEY("job_id","line","position")
);
--> statement-breakpoint
ALTER TABLE "import_job_rows" ADD CONSTRAINT "import_job_rows_job_id_import_jobs_id_fk" FOREIGN KEY ("job_id") REFERENCES "public"."import_jobs"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "import_job_rows" ADD CONSTRAINT "import_job_rows_question_id_questions_id_fk" FOREIGN KEY ("question_id") REFERENCES "public"."questions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "import_jobs" ADD CONSTRAINT "import_jobs_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "import_row_problems" ADD CONSTRAINT "import_row_problems_job_id_line_import_job_rows_job_id_line_fk" FOREIGN KEY ("job_id","line") REFERENCES "public"."import_job_rows"("job_id","line") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "import_job_rows_question_idx" ON "import_job_rows" USING btree ("question_id");