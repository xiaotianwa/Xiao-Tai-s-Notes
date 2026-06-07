import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { MediaAsset, Prisma } from "@prisma/client";
import {
  createHash,
  createHmac,
  randomBytes,
  timingSafeEqual,
} from "node:crypto";
import { extname, join } from "node:path";
import type { Request } from "express";
import sharp from "sharp";

import type { AuthUser } from "../auth/auth-user";
import { ObjectStorageService } from "../common/object-storage/object-storage.service";
import { getClientIp, getUserAgent } from "../common/request-context";
import { resolveStoragePath } from "../common/storage-path";
import type { AppConfig } from "../config/configuration";
import { PrismaService } from "../common/prisma/prisma.service";
import type { MediaListQueryDto, UploadMediaDto } from "./dto/media.dto";

const mediaThumbSize = 160;
const mediaThumbQuality = 72;
const mediaDownloadTicketTtlMs = 5 * 60 * 1000;

export interface UploadedMediaFile {
  originalname: string;
  mimetype: string;
  size: number;
  buffer: Buffer;
}

export interface MediaAssetView {
  id: string;
  userId: string;
  username: string;
  nickname: string;
  deviceId: string | null;
  originalName: string;
  mimeType: string;
  size: number;
  sha256: string;
  fileUrl: string;
  thumbUrl: string;
  takenAt: string | null;
  uploadedAt: string;
  deletedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface MediaDownloadTicketView {
  url: string;
  expiresAt: string;
}

@Injectable()
export class MediaService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService<AppConfig, true>,
    private readonly objectStorage: ObjectStorageService,
  ) {}

  async upload(
    user: AuthUser,
    input: UploadMediaDto,
    file: UploadedMediaFile | undefined,
  ): Promise<MediaAssetView> {
    if (!file) {
      throw new BadRequestException("请选择要上传的图片或视频");
    }
    this.assertSupportedMedia(file);
    const takenAt = input.takenAt ? new Date(input.takenAt) : null;
    if (input.takenAt && Number.isNaN(takenAt?.getTime())) {
      throw new BadRequestException("takenAt 不是有效时间");
    }

    const spaceId = await this.ensurePersonalSpace(user);
    const deviceId = await this.resolveDeviceId(user, input.deviceId);
    const storage = await this.saveMediaFile(file);
    const asset = await this.prisma.mediaAsset.create({
      data: {
        userId: user.id,
        spaceId,
        deviceId,
        originalName: file.originalname,
        mimeType: file.mimetype,
        size: file.size,
        sha256: storage.sha256,
        filePath: storage.path,
        thumbPath: storage.thumbPath,
        takenAt,
      },
      include: { user: { select: this.userSelect() } },
    });
    return this.toView(asset);
  }

  async listForUser(
    user: AuthUser,
    query: MediaListQueryDto,
  ): Promise<{
    items: MediaAssetView[];
    total: number;
    page: number;
    pageSize: number;
  }> {
    return this.list({ ...query, userId: user.id, deleted: "false" });
  }

  async list(query: MediaListQueryDto): Promise<{
    items: MediaAssetView[];
    total: number;
    page: number;
    pageSize: number;
  }> {
    const where: Prisma.MediaAssetWhereInput = {
      ...(query.userId ? { userId: query.userId } : {}),
      ...(query.deleted === "true"
        ? { deletedAt: { not: null } }
        : query.deleted === "false"
          ? { deletedAt: null }
          : {}),
      ...(query.keyword
        ? {
            OR: [
              { originalName: { contains: query.keyword } },
              { sha256: { contains: query.keyword } },
            ],
          }
        : {}),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.mediaAsset.findMany({
        where,
        include: { user: { select: this.userSelect() } },
        orderBy: { uploadedAt: "desc" },
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
      }),
      this.prisma.mediaAsset.count({ where }),
    ]);
    return {
      items: items.map((item) => this.toView(item)),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  async get(
    id: string,
    user: AuthUser,
    request?: Request,
  ): Promise<MediaAssetView> {
    const asset = await this.findVisible(id);
    this.assertOwnerOrAdmin(asset, user);
    if (user.role === "admin" && request) {
      await this.recordAudit(user, request, {
        action: "admin.media.view",
        targetId: id,
        metadata: { userId: asset.userId, mimeType: asset.mimeType },
      });
    }
    return this.toView(asset);
  }

  async readFile(
    id: string,
    user: AuthUser,
    request?: Request,
    thumb = false,
  ): Promise<{ fileName: string; contentType: string; bytes: Buffer }> {
    const asset = await this.findVisible(id);
    this.assertOwnerOrAdmin(asset, user);
    if (user.role === "admin" && request && !thumb) {
      await this.recordAudit(user, request, {
        action: "admin.media.download",
        targetId: id,
        metadata: { userId: asset.userId, thumb },
      });
    }
    const thumbPath = thumb ? await this.ensureThumbnail(asset) : null;
    const path = thumb ? (thumbPath ?? asset.filePath) : asset.filePath;
    const contentType = thumbPath ? "image/webp" : asset.mimeType;
    const file = await this.objectStorage.readObject({
      locator: path,
      contentType,
    });
    return {
      fileName: file.fileName,
      contentType: file.contentType,
      bytes: file.bytes,
    };
  }

  async createAdminDownloadTicket(
    id: string,
    user: AuthUser,
    request: Request,
  ): Promise<MediaDownloadTicketView> {
    if (user.role !== "admin") {
      throw new ForbiddenException("仅管理员可下载媒体文件");
    }
    const asset = await this.findVisible(id);
    await this.recordAudit(user, request, {
      action: "admin.media.download.ticket",
      targetId: id,
      metadata: { userId: asset.userId, mimeType: asset.mimeType },
    });
    const expiresAt = Date.now() + mediaDownloadTicketTtlMs;
    const nonce = randomBytes(12).toString("base64url");
    const payload = `${asset.id}.${expiresAt}.${nonce}`;
    const signature = this.signDownloadPayload(payload);
    const ticket = `${Buffer.from(payload, "utf8").toString("base64url")}.${signature}`;
    return {
      url: `/api/v1/admin/media-downloads/${ticket}`,
      expiresAt: new Date(expiresAt).toISOString(),
    };
  }

  async readFileByDownloadTicket(
    ticket: string,
  ): Promise<{ fileName: string; contentType: string; bytes: Buffer }> {
    const assetId = this.verifyDownloadTicket(ticket);
    const asset = await this.findVisible(assetId);
    const file = await this.objectStorage.readObject({
      locator: asset.filePath,
      contentType: asset.mimeType,
    });
    return {
      fileName: asset.originalName || file.fileName,
      contentType: file.contentType,
      bytes: file.bytes,
    };
  }

  async remove(
    id: string,
    user: AuthUser,
    request?: Request,
  ): Promise<{ deleted: true }> {
    const asset = await this.findVisible(id);
    this.assertOwnerOrAdmin(asset, user);
    await this.prisma.mediaAsset.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
    await this.deleteStoredFilesIfUnused(asset);
    if (user.role === "admin" && request) {
      await this.recordAudit(user, request, {
        action: "admin.media.delete",
        targetId: id,
        metadata: { userId: asset.userId },
      });
    }
    return { deleted: true };
  }

  private async findVisible(id: string) {
    const asset = await this.prisma.mediaAsset.findUnique({
      where: { id },
      include: { user: { select: this.userSelect() } },
    });
    if (!asset || asset.deletedAt) {
      throw new NotFoundException("媒体不存在");
    }
    return asset;
  }

  private assertOwnerOrAdmin(asset: MediaAsset, user: AuthUser): void {
    if (user.role === "admin" || asset.userId === user.id) {
      return;
    }
    throw new ForbiddenException("无权访问该媒体");
  }

  private assertSupportedMedia(file: UploadedMediaFile): void {
    const allowed = new Set([
      "image/jpeg",
      "image/png",
      "image/webp",
      "image/heic",
      "image/heif",
      "image/gif",
      "video/mp4",
      "video/quicktime",
      "video/webm",
      "video/3gpp",
      "video/x-matroska",
    ]);
    if (!allowed.has(file.mimetype)) {
      throw new BadRequestException(
        "仅支持 JPG、PNG、WebP、HEIC、HEIF、GIF 图片和 MP4、MOV、WebM、3GP、MKV 视频",
      );
    }
    if (file.size > 500 * 1024 * 1024) {
      throw new BadRequestException("单个媒体文件不能超过 500MB");
    }
  }

  private async ensurePersonalSpace(user: AuthUser): Promise<string> {
    const existing = await this.prisma.spaceMember.findFirst({
      where: { userId: user.id },
      orderBy: { createdAt: "asc" },
      select: { spaceId: true },
    });
    if (existing) {
      return existing.spaceId;
    }
    const space = await this.prisma.space.create({
      data: {
        name: `${user.nickname}的空间`,
        members: { create: { userId: user.id, role: "owner" } },
      },
      select: { id: true },
    });
    return space.id;
  }

  private async resolveDeviceId(
    user: AuthUser,
    deviceId: string | undefined,
  ): Promise<string | null> {
    if (!deviceId) {
      return null;
    }
    const device = await this.prisma.device.findFirst({
      where: { id: deviceId, userId: user.id },
      select: { id: true },
    });
    return device?.id ?? null;
  }

  private async saveMediaFile(
    file: UploadedMediaFile,
  ): Promise<{ path: string; sha256: string; thumbPath: string | null }> {
    const storageRoot = this.configService.get("storageRoot", { infer: true });
    const now = new Date();
    const year = String(now.getFullYear());
    const month = String(now.getMonth() + 1).padStart(2, "0");
    const mediaDir = resolveStoragePath(
      storageRoot,
      "uploads",
      "media",
      year,
      month,
    );
    const sha256 = createHash("sha256").update(file.buffer).digest("hex");
    const ext = normalizedMediaExt(file);
    const target = join(mediaDir, `${sha256}${ext}`);
    const stored = await this.objectStorage.putObject({
      key: ["uploads", "media", year, month, `${sha256}${ext}`].join("/"),
      localPath: target,
      buffer: file.buffer,
      contentType: file.mimetype,
    });
    const thumbPath = await this.createThumbnailObject(
      file.buffer,
      file.mimetype,
      sha256,
      year,
      month,
    );
    return { path: stored.locator, sha256, thumbPath };
  }

  private async ensureThumbnail(asset: MediaAsset): Promise<string | null> {
    if (!isImageMimeType(asset.mimeType)) {
      return null;
    }
    if (asset.thumbPath && asset.thumbPath !== asset.filePath) {
      return asset.thumbPath;
    }

    const original = await this.objectStorage.readObject({
      locator: asset.filePath,
      contentType: asset.mimeType,
    });
    const year = String(asset.uploadedAt.getFullYear());
    const month = String(asset.uploadedAt.getMonth() + 1).padStart(2, "0");
    const thumbPath = await this.createThumbnailObject(
      original.bytes,
      asset.mimeType,
      asset.sha256,
      year,
      month,
    );
    if (!thumbPath) {
      return null;
    }
    await this.prisma.mediaAsset.update({
      where: { id: asset.id },
      data: { thumbPath },
    });
    return thumbPath;
  }

  private async createThumbnailObject(
    buffer: Buffer,
    mimeType: string,
    sha256: string,
    year: string,
    month: string,
  ): Promise<string | null> {
    if (!isImageMimeType(mimeType)) {
      return null;
    }

    const storageRoot = this.configService.get("storageRoot", { infer: true });
    const fileName = `${sha256}.webp`;
    const key = ["uploads", "media-thumbs", year, month, fileName].join("/");
    const localPath = resolveStoragePath(
      storageRoot,
      "uploads",
      "media-thumbs",
      year,
      month,
      fileName,
    );

    try {
      const thumbBuffer = await sharp(buffer, { animated: false })
        .rotate()
        .resize(mediaThumbSize, mediaThumbSize, {
          fit: "cover",
          withoutEnlargement: true,
        })
        .webp({ quality: mediaThumbQuality })
        .toBuffer();
      const stored = await this.objectStorage.putObject({
        key,
        localPath,
        buffer: thumbBuffer,
        contentType: "image/webp",
      });
      return stored.locator;
    } catch {
      return null;
    }
  }

  private async recordAudit(
    actor: AuthUser,
    request: Request,
    input: {
      action: string;
      targetId: string;
      metadata?: Record<string, unknown>;
    },
  ): Promise<void> {
    await this.prisma.auditLog.create({
      data: {
        actorUserId: actor.id,
        action: input.action,
        targetType: "media_asset",
        targetId: input.targetId,
        ip: getClientIp(request),
        userAgent: getUserAgent(request),
        metadataJson: input.metadata ? JSON.stringify(input.metadata) : null,
      },
    });
  }

  private async deleteStoredFilesIfUnused(asset: MediaAsset): Promise<void> {
    const paths = [
      ...new Set(
        asset.thumbPath ? [asset.filePath, asset.thumbPath] : [asset.filePath],
      ),
    ];
    const sharedAssets = await this.prisma.mediaAsset.findMany({
      where: {
        id: { not: asset.id },
        deletedAt: null,
        OR: [{ filePath: { in: paths } }, { thumbPath: { in: paths } }],
      },
      select: { filePath: true, thumbPath: true },
    });
    const sharedPaths = new Set(
      sharedAssets.flatMap((item) =>
        item.thumbPath ? [item.filePath, item.thumbPath] : [item.filePath],
      ),
    );
    for (const path of paths) {
      if (!sharedPaths.has(path)) {
        await this.objectStorage.deleteObject(path);
      }
    }
  }

  private toView(
    asset: MediaAsset & {
      user: {
        id: string;
        username: string;
        nickname: string;
      };
    },
  ): MediaAssetView {
    return {
      id: asset.id,
      userId: asset.userId,
      username: asset.user.username,
      nickname: asset.user.nickname,
      deviceId: asset.deviceId,
      originalName: asset.originalName,
      mimeType: asset.mimeType,
      size: asset.size,
      sha256: asset.sha256,
      fileUrl: `/api/v1/media/${asset.id}/file`,
      thumbUrl: `/api/v1/media/${asset.id}/thumb`,
      takenAt: asset.takenAt?.toISOString() ?? null,
      uploadedAt: asset.uploadedAt.toISOString(),
      deletedAt: asset.deletedAt?.toISOString() ?? null,
      createdAt: asset.createdAt.toISOString(),
      updatedAt: asset.updatedAt.toISOString(),
    };
  }

  private userSelect(): Prisma.UserSelect {
    return {
      id: true,
      username: true,
      nickname: true,
    };
  }

  private signDownloadPayload(payload: string): string {
    return createHmac(
      "sha256",
      this.configService.get("jwtAccessSecret", { infer: true }),
    )
      .update(payload)
      .digest("base64url");
  }

  private verifyDownloadTicket(ticket: string): string {
    const [encodedPayload, signature] = ticket.split(".");
    if (!encodedPayload || !signature) {
      throw new ForbiddenException("下载链接无效");
    }

    let payload: string;
    try {
      payload = Buffer.from(encodedPayload, "base64url").toString("utf8");
    } catch {
      throw new ForbiddenException("下载链接无效");
    }

    const expected = this.signDownloadPayload(payload);
    const providedBuffer = Buffer.from(signature, "base64url");
    const expectedBuffer = Buffer.from(expected, "base64url");
    if (
      providedBuffer.length !== expectedBuffer.length ||
      !timingSafeEqual(providedBuffer, expectedBuffer)
    ) {
      throw new ForbiddenException("下载链接无效");
    }

    const [assetId, expiresAtText] = payload.split(".");
    const expiresAt = Number(expiresAtText);
    if (!assetId || !Number.isFinite(expiresAt) || Date.now() > expiresAt) {
      throw new ForbiddenException("下载链接已过期");
    }
    return assetId;
  }
}

function normalizedMediaExt(file: UploadedMediaFile): string {
  const ext = extname(file.originalname).toLowerCase();
  if (
    [
      ".jpg",
      ".jpeg",
      ".png",
      ".webp",
      ".heic",
      ".heif",
      ".gif",
      ".mp4",
      ".mov",
      ".webm",
      ".3gp",
      ".mkv",
    ].includes(ext)
  ) {
    return ext;
  }
  if (file.mimetype === "image/png") {
    return ".png";
  }
  if (file.mimetype === "image/webp") {
    return ".webp";
  }
  if (file.mimetype === "image/heic") {
    return ".heic";
  }
  if (file.mimetype === "image/heif") {
    return ".heif";
  }
  if (file.mimetype === "image/gif") {
    return ".gif";
  }
  if (file.mimetype === "video/quicktime") {
    return ".mov";
  }
  if (file.mimetype === "video/webm") {
    return ".webm";
  }
  if (file.mimetype === "video/3gpp") {
    return ".3gp";
  }
  if (file.mimetype === "video/x-matroska") {
    return ".mkv";
  }
  if (file.mimetype.startsWith("video/")) {
    return ".mp4";
  }
  return ".jpg";
}

function isImageMimeType(mimeType: string): boolean {
  return mimeType.startsWith("image/");
}
