CREATE TABLE "media_assets" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "user_id" TEXT NOT NULL,
  "space_id" TEXT NOT NULL,
  "device_id" TEXT,
  "original_name" TEXT NOT NULL,
  "mime_type" TEXT NOT NULL,
  "size" INTEGER NOT NULL,
  "sha256" TEXT NOT NULL,
  "file_path" TEXT NOT NULL,
  "thumb_path" TEXT,
  "taken_at" DATETIME,
  "uploaded_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" DATETIME,
  "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" DATETIME NOT NULL,
  CONSTRAINT "media_assets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "media_assets_space_id_fkey" FOREIGN KEY ("space_id") REFERENCES "spaces" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "media_assets_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "devices" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX "media_assets_user_id_uploaded_at_idx" ON "media_assets"("user_id", "uploaded_at");
CREATE INDEX "media_assets_space_id_idx" ON "media_assets"("space_id");
CREATE INDEX "media_assets_device_id_idx" ON "media_assets"("device_id");
CREATE INDEX "media_assets_sha256_idx" ON "media_assets"("sha256");
CREATE INDEX "media_assets_deleted_at_idx" ON "media_assets"("deleted_at");
