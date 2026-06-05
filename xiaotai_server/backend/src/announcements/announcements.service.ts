import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Prisma } from "@prisma/client";
import { createHash } from "node:crypto";
import { extname, join } from "node:path";
import { ObjectStorageService } from "../common/object-storage/object-storage.service";
import { PrismaService } from "../common/prisma/prisma.service";
import { resolveStoragePath } from "../common/storage-path";
import type { AppConfig } from "../config/configuration";
import { CreateAnnouncementDto } from "./dto/create-announcement.dto";
import { UpdateAnnouncementDto } from "./dto/update-announcement.dto";
import { QueryAnnouncementsDto } from "./dto/query-announcements.dto";

export interface UploadedAnnouncementImage {
  originalname: string;
  mimetype: string;
  size: number;
  buffer: Buffer;
}

@Injectable()
export class AnnouncementsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService<AppConfig, true>,
    private readonly objectStorage: ObjectStorageService,
  ) {}

  async create(dto: CreateAnnouncementDto, createdBy: string) {
    return this.prisma.announcement.create({
      data: {
        title: dto.title,
        content: dto.content,
        type: dto.type ?? "info",
        priority: dto.priority ?? 0,
        targetUsers: dto.targetUsers,
        imageUrl: dto.imageUrl,
        startAt: dto.startAt ? new Date(dto.startAt) : null,
        endAt: dto.endAt ? new Date(dto.endAt) : null,
        enabled: dto.enabled ?? true,
        createdBy,
      },
    });
  }

  async findAll(query: QueryAnnouncementsDto) {
    const { page = 1, pageSize = 20, keyword, type, enabled } = query;
    const skip = (page - 1) * pageSize;

    const where: Prisma.AnnouncementWhereInput = {};

    if (keyword) {
      where.OR = [
        { title: { contains: keyword } },
        { content: { contains: keyword } },
      ];
    }

    if (type) {
      where.type = type;
    }

    if (enabled !== undefined) {
      where.enabled = enabled === "true";
    }

    const [items, total] = await Promise.all([
      this.prisma.announcement.findMany({
        where,
        skip,
        take: pageSize,
        orderBy: [{ priority: "desc" }, { createdAt: "desc" }],
      }),
      this.prisma.announcement.count({ where }),
    ]);

    return {
      items,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  async findActive(userId?: string) {
    const now = new Date();
    const where: Prisma.AnnouncementWhereInput = {
      enabled: true,
      OR: [
        { startAt: null, endAt: null },
        { startAt: { lte: now }, endAt: null },
        { startAt: null, endAt: { gte: now } },
        { startAt: { lte: now }, endAt: { gte: now } },
      ],
    };

    if (userId) {
      where.AND = [
        {
          OR: [
            { targetUsers: null },
            { targetUsers: "" },
            { targetUsers: { contains: userId } },
          ],
        },
      ];
    } else {
      where.AND = [
        {
          OR: [{ targetUsers: null }, { targetUsers: "" }],
        },
      ];
    }

    return this.prisma.announcement.findMany({
      where,
      orderBy: [{ priority: "desc" }, { createdAt: "desc" }],
    });
  }

  async findOne(id: string) {
    return this.prisma.announcement.findUnique({
      where: { id },
    });
  }

  async update(id: string, dto: UpdateAnnouncementDto) {
    const data: Prisma.AnnouncementUpdateInput = {};

    if (dto.title !== undefined) data.title = dto.title;
    if (dto.content !== undefined) data.content = dto.content;
    if (dto.type !== undefined) data.type = dto.type;
    if (dto.priority !== undefined) data.priority = dto.priority;
    if (dto.targetUsers !== undefined) data.targetUsers = dto.targetUsers;
    if (dto.imageUrl !== undefined) data.imageUrl = dto.imageUrl;
    if (dto.startAt !== undefined)
      data.startAt = dto.startAt ? new Date(dto.startAt) : null;
    if (dto.endAt !== undefined)
      data.endAt = dto.endAt ? new Date(dto.endAt) : null;
    if (dto.enabled !== undefined) data.enabled = dto.enabled;

    return this.prisma.announcement.update({
      where: { id },
      data,
    });
  }

  async remove(id: string) {
    return this.prisma.announcement.delete({
      where: { id },
    });
  }

  async uploadImage(file: UploadedAnnouncementImage | undefined) {
    if (!file) {
      throw new BadRequestException("请选择要上传的公告图片");
    }
    this.assertImage(file);
    const storageRoot = this.configService.get("storageRoot", { infer: true });
    const imageDir = resolveStoragePath(storageRoot, "announcements");
    const hash = createHash("sha256").update(file.buffer).digest("hex");
    const fileName = `announcement-${hash.slice(0, 20)}-${Date.now()}${normalizedImageExt(file)}`;
    await this.objectStorage.putObject({
      key: `announcements/${fileName}`,
      localPath: join(imageDir, fileName),
      buffer: file.buffer,
      contentType: file.mimetype,
    });
    return {
      imageUrl: `/api/v1/announcements/images/${fileName}`,
    };
  }

  async readImage(fileName: string) {
    if (!/^[\w.-]+$/.test(fileName)) {
      throw new NotFoundException("图片不存在");
    }
    const storageRoot = this.configService.get("storageRoot", { infer: true });
    const imagePath = resolveStoragePath(
      storageRoot,
      "announcements",
      fileName,
    );
    const file = await this.objectStorage.readObject({
      key: `announcements/${fileName}`,
      localPath: imagePath,
      fileName,
      contentType: contentTypeFromExt(extname(imagePath)),
    });
    return file;
  }

  private assertImage(file: UploadedAnnouncementImage): void {
    const allowed = new Set(["image/jpeg", "image/png", "image/webp"]);
    if (!allowed.has(file.mimetype)) {
      throw new BadRequestException("仅支持 JPG、PNG、WebP 图片");
    }
    if (file.size > 5 * 1024 * 1024) {
      throw new BadRequestException("公告图片不能超过 5MB");
    }
  }
}

function normalizedImageExt(file: UploadedAnnouncementImage): string {
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

function contentTypeFromExt(ext: string): string {
  if (ext === ".png") {
    return "image/png";
  }
  if (ext === ".webp") {
    return "image/webp";
  }
  return "image/jpeg";
}
