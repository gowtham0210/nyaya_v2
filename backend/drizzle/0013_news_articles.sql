CREATE TYPE "public"."news_category" AS ENUM('supreme_court', 'high_courts', 'legislation', 'explainer');--> statement-breakpoint
CREATE TYPE "public"."news_status" AS ENUM('draft', 'in_review', 'changes_requested', 'approved', 'published', 'retired');--> statement-breakpoint
CREATE TABLE "news_articles" (
	"id" uuid PRIMARY KEY NOT NULL,
	"external_ref" text,
	"status" "news_status" DEFAULT 'draft' NOT NULL,
	"category" "news_category" NOT NULL,
	"title" text DEFAULT '' NOT NULL,
	"summary" text DEFAULT '' NOT NULL,
	"key_points" text[] DEFAULT '{}'::text[] NOT NULL,
	"why_it_matters" text DEFAULT '' NOT NULL,
	"source" text DEFAULT '' NOT NULL,
	"source_url" text,
	"event_date" date,
	"read_minutes" smallint DEFAULT 3 NOT NULL,
	"created_by" uuid,
	"updated_by" uuid,
	"reviewer_id" uuid,
	"approved_at" timestamp with time zone,
	"published_by" uuid,
	"published_at" timestamp with time zone,
	"retired_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "news_articles_external_ref_unique" UNIQUE("external_ref"),
	CONSTRAINT "read_minutes_range" CHECK ("news_articles"."read_minutes" between 1 and 30)
);
--> statement-breakpoint
ALTER TABLE "news_articles" ADD CONSTRAINT "news_articles_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "news_articles" ADD CONSTRAINT "news_articles_updated_by_users_id_fk" FOREIGN KEY ("updated_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "news_articles" ADD CONSTRAINT "news_articles_reviewer_id_users_id_fk" FOREIGN KEY ("reviewer_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "news_articles" ADD CONSTRAINT "news_articles_published_by_users_id_fk" FOREIGN KEY ("published_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "news_articles_status_idx" ON "news_articles" USING btree ("status","event_date");