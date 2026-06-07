import { Injectable } from '@nestjs/common';
import { Prisma, SyncItem } from '@prisma/client';

import type { AuthUser } from '../auth/auth-user';
import { normalizeDeviceName } from '../common/device-name';
import { PrismaService } from '../common/prisma/prisma.service';
import type {
  BatchUploadSyncItemsDto,
  PullSyncItemsDto,
  UploadSyncItemDto,
} from './dto/sync-item.dto';

export interface SyncItemView {
  id: string;
  type: string;
  clientId: string;
  data: unknown;
  version: number;
  clientUpdatedAt: string;
  serverUpdatedAt: string;
  deletedAt: string | null;
}

export interface PullSyncItemsResult {
  items: SyncItemView[];
  total: number;
  page: number;
  pageSize: number;
  serverTime: string;
}

export interface SyncConflict {
  type: string;
  clientId: string;
  reason: 'server_newer';
  serverItem: SyncItemView;
}

export interface BatchUploadSyncItemsResult {
  accepted: number;
  conflicts: SyncConflict[];
  serverTime: string;
}

@Injectable()
export class SyncService {
  constructor(private readonly prisma: PrismaService) {}

  async pullItems(
    user: AuthUser,
    query: PullSyncItemsDto,
  ): Promise<PullSyncItemsResult> {
    const page = query.page;
    const pageSize = query.pageSize;
    const where: Prisma.SyncItemWhereInput = {
      userId: user.id,
      ...(query.type ? { type: query.type } : {}),
      ...(query.since
        ? { serverUpdatedAt: { gt: new Date(query.since) } }
        : { deletedAt: null }),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.syncItem.findMany({
        where,
        orderBy: [{ serverUpdatedAt: 'asc' }, { id: 'asc' }],
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.syncItem.count({ where }),
    ]);

    return {
      items: items.map((item) => this.toView(item)),
      total,
      page,
      pageSize,
      serverTime: new Date().toISOString(),
    };
  }

  async batchUpload(
    user: AuthUser,
    input: BatchUploadSyncItemsDto,
  ): Promise<BatchUploadSyncItemsResult> {
    const spaceId = await this.ensurePersonalSpace(user);
    await this.upsertDevice(user, input);

    let accepted = 0;
    const conflicts: SyncConflict[] = [];
    for (const item of input.items) {
      const result = await this.upsertSyncItem({
        user,
        spaceId,
        deviceId: input.deviceId,
        item,
      });
      if (result.conflict) {
        conflicts.push(result.conflict);
      } else {
        accepted += 1;
      }
    }

    return {
      accepted,
      conflicts,
      serverTime: new Date().toISOString(),
    };
  }

  private async upsertSyncItem(input: {
    user: AuthUser;
    spaceId: string;
    deviceId: string;
    item: UploadSyncItemDto;
  }): Promise<{ conflict?: SyncConflict }> {
    const { user, spaceId, deviceId, item } = input;
    const clientUpdatedAt = new Date(item.clientUpdatedAt);
    const deletedAt = item.deletedAt ? new Date(item.deletedAt) : null;
    const existing = await this.prisma.syncItem.findUnique({
      where: {
        userId_type_clientId: {
          userId: user.id,
          type: item.type,
          clientId: item.clientId,
        },
      },
    });

    if (existing && existing.clientUpdatedAt > clientUpdatedAt) {
      return {
        conflict: {
          type: item.type,
          clientId: item.clientId,
          reason: 'server_newer',
          serverItem: this.toView(existing),
        },
      };
    }

    const serverUpdatedAt = new Date();
    if (!existing) {
      await this.prisma.syncItem.create({
        data: {
          userId: user.id,
          spaceId,
          deviceId,
          type: item.type,
          clientId: item.clientId,
          dataJson: JSON.stringify(item.data),
          clientUpdatedAt,
          serverUpdatedAt,
          deletedAt,
        },
      });
      return {};
    }

    await this.prisma.syncItem.update({
      where: { id: existing.id },
      data: {
        deviceId,
        dataJson: JSON.stringify(item.data),
        clientUpdatedAt,
        serverUpdatedAt,
        deletedAt,
        version: { increment: 1 },
      },
    });
    return {};
  }

  private async ensurePersonalSpace(user: AuthUser): Promise<string> {
    const existing = await this.prisma.spaceMember.findFirst({
      where: { userId: user.id },
      orderBy: { createdAt: 'asc' },
      select: { spaceId: true },
    });
    if (existing) {
      return existing.spaceId;
    }

    const space = await this.prisma.space.create({
      data: {
        name: `${user.nickname}的空间`,
        members: {
          create: {
            userId: user.id,
            role: 'owner',
          },
        },
      },
      select: { id: true },
    });
    return space.id;
  }

  private async upsertDevice(
    user: AuthUser,
    input: BatchUploadSyncItemsDto,
  ): Promise<void> {
    const device = input.device;
    const platform = device?.platform ?? 'unknown';
    const deviceName = normalizeDeviceName(
      device?.deviceName,
      platform,
      input.deviceId,
    );
    await this.prisma.device.upsert({
      where: { id: input.deviceId },
      create: {
        id: input.deviceId,
        userId: user.id,
        deviceName,
        platform,
        appVersionName: device?.appVersionName,
        appVersionCode: device?.appVersionCode,
        lastSeenAt: new Date(),
      },
      update: {
        userId: user.id,
        deviceName,
        platform,
        appVersionName: device?.appVersionName,
        appVersionCode: device?.appVersionCode,
        lastSeenAt: new Date(),
      },
    });
  }

  private toView(item: SyncItem): SyncItemView {
    return {
      id: item.id,
      type: item.type,
      clientId: item.clientId,
      data: parseDataJson(item.dataJson),
      version: item.version,
      clientUpdatedAt: item.clientUpdatedAt.toISOString(),
      serverUpdatedAt: item.serverUpdatedAt.toISOString(),
      deletedAt: item.deletedAt?.toISOString() ?? null,
    };
  }
}

function parseDataJson(value: string): unknown {
  try {
    return JSON.parse(value) as unknown;
  } catch {
    return {};
  }
}
