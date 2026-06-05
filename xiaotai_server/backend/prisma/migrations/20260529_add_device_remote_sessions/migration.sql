CREATE TABLE "device_remote_sessions" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "user_id" TEXT NOT NULL,
    "device_id" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'requested',
    "latest_frame_path" TEXT,
    "frame_mime_type" TEXT,
    "frame_size" INTEGER,
    "frame_width" INTEGER,
    "frame_height" INTEGER,
    "frame_captured_at" DATETIME,
    "requested_by" TEXT NOT NULL,
    "requested_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "accepted_at" DATETIME,
    "stopped_at" DATETIME,
    "expires_at" DATETIME NOT NULL,
    "error_message" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL
);

CREATE INDEX "device_remote_sessions_user_id_device_id_status_expires_at_idx" ON "device_remote_sessions"("user_id", "device_id", "status", "expires_at");
CREATE INDEX "device_remote_sessions_requested_at_idx" ON "device_remote_sessions"("requested_at" DESC);
