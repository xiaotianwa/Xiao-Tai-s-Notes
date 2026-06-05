import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppVersion, Prisma } from '@prisma/client';
import { createHash } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { mkdir, rm } from 'node:fs/promises';
import { basename, extname, join } from 'node:path';

import type { AuthUser } from '../auth/auth-user';
import type { AppConfig } from '../config/configuration';
import { PrismaService } from '../common/prisma/prisma.service';
import { resolveStoragePath } from '../common/storage-path';
import { ObjectStorageService } from '../common/object-storage/object-storage.service';
import type {
  AdminAppVersionsQueryDto,
  CreateAppVersionDto,
  LatestAppVersionQueryDto,
  UpdateAppVersionDto,
} from './dto/app-version.dto';

export interface UploadedApkFile {
  originalname: string;
  mimetype: string;
  size: number;
  buffer?: Buffer;
  path?: string;
}

export interface AppVersionView {
  id: string;
  platform: string;
  channel: string;
  versionName: string;
  versionCode: number;
  forceUpdate: boolean;
  enabled: boolean;
  apkUrl: string;
  apkSize: number | null;
  sha256: string | null;
  changelog: string | null;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
}

export interface AppVersionApkDownload {
  fileName: string;
  contentType: string;
  localPath?: string;
  redirectUrl?: string;
}

@Injectable()
export class AppVersionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService<AppConfig, true>,
    private readonly objectStorage: ObjectStorageService,
  ) {}

  async latest(query: LatestAppVersionQueryDto): Promise<AppVersionView> {
    const version = await this.prisma.appVersion.findFirst({
      where: {
        platform: query.platform,
        channel: query.channel,
        enabled: true,
      },
      orderBy: [{ versionCode: 'desc' }, { createdAt: 'desc' }],
    });
    if (!version) {
      throw new NotFoundException('暂无可用版本');
    }
    return this.toView(version);
  }

  async list(query: AdminAppVersionsQueryDto): Promise<{
    items: AppVersionView[];
    total: number;
    page: number;
    pageSize: number;
  }> {
    const where: Prisma.AppVersionWhereInput = {
      ...(query.platform ? { platform: query.platform } : {}),
      ...(query.channel ? { channel: query.channel } : {}),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.appVersion.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }],
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
      }),
      this.prisma.appVersion.count({ where }),
    ]);
    return {
      items: items.map((item) => this.toView(item)),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  async create(
    actor: AuthUser,
    input: CreateAppVersionDto,
    file: UploadedApkFile | undefined,
  ): Promise<AppVersionView> {
    if (!file) {
      throw new BadRequestException('请上传 APK 文件');
    }
    if (!file.originalname.toLowerCase().endsWith('.apk')) {
      throw new BadRequestException('只支持上传 APK 文件');
    }
    const versionCode = Number(input.versionCode);
    if (!Number.isInteger(versionCode) || versionCode <= 0) {
      throw new BadRequestException('versionCode 必须是正整数');
    }

    const storage = await this.saveApkFile(input, versionCode, file);
    const version = await this.prisma.appVersion.create({
      data: {
        platform: input.platform,
        channel: input.channel,
        versionName: input.versionName,
        versionCode,
        changelog: input.changelog,
        forceUpdate: parseBoolean(input.forceUpdate),
        enabled: parseBoolean(input.enabled, true),
        apkPath: storage.path,
        apkUrl: '',
        apkSize: file.size,
        sha256: storage.sha256,
        createdBy: actor.id,
      },
    });
    const apkUrl = `/api/v1/app-versions/${version.id}/apk`;
    const updated = await this.prisma.appVersion.update({
      where: { id: version.id },
      data: { apkUrl },
    });
    return this.toView(updated);
  }

  async update(
    id: string,
    input: UpdateAppVersionDto,
  ): Promise<AppVersionView> {
    await this.ensureExists(id);
    const version = await this.prisma.appVersion.update({
      where: { id },
      data: {
        changelog: input.changelog,
        forceUpdate: input.forceUpdate,
        enabled: input.enabled,
      },
    });
    return this.toView(version);
  }

  async remove(id: string): Promise<{ deleted: true }> {
    const version = await this.ensureExists(id);
    await this.prisma.appVersion.delete({ where: { id } });
    if (version.apkPath) {
      await this.objectStorage.deleteObject(version.apkPath).catch(() => {});
    }
    return { deleted: true };
  }

  async getApkDownload(id: string): Promise<AppVersionApkDownload> {
    const version = await this.ensureExists(id);
    if (!version.apkPath) {
      throw new NotFoundException('安装包不存在');
    }
    const fileName = this.objectStorage.fileNameFromLocator(version.apkPath);
    const redirectUrl = this.objectStorage.publicUrl(version.apkPath);
    if (redirectUrl) {
      return {
        fileName,
        contentType: 'application/vnd.android.package-archive',
        redirectUrl,
      };
    }
    return {
      fileName: basename(version.apkPath),
      contentType: 'application/vnd.android.package-archive',
      localPath: version.apkPath,
    };
  }

  private async ensureExists(id: string): Promise<AppVersion> {
    const version = await this.prisma.appVersion.findUnique({ where: { id } });
    if (!version) {
      throw new NotFoundException('版本不存在');
    }
    return version;
  }

  private async saveApkFile(
    input: CreateAppVersionDto,
    versionCode: number,
    file: UploadedApkFile,
  ): Promise<{ path: string; sha256: string }> {
    const storageRoot = this.configService.get('storageRoot', { infer: true });
    const now = new Date();
    const year = String(now.getFullYear());
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const releaseDir = resolveStoragePath(storageRoot, 'releases', year, month);
    await mkdir(releaseDir, { recursive: true });
    const ext = extname(file.originalname) || '.apk';
    const safePlatform = input.platform.replace(/[^\w.-]/g, '_');
    const safeChannel = input.channel.replace(/[^\w.-]/g, '_');
    const fileName = `${safePlatform}-${safeChannel}-${versionCode}-${Date.now()}${ext}`;
    const target = join(releaseDir, fileName);
    const key = ['releases', year, month, fileName].join('/');
    const sha256 = await hashUploadedFile(file);
    const stored = await this.objectStorage
      .putObject({
        key,
        localPath: target,
        buffer: file.buffer,
        sourcePath: file.path,
        contentType: 'application/vnd.android.package-archive',
      })
      .finally(async () => {
        if (file.path) {
          await rm(file.path, { force: true }).catch(() => {});
        }
      });
    if (this.objectStorage.cosEnabled) {
      await rm(target, { force: true }).catch(() => {});
    }
    return {
      path: stored.locator,
      sha256,
    };
  }

  private toView(version: AppVersion): AppVersionView {
    return {
      id: version.id,
      platform: version.platform,
      channel: version.channel,
      versionName: version.versionName,
      versionCode: version.versionCode,
      forceUpdate: version.forceUpdate,
      enabled: version.enabled,
      apkUrl: version.apkUrl,
      apkSize: version.apkSize,
      sha256: version.sha256,
      changelog: version.changelog,
      createdBy: version.createdBy,
      createdAt: version.createdAt.toISOString(),
      updatedAt: version.updatedAt.toISOString(),
    };
  }
}

async function hashUploadedFile(file: UploadedApkFile): Promise<string> {
  if (file.path) {
    return hashFile(file.path);
  }
  if (file.buffer) {
    return createHash('sha256').update(file.buffer).digest('hex');
  }
  throw new BadRequestException('APK file is empty');
}

async function hashFile(path: string): Promise<string> {
  const hash = createHash('sha256');
  await new Promise<void>((resolve, reject) => {
    createReadStream(path)
      .on('data', (chunk) => hash.update(chunk))
      .on('error', reject)
      .on('end', resolve);
  });
  return hash.digest('hex');
}

function parseBoolean(value: string | undefined, fallback = false): boolean {
  if (value === undefined || value === '') {
    return fallback;
  }
  return value === 'true' || value === '1' || value === 'yes';
}
