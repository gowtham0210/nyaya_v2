CREATE TYPE "public"."coin_reason" AS ENUM('welcome', 'new_stars', 'daily_docket', 'daily_goal', 'streak_milestone', 'chest', 'energy_refill', 'streak_freeze');--> statement-breakpoint
CREATE TYPE "public"."energy_reason" AS ENUM('quiz_start', 'quiz_refund', 'three_star_bonus', 'refill');--> statement-breakpoint
CREATE TYPE "public"."persona" AS ENUM('advocate', 'aspirant', 'citizen');--> statement-breakpoint
CREATE TABLE "coin_ledger" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"amount" integer NOT NULL,
	"reason" "coin_reason" NOT NULL,
	"session_id" uuid,
	"subject_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "energy_ledger" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"amount" integer NOT NULL,
	"reason" "energy_reason" NOT NULL,
	"session_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "learner_settings" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"persona" "persona" NOT NULL,
	"language" text NOT NULL,
	"daily_goal" smallint NOT NULL,
	"onboarded_at" timestamp with time zone,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "premium_memberships" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"source" text NOT NULL,
	"started_at" timestamp with time zone NOT NULL
);
--> statement-breakpoint
ALTER TABLE "coin_ledger" ADD CONSTRAINT "coin_ledger_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "coin_ledger" ADD CONSTRAINT "coin_ledger_session_id_quiz_sessions_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."quiz_sessions"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "coin_ledger" ADD CONSTRAINT "coin_ledger_subject_id_subjects_id_fk" FOREIGN KEY ("subject_id") REFERENCES "public"."subjects"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "energy_ledger" ADD CONSTRAINT "energy_ledger_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "energy_ledger" ADD CONSTRAINT "energy_ledger_session_id_quiz_sessions_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."quiz_sessions"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "learner_settings" ADD CONSTRAINT "learner_settings_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "premium_memberships" ADD CONSTRAINT "premium_memberships_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "coin_ledger_user_idx" ON "coin_ledger" USING btree ("user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "coin_ledger_session_reason_idx" ON "coin_ledger" USING btree ("user_id","reason","session_id") WHERE "coin_ledger"."session_id" is not null;--> statement-breakpoint
CREATE UNIQUE INDEX "coin_ledger_chest_idx" ON "coin_ledger" USING btree ("user_id","subject_id") WHERE "coin_ledger"."reason" = 'chest';--> statement-breakpoint
CREATE UNIQUE INDEX "coin_ledger_welcome_idx" ON "coin_ledger" USING btree ("user_id") WHERE "coin_ledger"."reason" = 'welcome';--> statement-breakpoint
CREATE INDEX "energy_ledger_user_idx" ON "energy_ledger" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "energy_ledger_session_reason_idx" ON "energy_ledger" USING btree ("session_id","reason") WHERE "energy_ledger"."session_id" is not null;