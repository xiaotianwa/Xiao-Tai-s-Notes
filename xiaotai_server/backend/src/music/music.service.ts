import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { MusicTrack, Prisma } from "@prisma/client";
import { createHash } from "node:crypto";
import { extname } from "node:path";

import { ObjectStorageService } from "../common/object-storage/object-storage.service";
import { PrismaService } from "../common/prisma/prisma.service";
import { resolveStoragePath } from "../common/storage-path";
import type { AppConfig } from "../config/configuration";
import type {
  CreateMusicTrackDto,
  MusicQueryDto,
  UpdateMusicTrackDto,
} from "./dto/music.dto";

const maxAudioBytes = 80 * 1024 * 1024;
const maxCoverBytes = 5 * 1024 * 1024;
const maxLyricsBytes = 512 * 1024;

const audioTypes = new Set([
  "audio/mpeg",
  "audio/mp3",
  "audio/mp4",
  "audio/aac",
  "audio/x-m4a",
  "audio/wav",
  "audio/wave",
  "audio/x-wav",
  "audio/flac",
  "audio/x-flac",
  "audio/ogg",
  "audio/webm",
]);

const coverTypes = new Set(["image/jpeg", "image/png", "image/webp"]);
const lyricsTypes = new Set([
  "text/plain",
  "application/octet-stream",
  "application/x-subrip",
]);

export interface UploadedMusicFile {
  originalname: string;
  mimetype: string;
  size: number;
  buffer: Buffer;
}

export interface MusicTrackFiles {
  audio?: UploadedMusicFile[];
  cover?: UploadedMusicFile[];
  lyricsFile?: UploadedMusicFile[];
}

export interface MusicTrackView {
  id: string;
  title: string;
  artist: string | null;
  album: string | null;
  audioUrl: string;
  coverUrl: string | null;
  lyrics: string | null;
  originalName: string;
  mimeType: string;
  size: number;
  durationSeconds: number | null;
  enabled: boolean;
  sortOrder: number;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
}

@Injectable()
export class MusicService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService<AppConfig, true>,
    private readonly objectStorage: ObjectStorageService,
  ) {}

  async create(
    dto: CreateMusicTrackDto,
    files: MusicTrackFiles,
    createdBy: string,
  ): Promise<MusicTrackView> {
    const audio = files.audio?.[0];
    if (!audio) {
      throw new BadRequestException("请选择要上传的音乐文件");
    }
    assertAudio(audio);
    const storedAudio = await this.saveFile(audio, "audio");
    const cover = files.cover?.[0]
      ? await this.saveOptionalCover(files.cover[0])
      : null;
    const lyrics = this.resolveLyrics(dto.lyrics, files.lyricsFile?.[0]);

    const track = await this.prisma.musicTrack.create({
      data: {
        title: normalizeRequiredText(dto.title, "歌曲名称不能为空"),
        artist: normalizeNullableText(dto.artist),
        album: normalizeNullableText(dto.album),
        audioPath: storedAudio.path,
        coverPath: cover?.path ?? null,
        lyrics,
        originalName: audio.originalname,
        mimeType: audio.mimetype,
        size: audio.size,
        enabled: parseBoolean(dto.enabled, true),
        sortOrder: dto.sortOrder ?? 0,
        createdBy,
      },
    });
    return this.toView(track);
  }

  async update(
    id: string,
    dto: UpdateMusicTrackDto,
    files: MusicTrackFiles,
  ): Promise<MusicTrackView> {
    const existing = await this.find(id);
    const data: Prisma.MusicTrackUpdateInput = {};
    const oldPaths: string[] = [];

    if (dto.title !== undefined) {
      data.title = normalizeRequiredText(dto.title, "歌曲名称不能为空");
    }
    if (dto.artist !== undefined) {
      data.artist = normalizeNullableText(dto.artist);
    }
    if (dto.album !== undefined) {
      data.album = normalizeNullableText(dto.album);
    }
    if (dto.enabled !== undefined) {
      data.enabled = parseBoolean(dto.enabled, existing.enabled);
    }
    if (dto.sortOrder !== undefined) {
      data.sortOrder = dto.sortOrder;
    }
    if (dto.lyrics !== undefined || files.lyricsFile?.[0]) {
      data.lyrics = this.resolveLyrics(dto.lyrics, files.lyricsFile?.[0]);
    }

    const audio = files.audio?.[0];
    if (audio) {
      assertAudio(audio);
      const stored = await this.saveFile(audio, "audio");
      data.audioPath = stored.path;
      data.originalName = audio.originalname;
      data.mimeType = audio.mimetype;
      data.size = audio.size;
      oldPaths.push(existing.audioPath);
    }

    const coverFile = files.cover?.[0];
    if (coverFile) {
      const cover = await this.saveOptionalCover(coverFile);
      data.coverPath = cover.path;
      if (existing.coverPath) {
        oldPaths.push(existing.coverPath);
      }
    }

    const track = await this.prisma.musicTrack.update({
      where: { id },
      data,
    });
    await this.deleteUnused(oldPaths);
    return this.toView(track);
  }

  async list(query: MusicQueryDto, publicOnly = false) {
    const where: Prisma.MusicTrackWhereInput = {
      ...(publicOnly ? { enabled: true } : {}),
      ...(query.enabled !== undefined && !publicOnly
        ? { enabled: query.enabled === "true" }
        : {}),
      ...(query.keyword
        ? {
            OR: [
              { title: { contains: query.keyword } },
              { artist: { contains: query.keyword } },
              { album: { contains: query.keyword } },
              { originalName: { contains: query.keyword } },
            ],
          }
        : {}),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.musicTrack.findMany({
        where,
        orderBy: [{ sortOrder: "asc" }, { createdAt: "desc" }],
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
      }),
      this.prisma.musicTrack.count({ where }),
    ]);
    return {
      items: items.map((item) => this.toView(item)),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  async get(id: string, publicOnly = false): Promise<MusicTrackView> {
    const track = await this.find(id);
    if (publicOnly && !track.enabled) {
      throw new NotFoundException("音乐不存在");
    }
    return this.toView(track);
  }

  async readAudio(id: string) {
    const track = await this.find(id);
    if (!track.enabled) {
      throw new NotFoundException("音乐不存在");
    }
    const file = await this.objectStorage.readObject({
      locator: track.audioPath,
      contentType: track.mimeType,
      fileName: track.originalName,
    });
    return {
      fileName: track.originalName || file.fileName,
      contentType: file.contentType,
      bytes: file.bytes,
    };
  }

  async readCover(id: string) {
    const track = await this.find(id);
    if (!track.enabled || !track.coverPath) {
      throw new NotFoundException("封面不存在");
    }
    return this.objectStorage.readObject({
      locator: track.coverPath,
      contentType: contentTypeFromCoverExt(extname(track.coverPath)),
    });
  }

  async remove(id: string): Promise<{ success: true }> {
    const track = await this.find(id);
    await this.prisma.musicTrack.delete({ where: { id } });
    await this.deleteUnused(
      track.coverPath ? [track.audioPath, track.coverPath] : [track.audioPath],
    );
    return { success: true };
  }

  private async find(id: string) {
    const track = await this.prisma.musicTrack.findUnique({ where: { id } });
    if (!track) {
      throw new NotFoundException("音乐不存在");
    }
    return track;
  }

  private resolveLyrics(
    text: string | undefined,
    file: UploadedMusicFile | undefined,
  ): string | null {
    if (file) {
      assertLyrics(file);
      return file.buffer.toString("utf8").trim() || null;
    }
    return normalizeNullableText(text);
  }

  private saveOptionalCover(file: UploadedMusicFile) {
    assertCover(file);
    return this.saveFile(file, "cover");
  }

  private async saveFile(file: UploadedMusicFile, kind: "audio" | "cover") {
    const now = new Date();
    const year = String(now.getFullYear());
    const month = String(now.getMonth() + 1).padStart(2, "0");
    const hash = createHash("sha256").update(file.buffer).digest("hex");
    const ext =
      kind === "audio" ? normalizedAudioExt(file) : normalizedCoverExt(file);
    const fileName = `${kind}-${hash.slice(0, 24)}-${Date.now()}${ext}`;
    const storageRoot = this.configService.get("storageRoot", { infer: true });
    const key = ["uploads", "music", kind, year, month, fileName].join("/");
    const localPath = resolveStoragePath(
      storageRoot,
      "uploads",
      "music",
      kind,
      year,
      month,
      fileName,
    );
    const stored = await this.objectStorage.putObject({
      key,
      localPath,
      buffer: file.buffer,
      contentType: file.mimetype,
    });
    return { path: stored.locator };
  }

  private async deleteUnused(paths: string[]): Promise<void> {
    for (const path of paths) {
      await this.objectStorage.deleteObject(path);
    }
  }

  private toView(track: MusicTrack): MusicTrackView {
    return {
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      audioUrl: this.publicApiUrl(`/api/v1/music/tracks/${track.id}/audio`),
      coverUrl: track.coverPath
        ? this.publicApiUrl(`/api/v1/music/tracks/${track.id}/cover`)
        : null,
      lyrics: track.lyrics,
      originalName: track.originalName,
      mimeType: track.mimeType,
      size: track.size,
      durationSeconds: track.durationSeconds,
      enabled: track.enabled,
      sortOrder: track.sortOrder,
      createdBy: track.createdBy,
      createdAt: track.createdAt.toISOString(),
      updatedAt: track.updatedAt.toISOString(),
    };
  }

  private publicApiUrl(path: string): string {
    const baseUrl = this.configService
      .get("publicBaseUrl", { infer: true })
      .replace(/\/+$/g, "");
    return baseUrl ? `${baseUrl}${path}` : path;
  }
}

function assertAudio(file: UploadedMusicFile): void {
  if (!audioTypes.has(file.mimetype)) {
    throw new BadRequestException("仅支持 MP3、AAC、WAV、FLAC、OGG、WebM 音频");
  }
  if (file.size > maxAudioBytes) {
    throw new BadRequestException("单个音乐文件不能超过 80MB");
  }
}

function assertCover(file: UploadedMusicFile): void {
  if (!coverTypes.has(file.mimetype)) {
    throw new BadRequestException("封面仅支持 JPG、PNG、WebP 图片");
  }
  if (file.size > maxCoverBytes) {
    throw new BadRequestException("封面不能超过 5MB");
  }
}

function assertLyrics(file: UploadedMusicFile): void {
  const lowerName = file.originalname.toLowerCase();
  if (
    !lyricsTypes.has(file.mimetype) &&
    !lowerName.endsWith(".lrc") &&
    !lowerName.endsWith(".txt")
  ) {
    throw new BadRequestException("歌词仅支持 LRC 或 TXT 文件");
  }
  if (file.size > maxLyricsBytes) {
    throw new BadRequestException("歌词文件不能超过 512KB");
  }
}

function parseBoolean(value: string | undefined, fallback: boolean): boolean {
  if (value === undefined) {
    return fallback;
  }
  return value === "true";
}

function normalizeRequiredText(value: string, message: string): string {
  const text = value.trim();
  if (!text) {
    throw new BadRequestException(message);
  }
  return text;
}

function normalizeNullableText(value: string | undefined): string | null {
  const text = value?.trim();
  return text ? text : null;
}

function normalizedAudioExt(file: UploadedMusicFile): string {
  const ext = extname(file.originalname).toLowerCase();
  if (
    [".mp3", ".m4a", ".aac", ".wav", ".flac", ".ogg", ".webm"].includes(ext)
  ) {
    return ext;
  }
  if (file.mimetype === "audio/mp4" || file.mimetype === "audio/aac") {
    return ".m4a";
  }
  if (file.mimetype.includes("wav")) {
    return ".wav";
  }
  if (file.mimetype.includes("flac")) {
    return ".flac";
  }
  if (file.mimetype.includes("ogg")) {
    return ".ogg";
  }
  if (file.mimetype.includes("webm")) {
    return ".webm";
  }
  return ".mp3";
}

function normalizedCoverExt(file: UploadedMusicFile): string {
  const ext = extname(file.originalname).toLowerCase();
  if ([".jpg", ".jpeg", ".png", ".webp"].includes(ext)) {
    return ext;
  }
  if (file.mimetype === "image/png") {
    return ".png";
  }
  if (file.mimetype === "image/webp") {
    return ".webp";
  }
  return ".jpg";
}

function contentTypeFromCoverExt(ext: string): string {
  if (ext === ".png") {
    return "image/png";
  }
  if (ext === ".webp") {
    return "image/webp";
  }
  return "image/jpeg";
}
