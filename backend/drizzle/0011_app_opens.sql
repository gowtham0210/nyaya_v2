CREATE TABLE "app_opens" (
	"user_id" uuid NOT NULL,
	"day" date NOT NULL,
	CONSTRAINT "app_opens_user_id_day_pk" PRIMARY KEY("user_id","day")
);
--> statement-breakpoint
ALTER TABLE "app_opens" ADD CONSTRAINT "app_opens_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "app_opens_day_idx" ON "app_opens" USING btree ("day");