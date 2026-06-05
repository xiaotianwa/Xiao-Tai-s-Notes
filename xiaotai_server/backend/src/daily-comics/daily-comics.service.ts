import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { createHash } from "node:crypto";
import { extname, join } from "node:path";

import { ObjectStorageService } from "../common/object-storage/object-storage.service";
import { PrismaService } from "../common/prisma/prisma.service";
import { resolveStoragePath } from "../common/storage-path";
import type { AppConfig } from "../config/configuration";
import { CreateDailyComicDto } from "./dto/create-daily-comic.dto";
import { QueryDailyComicsDto } from "./dto/query-daily-comics.dto";
import { UpdateDailyComicDto } from "./dto/update-daily-comic.dto";

const maxComicImages = 10;
const maxImageBytes = 5 * 1024 * 1024;
const allowedImageTypes = new Set(["image/jpeg", "image/png", "image/webp"]);
const imagePathPattern = /^\/api\/v1\/daily-comics\/images\/[\w.-]+$/;

export interface UploadedDailyComicImage {
  originalname: string;
  mimetype: string;
  size: number;
  buffer: Buffer;
}

export interface DailyComicImageInput {
  imageUrl: string;
  originalName?: string;
  mimeType?: string;
  size?: number;
}

interface NormalizedDailyComicImage {
  imageUrl: string;
  originalName?: string;
  mimeType?: string;
  size?: number;
  sortOrder: number;
}

@Injectable()
export class DailyComicsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService<AppConfig, true>,
    private readonly objectStorage: ObjectStorageService,
  ) {}

  async create(dto: CreateDailyComicDto, createdBy: string) {
    const images = normalizeDailyComicImages(dto.images);
    const publishDate = parseDailyComicPublishDate(dto.publishDate);

    try {
      return await this.prisma.dailyComic.create({
        data: {
          title: dto.title.trim(),
          description: normalizeText(dto.description),
          publishDate,
          enabled: dto.enabled ?? true,
          createdBy,
          images: {
            create: images,
          },
        },
        include: comicImagesInclude(),
      });
    } catch (error) {
      if (isUniqueConstraintError(error)) {
        throw new ConflictException("该日期已经存在每日漫画，请直接编辑原内容");
      }
      throw error;
    }
  }

  async findAll(query: QueryDailyComicsDto) {
    const { page = 1, pageSize = 20, keyword, enabled } = query;
    const skip = (page - 1) * pageSize;
    const where: Record<string, unknown> = {};

    if (keyword) {
      where.OR = [
        { title: { contains: keyword } },
        { description: { contains: keyword } },
      ];
    }

    if (enabled !== undefined) {
      where.enabled = enabled === "true";
    }

    const [items, total] = await Promise.all([
      this.prisma.dailyComic.findMany({
        where,
        skip,
        take: pageSize,
        orderBy: [{ publishDate: "desc" }, { createdAt: "desc" }],
        include: comicImagesInclude(),
      }),
      this.prisma.dailyComic.count({ where }),
    ]);

    return {
      items,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  async findLatest() {
    const today = dailyComicPublishCutoff();
    return this.prisma.dailyComic.findFirst({
      where: {
        enabled: true,
        publishDate: { lte: today },
        images: { some: {} },
      },
      orderBy: [{ publishDate: "desc" }, { createdAt: "desc" }],
      include: comicImagesInclude(),
    });
  }

  async findPublished(query: QueryDailyComicsDto) {
    const { page = 1, pageSize = 20 } = query;
    const skip = (page - 1) * pageSize;
    const where = {
      enabled: true,
      publishDate: { lte: dailyComicPublishCutoff() },
      images: { some: {} },
    };

    const [items, total] = await Promise.all([
      this.prisma.dailyComic.findMany({
        where,
        skip,
        take: pageSize,
        orderBy: [{ publishDate: "desc" }, { createdAt: "desc" }],
        include: comicImagesInclude(),
      }),
      this.prisma.dailyComic.count({ where }),
    ]);

    return {
      items,
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  async findOne(id: string) {
    const comic = await this.prisma.dailyComic.findUnique({
      where: { id },
      include: comicImagesInclude(),
    });
    if (!comic) {
      throw new NotFoundException("每日漫画不存在");
    }
    return comic;
  }

  async update(id: string, dto: UpdateDailyComicDto) {
    await this.ensureExists(id);

    const data: Record<string, unknown> = {};
    if (dto.title !== undefined) {
      data.title = dto.title.trim();
    }
    if (dto.description !== undefined) {
      data.description = normalizeText(dto.description);
    }
    if (dto.publishDate !== undefined) {
      data.publishDate = parseDailyComicPublishDate(dto.publishDate);
    }
    if (dto.enabled !== undefined) {
      data.enabled = dto.enabled;
    }
    if (dto.images !== undefined) {
      data.images = {
        deleteMany: {},
        create: normalizeDailyComicImages(dto.images),
      };
    }

    try {
      return await this.prisma.dailyComic.update({
        where: { id },
        data,
        include: comicImagesInclude(),
      });
    } catch (error) {
      if (isUniqueConstraintError(error)) {
        throw new ConflictException("该日期已经存在每日漫画，请选择其他日期");
      }
      throw error;
    }
  }

  async remove(id: string) {
    await this.ensureExists(id);
    return this.prisma.dailyComic.delete({
      where: { id },
    });
  }

  async uploadImage(file: UploadedDailyComicImage | undefined) {
    if (!file) {
      throw new BadRequestException("请选择要上传的漫画图片");
    }
    assertImage(file);

    const storageRoot = this.configService.get("storageRoot", { infer: true });
    const imageDir = resolveStoragePath(storageRoot, "daily-comics");

    const hash = createHash("sha256").update(file.buffer).digest("hex");
    const fileName = `comic-${hash.slice(0, 20)}-${Date.now()}${normalizedImageExt(
      file,
    )}`;
    await this.objectStorage.putObject({
      key: `daily-comics/${fileName}`,
      localPath: join(imageDir, fileName),
      buffer: file.buffer,
      contentType: file.mimetype,
    });

    return {
      imageUrl: `/api/v1/daily-comics/images/${fileName}`,
      originalName: file.originalname,
      mimeType: file.mimetype,
      size: file.size,
    };
  }

  async readImage(fileName: string) {
    if (!/^[\w.-]+$/.test(fileName)) {
      throw new NotFoundException("图片不存在");
    }
    const storageRoot = this.configService.get("storageRoot", { infer: true });
    const imagePath = resolveStoragePath(storageRoot, "daily-comics", fileName);
    const file = await this.objectStorage.readObject({
      key: `daily-comics/${fileName}`,
      localPath: imagePath,
      fileName,
      contentType: contentTypeFromExt(extname(imagePath)),
    });
    return file;
  }

  private async ensureExists(id: string): Promise<void> {
    const existing = await this.prisma.dailyComic.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!existing) {
      throw new NotFoundException("每日漫画不存在");
    }
  }
}

export function normalizeDailyComicImages(
  images: DailyComicImageInput[] | undefined,
): NormalizedDailyComicImage[] {
  if (!images || images.length === 0) {
    throw new BadRequestException("每日漫画至少需要上传 1 张图片");
  }
  if (images.length > maxComicImages) {
    throw new BadRequestException("每日漫画最多只能上传 10 张图片");
  }

  const seenUrls = new Set<string>();
  return images.map((image, index) => {
    const imageUrl = image.imageUrl.trim();
    if (!imagePathPattern.test(imageUrl)) {
      throw new BadRequestException("漫画图片必须先通过管理端上传");
    }
    if (seenUrls.has(imageUrl)) {
      throw new BadRequestException("漫画图片不能重复添加");
    }
    seenUrls.add(imageUrl);
    return {
      imageUrl,
      originalName: normalizeText(image.originalName),
      mimeType: normalizeText(image.mimeType),
      size: image.size,
      sortOrder: index,
    };
  });
}

export function parseDailyComicPublishDate(value: string): Date {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new BadRequestException("发布日期格式必须为 YYYY-MM-DD");
  }
  const date = new Date(`${value}T00:00:00.000Z`);
  if (
    Number.isNaN(date.getTime()) ||
    date.toISOString().slice(0, 10) !== value
  ) {
    throw new BadRequestException("发布日期不是有效日期");
  }
  return date;
}

export function dailyComicPublishCutoff(now = new Date()): Date {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Shanghai",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  })
    .formatToParts(now)
    .reduce<Record<string, string>>((result, part) => {
      if (part.type !== "literal") {
        result[part.type] = part.value;
      }
      return result;
    }, {});
  return parseDailyComicPublishDate(
    `${parts.year}-${parts.month}-${parts.day}`,
  );
}

function normalizeText(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

function comicImagesInclude() {
  return {
    images: {
      orderBy: { sortOrder: "asc" as const },
    },
  };
}

function isUniqueConstraintError(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: string }).code === "P2002"
  );
}

function assertImage(file: UploadedDailyComicImage): void {
  if (!allowedImageTypes.has(file.mimetype)) {
    throw new BadRequestException("仅支持 JPG、PNG、WebP 图片");
  }
  if (file.size > maxImageBytes) {
    throw new BadRequestException("漫画图片不能超过 5MB");
  }
}

function normalizedImageExt(file: UploadedDailyComicImage): string {
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
