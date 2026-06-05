CREATE TABLE "music_tracks" (
  "id" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "artist" TEXT,
  "album" TEXT,
  "audio_path" TEXT NOT NULL,
  "cover_path" TEXT,
  "lyrics" TEXT,
  "original_name" TEXT NOT NULL,
  "mime_type" TEXT NOT NULL,
  "size" INTEGER NOT NULL,
  "duration_seconds" INTEGER,
  "enabled" BOOLEAN NOT NULL DEFAULT true,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_by" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "music_tracks_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "music_tracks_enabled_sort_order_idx" ON "music_tracks"("enabled", "sort_order");
CREATE INDEX "music_tracks_created_at_idx" ON "music_tracks"("created_at");
