-- CreateTable
CREATE TABLE "daily_comics" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "publish_date" DATETIME NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "created_by" TEXT NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL
);

-- CreateTable
CREATE TABLE "daily_comic_images" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "comic_id" TEXT NOT NULL,
    "image_url" TEXT NOT NULL,
    "original_name" TEXT,
    "mime_type" TEXT,
    "size" INTEGER,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    CONSTRAINT "daily_comic_images_comic_id_fkey" FOREIGN KEY ("comic_id") REFERENCES "daily_comics" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateIndex
CREATE UNIQUE INDEX "daily_comics_publish_date_key" ON "daily_comics"("publish_date");

-- CreateIndex
CREATE INDEX "daily_comics_enabled_publish_date_idx" ON "daily_comics"("enabled", "publish_date");

-- CreateIndex
CREATE INDEX "daily_comics_created_at_idx" ON "daily_comics"("created_at");

-- CreateIndex
CREATE INDEX "daily_comic_images_comic_id_sort_order_idx" ON "daily_comic_images"("comic_id", "sort_order");
