CREATE TABLE "device_usage_reports" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "user_id" TEXT NOT NULL,
    "device_id" TEXT NOT NULL,
    "device_name" TEXT,
    "screen_on" BOOLEAN NOT NULL DEFAULT false,
    "foreground_package" TEXT,
    "foreground_app_name" TEXT,
    "foreground_since_ms" BIGINT,
    "today_usage" JSONB,
    "captured_at" DATETIME NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX "device_usage_reports_user_id_device_id_captured_at_idx" ON "device_usage_reports"("user_id", "device_id", "captured_at" DESC);
CREATE INDEX "device_usage_reports_user_id_captured_at_idx" ON "device_usage_reports"("user_id", "captured_at" DESC);

CREATE TABLE "force_pushes" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "user_id" TEXT NOT NULL,
    "device_id" TEXT,
    "title" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "level" TEXT NOT NULL DEFAULT 'info',
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "delivered_at" DATETIME,
    "created_by" TEXT NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "expires_at" DATETIME
);

CREATE INDEX "force_pushes_user_id_device_id_enabled_delivered_at_idx" ON "force_pushes"("user_id", "device_id", "enabled", "delivered_at");
CREATE INDEX "force_pushes_created_at_idx" ON "force_pushes"("created_at" DESC);
