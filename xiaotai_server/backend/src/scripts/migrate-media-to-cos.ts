import { NestFactory } from "@nestjs/core";
import { ConfigService } from "@nestjs/config";
import { createHash } from "node:crypto";
import { readdir, readFile, stat } from "node:fs/promises";
import { basename, extname, isAbsolute, relative, resolve } from "node:path";

import { AppModule } from "../app.module";
import { ObjectStorageService } from "../common/object-storage/object-storage.service";
import { PrismaService } from "../common/prisma/prisma.service";
import { resolveStoragePath } from "../common/storage-path";
import type { AppConfig } from "../config/configuration";

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ["error", "warn", "log"],
  });
  try {
    const objectStorage = app.get(ObjectStorageService);
    const prisma = app.get(PrismaService);
    const configService = app.get(ConfigService<AppConfig, true>);
    if (!objectStorage.cosEnabled) {
      throw new Error("COS_ENABLED=true is required before migration");
    }

    const storageRoot = configService.get("storageRoot", { infer: true });
    const rootPath = resolveStoragePath(storageRoot);
    const migrated = new Map<string, string>();

    const migrateLocalFile = async (
      localPath: string,
      contentType: string,
    ): Promise<string> => {
      if (objectStorage.isCosLocator(localPath)) {
        return localPath;
      }
      const cached = migrated.get(localPath);
      if (cached) {
        return cached;
      }
      const buffer = await readFile(localPath).catch(() => null);
      if (!buffer) {
        console.warn(`[skip] missing local file: ${localPath}`);
        return localPath;
      }
      const key = storageKeyForLocalPath(rootPath, localPath, buffer);
      const stored = await objectStorage.putObject({
        key,
        localPath,
        buffer,
        contentType,
      });
      migrated.set(localPath, stored.locator);
      console.log(`[media] ${localPath} -> ${stored.locator}`);
      return stored.locator;
    };

    const assets = await prisma.mediaAsset.findMany({
      select: {
        id: true,
        filePath: true,
        thumbPath: true,
        mimeType: true,
      },
    });
    let updatedMediaRows = 0;
    for (const asset of assets) {
      const filePath = await migrateLocalFile(asset.filePath, asset.mimeType);
      const thumbPath = asset.thumbPath
        ? await migrateLocalFile(asset.thumbPath, asset.mimeType)
        : null;
      if (filePath !== asset.filePath || thumbPath !== asset.thumbPath) {
        await prisma.mediaAsset.update({
          where: { id: asset.id },
          data: { filePath, thumbPath },
        });
        updatedMediaRows += 1;
      }
    }

    const announcementFiles = await migratePublicFolder(
      objectStorage,
      storageRoot,
      "announcements",
    );
    const comicFiles = await migratePublicFolder(
      objectStorage,
      storageRoot,
      "daily-comics",
    );

    console.log(
      `COS migration done. mediaRows=${updatedMediaRows}, uniqueMediaFiles=${migrated.size}, announcementFiles=${announcementFiles}, comicFiles=${comicFiles}`,
    );
  } finally {
    await app.close();
  }
}

async function migratePublicFolder(
  objectStorage: ObjectStorageService,
  storageRoot: string,
  folder: "announcements" | "daily-comics",
): Promise<number> {
  const dir = resolveStoragePath(storageRoot, folder);
  const names = await readdir(dir).catch(() => []);
  let count = 0;
  for (const name of names) {
    if (!/^[\w.-]+$/.test(name)) {
      continue;
    }
    const localPath = resolveStoragePath(storageRoot, folder, name);
    const fileStat = await stat(localPath).catch(() => null);
    if (!fileStat?.isFile()) {
      continue;
    }
    const buffer = await readFile(localPath);
    const stored = await objectStorage.putObject({
      key: `${folder}/${name}`,
      localPath,
      buffer,
      contentType: contentTypeFromExt(extname(name)),
    });
    console.log(`[${folder}] ${name} -> ${stored.locator}`);
    count += 1;
  }
  return count;
}

function storageKeyForLocalPath(
  rootPath: string,
  localPath: string,
  buffer: Buffer,
): string {
  const absoluteRoot = resolve(rootPath);
  const absolutePath = resolve(localPath);
  const relativePath = relative(absoluteRoot, absolutePath);
  if (
    relativePath &&
    !relativePath.startsWith("..") &&
    !isAbsolute(relativePath)
  ) {
    return relativePath.replace(/\\/g, "/");
  }
  const digest = createHash("sha256").update(buffer).digest("hex").slice(0, 16);
  return `uploads/migrated/${digest}-${basename(localPath)}`;
}

function contentTypeFromExt(ext: string): string {
  const value = ext.toLowerCase();
  if (value === ".png") return "image/png";
  if (value === ".webp") return "image/webp";
  if (value === ".gif") return "image/gif";
  if (value === ".heic") return "image/heic";
  if (value === ".heif") return "image/heif";
  if (value === ".mov") return "video/quicktime";
  if (value === ".webm") return "video/webm";
  if (value === ".3gp") return "video/3gpp";
  if (value === ".mkv") return "video/x-matroska";
  if (value === ".mp4") return "video/mp4";
  return "image/jpeg";
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
