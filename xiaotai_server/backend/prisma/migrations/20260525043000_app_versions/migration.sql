-- CreateTable
CREATE TABLE "app_versions" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "platform" TEXT NOT NULL,
    "channel" TEXT NOT NULL DEFAULT 'private',
    "version_name" TEXT NOT NULL,
    "version_code" INTEGER NOT NULL,
    "apk_url" TEXT NOT NULL,
    "apk_path" TEXT,
    "apk_size" INTEGER,
    "sha256" TEXT,
    "changelog" TEXT,
    "force_update" BOOLEAN NOT NULL DEFAULT false,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "created_by" TEXT NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL
);

-- CreateIndex
CREATE INDEX "app_versions_platform_channel_enabled_idx" ON "app_versions"("platform", "channel", "enabled");

-- CreateIndex
CREATE INDEX "app_versions_version_code_idx" ON "app_versions"("version_code");

-- CreateIndex
CREATE INDEX "app_versions_created_at_idx" ON "app_versions"("created_at");
