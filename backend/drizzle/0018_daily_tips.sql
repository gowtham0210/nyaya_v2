CREATE TYPE "public"."daily_tip_category" AS ENUM('citizen_rights', 'criminal_law', 'consumer_rights', 'family_law', 'property', 'workplace', 'general');--> statement-breakpoint
CREATE TYPE "public"."daily_tip_status" AS ENUM('draft', 'in_review', 'changes_requested', 'approved', 'published', 'retired');--> statement-breakpoint
CREATE TABLE "daily_tips" (
	"id" uuid PRIMARY KEY NOT NULL,
	"status" "daily_tip_status" DEFAULT 'draft' NOT NULL,
	"category" "daily_tip_category" NOT NULL,
	"language" text DEFAULT 'en' NOT NULL,
	"title" text DEFAULT '' NOT NULL,
	"summary" text DEFAULT '' NOT NULL,
	"explanation" text DEFAULT '' NOT NULL,
	"legal_reference" text DEFAULT '' NOT NULL,
	"source_url" text,
	"publish_date" date,
	"last_verified_on" date,
	"created_by" uuid,
	"updated_by" uuid,
	"reviewer_id" uuid,
	"approved_at" timestamp with time zone,
	"published_by" uuid,
	"published_at" timestamp with time zone,
	"retired_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "daily_tips" ADD CONSTRAINT "daily_tips_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "daily_tips" ADD CONSTRAINT "daily_tips_updated_by_users_id_fk" FOREIGN KEY ("updated_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "daily_tips" ADD CONSTRAINT "daily_tips_reviewer_id_users_id_fk" FOREIGN KEY ("reviewer_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "daily_tips" ADD CONSTRAINT "daily_tips_published_by_users_id_fk" FOREIGN KEY ("published_by") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "daily_tips_status_idx" ON "daily_tips" USING btree ("status","publish_date");--> statement-breakpoint
CREATE UNIQUE INDEX "daily_tips_live_day_idx" ON "daily_tips" USING btree ("publish_date","language") WHERE "daily_tips"."status" = 'published';