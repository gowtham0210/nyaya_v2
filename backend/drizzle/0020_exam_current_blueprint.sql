ALTER TYPE "public"."law_regime_filter" ADD VALUE 'include_all';--> statement-breakpoint
ALTER TABLE "exam_blueprints" ADD COLUMN "is_current" boolean DEFAULT false NOT NULL;--> statement-breakpoint
CREATE UNIQUE INDEX "exam_blueprints_current_idx" ON "exam_blueprints" USING btree ("exam_id") WHERE "exam_blueprints"."is_current";--> statement-breakpoint
ALTER TABLE "exam_blueprints" ADD CONSTRAINT "exam_blueprints_current_published_check" CHECK (not "exam_blueprints"."is_current" or "exam_blueprints"."status" = 'published');