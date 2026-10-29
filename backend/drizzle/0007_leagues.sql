ALTER TYPE "public"."coin_reason" ADD VALUE 'league_top3';--> statement-breakpoint
CREATE TABLE "league_cohorts" (
	"id" uuid PRIMARY KEY NOT NULL,
	"week_id" text NOT NULL,
	"tier" smallint NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "league_memberships" (
	"user_id" uuid NOT NULL,
	"week_id" text NOT NULL,
	"cohort_id" uuid NOT NULL,
	"joined_at" timestamp with time zone NOT NULL,
	CONSTRAINT "league_memberships_user_id_week_id_pk" PRIMARY KEY("user_id","week_id")
);
--> statement-breakpoint
-- Must exist before the memberships foreign key that references it.
CREATE UNIQUE INDEX "league_cohorts_id_week_idx" ON "league_cohorts" USING btree ("id","week_id");--> statement-breakpoint
ALTER TABLE "coin_ledger" ADD COLUMN "cohort_id" uuid;--> statement-breakpoint
ALTER TABLE "league_memberships" ADD CONSTRAINT "league_memberships_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "league_memberships" ADD CONSTRAINT "league_memberships_cohort_id_week_id_league_cohorts_id_week_id_fk" FOREIGN KEY ("cohort_id","week_id") REFERENCES "public"."league_cohorts"("id","week_id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "league_cohorts_week_tier_idx" ON "league_cohorts" USING btree ("week_id","tier");--> statement-breakpoint
CREATE INDEX "league_memberships_cohort_idx" ON "league_memberships" USING btree ("cohort_id");--> statement-breakpoint
ALTER TABLE "coin_ledger" ADD CONSTRAINT "coin_ledger_cohort_id_league_cohorts_id_fk" FOREIGN KEY ("cohort_id") REFERENCES "public"."league_cohorts"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "coin_ledger_cohort_idx" ON "coin_ledger" USING btree ("user_id","cohort_id") WHERE "coin_ledger"."cohort_id" is not null;