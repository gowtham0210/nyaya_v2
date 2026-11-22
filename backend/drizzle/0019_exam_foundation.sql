CREATE TYPE "public"."alternate_answer_policy" AS ENUM('any_accepted');--> statement-breakpoint
CREATE TYPE "public"."blueprint_status" AS ENUM('draft', 'published', 'retired');--> statement-breakpoint
CREATE TYPE "public"."config_status" AS ENUM('official_confirmed', 'inferred', 'unverified');--> statement-breakpoint
CREATE TYPE "public"."content_source_kind" AS ENUM('official_bci', 'third_party', 'original');--> statement-breakpoint
CREATE TYPE "public"."law_regime" AS ENUM('old_codes', 'new_codes', 'both', 'neutral');--> statement-breakpoint
CREATE TYPE "public"."law_regime_filter" AS ENUM('any', 'exclude_old', 'prefer_new');--> statement-breakpoint
CREATE TYPE "public"."license_status" AS ENUM('pending', 'permission_granted', 'permitted_by_terms', 'blocked');--> statement-breakpoint
CREATE TYPE "public"."section_navigation" AS ENUM('free', 'locked_order');--> statement-breakpoint
CREATE TABLE "content_sources" (
	"id" uuid PRIMARY KEY NOT NULL,
	"kind" "content_source_kind" NOT NULL,
	"title" text NOT NULL,
	"publisher" text,
	"url" text,
	"retrieved_on" date,
	"sha256" text,
	"license_status" "license_status" DEFAULT 'pending' NOT NULL,
	"license_note" text,
	"allowed_uses" text[] DEFAULT '{}'::text[] NOT NULL,
	"created_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "content_sources_url_https" CHECK ("content_sources"."url" is null or "content_sources"."url" ~ '^https://'),
	CONSTRAINT "content_sources_sha256_hex" CHECK ("content_sources"."sha256" is null or "content_sources"."sha256" ~ '^[0-9a-f]{64}$')
);
--> statement-breakpoint
CREATE TABLE "exam_blueprints" (
	"id" uuid PRIMARY KEY NOT NULL,
	"exam_id" uuid NOT NULL,
	"code" text NOT NULL,
	"version" integer DEFAULT 1 NOT NULL,
	"status" "blueprint_status" DEFAULT 'draft' NOT NULL,
	"duration_seconds" integer NOT NULL,
	"total_questions" integer NOT NULL,
	"marks_correct" numeric(5, 2) NOT NULL,
	"negative_marks" numeric(5, 2) DEFAULT '0' NOT NULL,
	"marks_unanswered" numeric(5, 2) DEFAULT '0' NOT NULL,
	"pass_percent_general" numeric(5, 2),
	"pass_percent_reserved" numeric(5, 2),
	"section_navigation" "section_navigation" DEFAULT 'free' NOT NULL,
	"law_regime_filter" "law_regime_filter" DEFAULT 'any' NOT NULL,
	"alternate_answer_policy" "alternate_answer_policy" DEFAULT 'any_accepted' NOT NULL,
	"config_status" "config_status" DEFAULT 'unverified' NOT NULL,
	"config_source" text,
	"config_checked_on" date,
	"created_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "exam_blueprints_duration_check" CHECK ("exam_blueprints"."duration_seconds" > 0),
	CONSTRAINT "exam_blueprints_total_check" CHECK ("exam_blueprints"."total_questions" > 0),
	CONSTRAINT "exam_blueprints_marks_check" CHECK ("exam_blueprints"."marks_correct" >= 0 and "exam_blueprints"."negative_marks" >= 0 and "exam_blueprints"."marks_unanswered" >= 0),
	CONSTRAINT "exam_blueprints_pass_check" CHECK (("exam_blueprints"."pass_percent_general" is null or "exam_blueprints"."pass_percent_general" between 0 and 100)
        and ("exam_blueprints"."pass_percent_reserved" is null or "exam_blueprints"."pass_percent_reserved" between 0 and 100))
);
--> statement-breakpoint
CREATE TABLE "exam_question_tags" (
	"question_id" uuid NOT NULL,
	"exam_id" uuid NOT NULL,
	"created_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "exam_question_tags_question_id_exam_id_pk" PRIMARY KEY("question_id","exam_id")
);
--> statement-breakpoint
CREATE TABLE "exam_section_topics" (
	"section_id" uuid NOT NULL,
	"topic_id" uuid NOT NULL,
	"min_count" integer DEFAULT 0 NOT NULL,
	"max_count" integer,
	"weight" integer DEFAULT 1 NOT NULL,
	CONSTRAINT "exam_section_topics_section_id_topic_id_pk" PRIMARY KEY("section_id","topic_id"),
	CONSTRAINT "exam_section_topics_range_check" CHECK ("exam_section_topics"."min_count" >= 0 and ("exam_section_topics"."max_count" is null or "exam_section_topics"."max_count" >= "exam_section_topics"."min_count") and "exam_section_topics"."weight" > 0)
);
--> statement-breakpoint
CREATE TABLE "exam_sections" (
	"id" uuid PRIMARY KEY NOT NULL,
	"blueprint_id" uuid NOT NULL,
	"code" text NOT NULL,
	"name" text NOT NULL,
	"position" integer NOT NULL,
	"question_count" integer NOT NULL,
	"duration_seconds" integer,
	"marks_correct" numeric(5, 2),
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "exam_sections_count_check" CHECK ("exam_sections"."question_count" > 0),
	CONSTRAINT "exam_sections_duration_check" CHECK ("exam_sections"."duration_seconds" is null or "exam_sections"."duration_seconds" > 0)
);
--> statement-breakpoint
CREATE TABLE "exams" (
	"id" uuid PRIMARY KEY NOT NULL,
	"slug" text NOT NULL,
	"name" text NOT NULL,
	"short_name" text NOT NULL,
	"is_active" boolean DEFAULT false NOT NULL,
	"sort_order" integer DEFAULT 0 NOT NULL,
	"instructions" text DEFAULT '' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "exams_slug_unique" UNIQUE("slug")
);
--> statement-breakpoint
CREATE TABLE "question_version_acts" (
	"version_id" uuid NOT NULL,
	"act_id" uuid NOT NULL,
	CONSTRAINT "question_version_acts_version_id_act_id_pk" PRIMARY KEY("version_id","act_id")
);
--> statement-breakpoint
ALTER TABLE "acts" ADD COLUMN "repealed_on" date;--> statement-breakpoint
ALTER TABLE "acts" ADD COLUMN "replaced_by_act_id" uuid;--> statement-breakpoint
ALTER TABLE "import_jobs" ADD COLUMN "content_source_id" uuid;--> statement-breakpoint
ALTER TABLE "question_versions" ADD COLUMN "alternate_correct_option_ids" text[] DEFAULT '{}'::text[] NOT NULL;--> statement-breakpoint
ALTER TABLE "question_versions" ADD COLUMN "lock_option_order" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "question_versions" ADD COLUMN "law_regime" "law_regime" DEFAULT 'neutral' NOT NULL;--> statement-breakpoint
ALTER TABLE "question_versions" ADD COLUMN "currency_note" text;--> statement-breakpoint
ALTER TABLE "question_versions" ADD COLUMN "content_source_id" uuid;--> statement-breakpoint
ALTER TABLE "question_versions" ADD COLUMN "concept_key" text;--> statement-breakpoint
ALTER TABLE "questions" ADD COLUMN "exam_only" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "content_sources" ADD CONSTRAINT "content_sources_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_blueprints" ADD CONSTRAINT "exam_blueprints_exam_id_exams_id_fk" FOREIGN KEY ("exam_id") REFERENCES "public"."exams"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_blueprints" ADD CONSTRAINT "exam_blueprints_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_question_tags" ADD CONSTRAINT "exam_question_tags_question_id_questions_id_fk" FOREIGN KEY ("question_id") REFERENCES "public"."questions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_question_tags" ADD CONSTRAINT "exam_question_tags_exam_id_exams_id_fk" FOREIGN KEY ("exam_id") REFERENCES "public"."exams"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_question_tags" ADD CONSTRAINT "exam_question_tags_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_section_topics" ADD CONSTRAINT "exam_section_topics_section_id_exam_sections_id_fk" FOREIGN KEY ("section_id") REFERENCES "public"."exam_sections"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_section_topics" ADD CONSTRAINT "exam_section_topics_topic_id_topics_id_fk" FOREIGN KEY ("topic_id") REFERENCES "public"."topics"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_sections" ADD CONSTRAINT "exam_sections_blueprint_id_exam_blueprints_id_fk" FOREIGN KEY ("blueprint_id") REFERENCES "public"."exam_blueprints"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "question_version_acts" ADD CONSTRAINT "question_version_acts_version_id_question_versions_id_fk" FOREIGN KEY ("version_id") REFERENCES "public"."question_versions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "question_version_acts" ADD CONSTRAINT "question_version_acts_act_id_acts_id_fk" FOREIGN KEY ("act_id") REFERENCES "public"."acts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "content_sources_license_idx" ON "content_sources" USING btree ("license_status");--> statement-breakpoint
CREATE UNIQUE INDEX "exam_blueprints_code_version_idx" ON "exam_blueprints" USING btree ("exam_id","code","version");--> statement-breakpoint
CREATE INDEX "exam_blueprints_exam_idx" ON "exam_blueprints" USING btree ("exam_id","status");--> statement-breakpoint
CREATE INDEX "exam_question_tags_exam_idx" ON "exam_question_tags" USING btree ("exam_id");--> statement-breakpoint
CREATE INDEX "exam_section_topics_topic_idx" ON "exam_section_topics" USING btree ("topic_id");--> statement-breakpoint
CREATE UNIQUE INDEX "exam_sections_code_idx" ON "exam_sections" USING btree ("blueprint_id","code");--> statement-breakpoint
CREATE UNIQUE INDEX "exam_sections_position_idx" ON "exam_sections" USING btree ("blueprint_id","position");--> statement-breakpoint
CREATE INDEX "question_version_acts_act_idx" ON "question_version_acts" USING btree ("act_id");--> statement-breakpoint
ALTER TABLE "acts" ADD CONSTRAINT "acts_replaced_by_act_id_acts_id_fk" FOREIGN KEY ("replaced_by_act_id") REFERENCES "public"."acts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "import_jobs" ADD CONSTRAINT "import_jobs_content_source_id_content_sources_id_fk" FOREIGN KEY ("content_source_id") REFERENCES "public"."content_sources"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "question_versions" ADD CONSTRAINT "question_versions_content_source_id_content_sources_id_fk" FOREIGN KEY ("content_source_id") REFERENCES "public"."content_sources"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "question_versions_content_source_idx" ON "question_versions" USING btree ("content_source_id");--> statement-breakpoint
ALTER TABLE "question_versions" ADD CONSTRAINT "alternate_disjoint_from_correct" CHECK (not ("question_versions"."alternate_correct_option_ids" && "question_versions"."correct_option_ids"));