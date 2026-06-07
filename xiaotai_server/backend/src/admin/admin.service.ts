import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { Prisma, SyncItem } from "@prisma/client";
import * as bcrypt from "bcryptjs";
import type { Request } from "express";

import type { AuthUser } from "../auth/auth-user";
import { ObjectStorageService } from "../common/object-storage/object-storage.service";
import { PrismaService } from "../common/prisma/prisma.service";
import type {
  AdminAuditLogsQueryDto,
  AdminItemsQueryDto,
  AdminUsersQueryDto,
} from "./dto/admin-query.dto";
import type {
  CreateAdminUserDto,
  ResetAdminUserPasswordDto,
  UpdateAdminUserStatusDto,
} from "./dto/admin-user.dto";

export interface PageResult<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
}

interface UserRecord {
  id: string;
  username: string;
  nickname: string;
  role: string;
  status: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface PublicUserView {
  id: string;
  username: string;
  nickname: string;
  role: string;
  status: string;
  createdAt: string;
  updatedAt: string;
}

export interface AdminSyncItemView {
  id: string;
  userId: string;
  username: string;
  nickname: string;
  deviceId: string | null;
  type: string;
  clientId: string;
  data: unknown;
  version: number;
  clientUpdatedAt: string;
  serverUpdatedAt: string;
  deletedAt: string | null;
}

export interface AdminSyncTypeStatView {
  type: string;
  activeCount: number;
  deletedCount: number;
  latestServerUpdatedAt: string | null;
}

export interface AdminUserDetailView extends PublicUserView {
  devices: Array<{
    id: string;
    deviceName: string;
    platform: string;
    appVersionName: string | null;
    appVersionCode: number | null;
    lastSeenAt: string | null;
    createdAt: string;
  }>;
  syncItemCount: number;
  deletedSyncItemCount: number;
  mediaAssetCount: number;
  latestSyncAt: string | null;
  latestMediaUploadedAt: string | null;
  syncTypeStats: AdminSyncTypeStatView[];
  latestItems: AdminSyncItemView[];
  recentDeletedItems: AdminSyncItemView[];
  recentAuditLogs: Array<{
    id: string;
    action: string;
    targetType: string | null;
    targetId: string | null;
    metadata: unknown;
    createdAt: string;
    actor: PublicUserView;
  }>;
}

export type SyncHealthStatus =
  | "healthy"
  | "warning"
  | "critical"
  | "no_data"
  | "disabled";

export interface AdminSyncHealthUserView {
  user: PublicUserView;
  status: SyncHealthStatus;
  statusLabel: string;
  statusReason: string;
  deviceCount: number;
  syncItemCount: number;
  activeSyncItemCount: number;
  deletedSyncItemCount: number;
  todaySyncCount: number;
  mediaAssetCount: number;
  latestSyncAt: string | null;
  latestDeviceSeenAt: string | null;
  latestActivityAt: string | null;
  latestMediaUploadedAt: string | null;
  latestDevice: {
    id: string;
    deviceName: string;
    platform: string;
    appVersionName: string | null;
    appVersionCode: number | null;
    lastSeenAt: string | null;
  } | null;
}

export interface AdminSyncHealthSummaryView {
  totalUsers: number;
  activeUsers: number;
  healthyUsers: number;
  warningUsers: number;
  criticalUsers: number;
  noDataUsers: number;
  disabledUsers: number;
  totalDevices: number;
  totalSyncItems: number;
  deletedSyncItems: number;
  todaySyncCount: number;
  latestActivityAt: string | null;
}

interface UserSyncStatsBundle {
  syncCountByUser: Map<string, number>;
  activeSyncCountByUser: Map<string, number>;
  deletedSyncCountByUser: Map<string, number>;
  todaySyncCountByUser: Map<string, number>;
  mediaCountByUser: Map<string, number>;
  latestSyncByUser: Map<string, Date>;
  latestMediaByUser: Map<string, Date>;
  deviceCountByUser: Map<string, number>;
  latestDeviceSeenByUser: Map<string, Date>;
  latestDeviceByUser: Map<
    string,
    {
      id: string;
      deviceName: string;
      platform: string;
      appVersionName: string | null;
      appVersionCode: number | null;
      lastSeenAt: Date | null;
    }
  >;
}

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly objectStorage: ObjectStorageService,
  ) {}

  async dashboard(): Promise<{
    userCount: number;
    syncItemCount: number;
    memoCount: number;
    reminderCount: number;
    mediaCount: number;
    todaySyncCount: number;
    latestDevices: Array<{
      id: string;
      deviceName: string;
      platform: string;
      lastSeenAt: string | null;
      user: PublicUserView;
    }>;
    recentAuditLogs: Array<{
      id: string;
      action: string;
      targetType: string | null;
      targetId: string | null;
      createdAt: string;
      actor: PublicUserView;
    }>;
  }> {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const [
      userCount,
      syncItemCount,
      memoCount,
      reminderCount,
      mediaCount,
      todaySyncCount,
      latestDevices,
      recentAuditLogs,
    ] = await this.prisma.$transaction([
      this.prisma.user.count(),
      this.prisma.syncItem.count({ where: { deletedAt: null } }),
      this.prisma.syncItem.count({ where: { type: "memo", deletedAt: null } }),
      this.prisma.syncItem.count({
        where: { type: "reminder", deletedAt: null },
      }),
      this.prisma.mediaAsset.count({ where: { deletedAt: null } }),
      this.prisma.syncItem.count({
        where: { serverUpdatedAt: { gte: today } },
      }),
      this.prisma.device.findMany({
        orderBy: [{ lastSeenAt: "desc" }, { updatedAt: "desc" }],
        take: 5,
        include: { user: { select: this.userSelect() } },
      }),
      this.prisma.auditLog.findMany({
        orderBy: { createdAt: "desc" },
        take: 5,
        include: { actor: { select: this.userSelect() } },
      }),
    ]);

    return {
      userCount,
      syncItemCount,
      memoCount,
      reminderCount,
      mediaCount,
      todaySyncCount,
      latestDevices: latestDevices.map((device) => ({
        id: device.id,
        deviceName: device.deviceName,
        platform: device.platform,
        lastSeenAt: device.lastSeenAt?.toISOString() ?? null,
        user: this.toPublicUser(device.user),
      })),
      recentAuditLogs: recentAuditLogs.map((log) => ({
        id: log.id,
        action: log.action,
        targetType: log.targetType,
        targetId: log.targetId,
        createdAt: log.createdAt.toISOString(),
        actor: this.toPublicUser(log.actor),
      })),
    };
  }

  async syncHealth(query: AdminUsersQueryDto): Promise<
    PageResult<AdminSyncHealthUserView> & {
      summary: AdminSyncHealthSummaryView;
    }
  > {
    const page = query.page;
    const pageSize = query.pageSize;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const where = this.buildUserWhere(query);
    const [allMatchedUsers, users, total] = await this.prisma.$transaction([
      this.prisma.user.findMany({
        where,
        select: this.userSelect(),
        orderBy: { createdAt: "desc" },
      }),
      this.prisma.user.findMany({
        where,
        select: this.userSelect(),
        orderBy: { createdAt: "desc" },
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.user.count({ where }),
    ]);

    const allStats = await this.collectUserSyncStats(
      allMatchedUsers.map((user) => user.id),
      today,
    );
    const pageStats = await this.collectUserSyncStats(
      users.map((user) => user.id),
      today,
    );
    const allRows = allMatchedUsers.map((user) =>
      this.toSyncHealthUserView(user, allStats),
    );

    return {
      items: users.map((user) => this.toSyncHealthUserView(user, pageStats)),
      total,
      page,
      pageSize,
      summary: this.buildSyncHealthSummary(allRows),
    };
  }

  async listUsers(
    query: AdminUsersQueryDto,
  ): Promise<PageResult<PublicUserView & { syncItemCount: number }>> {
    const page = query.page;
    const pageSize = query.pageSize;
    const where = this.buildUserWhere(query);
    const [items, total] = await this.prisma.$transaction([
      this.prisma.user.findMany({
        where,
        select: {
          ...this.userSelect(),
          _count: { select: { syncItems: true } },
        },
        orderBy: { createdAt: "desc" },
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.user.count({ where }),
    ]);

    return {
      items: items.map((item) => ({
        ...this.toPublicUser(item),
        syncItemCount: item._count.syncItems,
      })),
      total,
      page,
      pageSize,
    };
  }

  async createUser(
    input: CreateAdminUserDto,
    actor: AuthUser,
    request: Request,
  ): Promise<PublicUserView> {
    const existing = await this.prisma.user.findUnique({
      where: { username: input.username },
      select: { id: true },
    });
    if (existing) {
      throw new ConflictException("账号已存在");
    }

    const passwordHash = await bcrypt.hash(input.password, 12);
    const user = await this.prisma.user.create({
      data: {
        username: input.username,
        nickname: input.nickname,
        role: input.role,
        status: input.status,
        passwordHash,
      },
      select: this.userSelect(),
    });

    await this.recordAudit(actor, request, {
      action: "admin.users.create",
      targetType: "user",
      targetId: user.id,
      metadata: {
        username: user.username,
        role: user.role,
        status: user.status,
      },
    });

    return this.toPublicUser(user);
  }

  async resetUserPassword(
    id: string,
    input: ResetAdminUserPasswordDto,
    actor: AuthUser,
    request: Request,
  ): Promise<PublicUserView> {
    const passwordHash = await bcrypt.hash(input.password, 12);
    const now = new Date();
    const user = await this.prisma
      .$transaction(async (tx) => {
        const updated = await tx.user.update({
          where: { id },
          data: { passwordHash },
          select: this.userSelect(),
        });
        await tx.refreshToken.updateMany({
          where: { userId: id, revokedAt: null },
          data: { revokedAt: now },
        });
        return updated;
      })
      .catch((error: unknown) => {
        if (
          error instanceof Prisma.PrismaClientKnownRequestError &&
          error.code === "P2025"
        ) {
          throw new NotFoundException("用户不存在");
        }
        throw error;
      });

    await this.recordAudit(actor, request, {
      action: "admin.users.reset_password",
      targetType: "user",
      targetId: id,
      metadata: { username: user.username },
    });

    return this.toPublicUser(user);
  }

  async updateUserStatus(
    id: string,
    input: UpdateAdminUserStatusDto,
    actor: AuthUser,
    request: Request,
  ): Promise<PublicUserView> {
    if (id === actor.id && input.status === "disabled") {
      throw new BadRequestException("不能停用当前登录的管理员账号");
    }

    const existing = await this.prisma.user.findUnique({
      where: { id },
      select: this.userSelect(),
    });
    if (!existing) {
      throw new NotFoundException("用户不存在");
    }

    if (
      existing.role === "admin" &&
      existing.status === "active" &&
      input.status === "disabled"
    ) {
      const activeAdminCount = await this.prisma.user.count({
        where: { role: "admin", status: "active" },
      });
      if (activeAdminCount <= 1) {
        throw new BadRequestException("至少需要保留一个可用管理员账号");
      }
    }

    const now = new Date();
    const user = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.user.update({
        where: { id },
        data: { status: input.status },
        select: this.userSelect(),
      });
      if (input.status === "disabled") {
        await tx.refreshToken.updateMany({
          where: { userId: id, revokedAt: null },
          data: { revokedAt: now },
        });
      }
      return updated;
    });

    await this.recordAudit(actor, request, {
      action: "admin.users.update_status",
      targetType: "user",
      targetId: id,
      metadata: {
        username: user.username,
        previousStatus: existing.status,
        status: user.status,
      },
    });

    return this.toPublicUser(user);
  }

  async deleteUser(
    id: string,
    actor: AuthUser,
    request: Request,
  ): Promise<{
    deleted: true;
    user: PublicUserView;
    related: {
      refreshTokens: number;
      devices: number;
      syncItems: number;
      mediaAssets: number;
      auditLogs: number;
      spaceMemberships: number;
      orphanSpaces: number;
    };
  }> {
    if (id === actor.id) {
      throw new BadRequestException("不能删除当前登录的管理员账号");
    }

    const existing = await this.prisma.user.findUnique({
      where: { id },
      select: {
        ...this.userSelect(),
        _count: {
          select: {
            refreshTokens: true,
            devices: true,
            syncItems: true,
            mediaAssets: true,
            auditLogs: true,
            spaces: true,
          },
        },
      },
    });
    if (!existing) {
      throw new NotFoundException("用户不存在");
    }

    if (existing.role === "admin" && existing.status === "active") {
      const activeAdminCount = await this.prisma.user.count({
        where: { role: "admin", status: "active" },
      });
      if (activeAdminCount <= 1) {
        throw new BadRequestException("至少需要保留一个可用管理员账号");
      }
    }

    const mediaAssets = await this.prisma.mediaAsset.findMany({
      where: { userId: id },
      select: { id: true, filePath: true, thumbPath: true },
    });
    const userSpaceIds = (
      await this.prisma.spaceMember.findMany({
        where: { userId: id },
        select: { spaceId: true },
      })
    ).map((member) => member.spaceId);
    const deletablePaths = await this.findUserOwnedMediaPaths(id, mediaAssets);
    const user = this.toPublicUser(existing);
    const related = {
      refreshTokens: existing._count.refreshTokens,
      devices: existing._count.devices,
      syncItems: existing._count.syncItems,
      mediaAssets: existing._count.mediaAssets,
      auditLogs: existing._count.auditLogs,
      spaceMemberships: existing._count.spaces,
      orphanSpaces: 0,
    };

    const result = await this.prisma.$transaction(async (tx) => {
      await tx.user.delete({ where: { id } });
      const orphanSpaces = await tx.space.deleteMany({
        where: { id: { in: userSpaceIds }, members: { none: {} } },
      });
      await tx.auditLog.create({
        data: {
          actorUserId: actor.id,
          action: "admin.users.delete",
          targetType: "user",
          targetId: id,
          ip: request.ip,
          userAgent: request.headers["user-agent"],
          metadataJson: JSON.stringify({
            username: user.username,
            nickname: user.nickname,
            role: user.role,
            status: user.status,
            related: {
              ...related,
              orphanSpaces: orphanSpaces.count,
            },
          }),
        },
      });
      return orphanSpaces;
    });

    await Promise.all(
      deletablePaths.map((path) =>
        this.objectStorage.deleteObject(path).catch(() => {}),
      ),
    );

    return {
      deleted: true,
      user,
      related: { ...related, orphanSpaces: result.count },
    };
  }

  async getUserDetail(
    id: string,
    actor: AuthUser,
    request: Request,
  ): Promise<AdminUserDetailView> {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        ...this.userSelect(),
        devices: {
          orderBy: [{ lastSeenAt: "desc" }, { updatedAt: "desc" }],
          select: {
            id: true,
            deviceName: true,
            platform: true,
            appVersionName: true,
            appVersionCode: true,
            lastSeenAt: true,
            createdAt: true,
          },
        },
        _count: { select: { syncItems: true, mediaAssets: true } },
      },
    });
    if (!user) {
      throw new NotFoundException("用户不存在");
    }

    const [
      activeTypeStats,
      deletedTypeStats,
      latestItems,
      recentDeletedItems,
      deletedSyncItemCount,
      latestSyncAggregate,
      latestMediaAggregate,
      recentAuditLogs,
    ] = await this.prisma.$transaction([
      this.prisma.syncItem.groupBy({
        by: ["type"],
        where: { userId: id, deletedAt: null },
        orderBy: { type: "asc" },
        _count: { _all: true },
        _max: { serverUpdatedAt: true },
      }),
      this.prisma.syncItem.groupBy({
        by: ["type"],
        where: { userId: id, deletedAt: { not: null } },
        orderBy: { type: "asc" },
        _count: { _all: true },
        _max: { serverUpdatedAt: true },
      }),
      this.prisma.syncItem.findMany({
        where: { userId: id },
        include: { user: { select: this.userSelect() } },
        orderBy: { serverUpdatedAt: "desc" },
        take: 8,
      }),
      this.prisma.syncItem.findMany({
        where: { userId: id, deletedAt: { not: null } },
        include: { user: { select: this.userSelect() } },
        orderBy: { deletedAt: "desc" },
        take: 5,
      }),
      this.prisma.syncItem.count({ where: { userId: id, deletedAt: { not: null } } }),
      this.prisma.syncItem.aggregate({
        where: { userId: id },
        _max: { serverUpdatedAt: true },
      }),
      this.prisma.mediaAsset.aggregate({
        where: { userId: id },
        _max: { uploadedAt: true },
      }),
      this.prisma.auditLog.findMany({
        where: {
          OR: [
            { targetType: "user", targetId: id },
            { metadataJson: { contains: id } },
          ],
        },
        include: { actor: { select: this.userSelect() } },
        orderBy: { createdAt: "desc" },
        take: 8,
      }),
    ]);

    await this.recordAudit(actor, request, {
      action: "admin.users.view",
      targetType: "user",
      targetId: id,
    });

    return {
      ...this.toPublicUser(user),
      devices: user.devices.map((device) => ({
        ...device,
        lastSeenAt: device.lastSeenAt?.toISOString() ?? null,
        createdAt: device.createdAt.toISOString(),
      })),
      syncItemCount: user._count.syncItems,
      deletedSyncItemCount,
      mediaAssetCount: user._count.mediaAssets,
      latestSyncAt:
        latestSyncAggregate._max.serverUpdatedAt?.toISOString() ?? null,
      latestMediaUploadedAt:
        latestMediaAggregate._max.uploadedAt?.toISOString() ?? null,
      syncTypeStats: this.mergeSyncTypeStats(activeTypeStats, deletedTypeStats),
      latestItems: latestItems.map((item) => this.toSyncItemView(item)),
      recentDeletedItems: recentDeletedItems.map((item) =>
        this.toSyncItemView(item),
      ),
      recentAuditLogs: recentAuditLogs.map((log) => ({
        id: log.id,
        action: log.action,
        targetType: log.targetType,
        targetId: log.targetId,
        metadata: parseJson(log.metadataJson),
        createdAt: log.createdAt.toISOString(),
        actor: this.toPublicUser(log.actor),
      })),
    };
  }

  async listItems(
    query: AdminItemsQueryDto,
  ): Promise<PageResult<AdminSyncItemView>> {
    const page = query.page;
    const pageSize = query.pageSize;
    const where: Prisma.SyncItemWhereInput = {
      ...(query.userId ? { userId: query.userId } : {}),
      ...(query.type ? { type: query.type } : {}),
      ...(query.deleted === "true"
        ? { deletedAt: { not: null } }
        : query.deleted === "false"
          ? { deletedAt: null }
          : {}),
      ...(query.keyword
        ? {
            OR: [
              { clientId: { contains: query.keyword } },
              { dataJson: { contains: query.keyword } },
            ],
          }
        : {}),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.syncItem.findMany({
        where,
        include: { user: { select: this.userSelect() } },
        orderBy: { serverUpdatedAt: "desc" },
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.syncItem.count({ where }),
    ]);

    return {
      items: items.map((item) => this.toSyncItemView(item)),
      total,
      page,
      pageSize,
    };
  }

  async listUserItems(
    userId: string,
    query: AdminItemsQueryDto,
  ): Promise<PageResult<AdminSyncItemView>> {
    return this.listItems({ ...query, userId });
  }

  async getItemDetail(
    id: string,
    actor: AuthUser,
    request: Request,
  ): Promise<AdminSyncItemView> {
    const item = await this.prisma.syncItem.findUnique({
      where: { id },
      include: { user: { select: this.userSelect() } },
    });
    if (!item) {
      throw new NotFoundException("数据不存在");
    }
    await this.recordAudit(actor, request, {
      action: "admin.items.view",
      targetType: "sync_item",
      targetId: id,
      metadata: { type: item.type, userId: item.userId },
    });
    return this.toSyncItemView(item);
  }

  async softDeleteItem(
    id: string,
    actor: AuthUser,
    request: Request,
  ): Promise<{ deleted: true; item: AdminSyncItemView }> {
    const existing = await this.prisma.syncItem.findUnique({
      where: { id },
      include: { user: { select: this.userSelect() } },
    });
    if (!existing) {
      throw new NotFoundException("Sync item not found");
    }

    const now = existing.deletedAt ?? new Date();
    const item = existing.deletedAt
      ? existing
      : await this.prisma.syncItem.update({
          where: { id },
          data: {
            deletedAt: now,
            serverUpdatedAt: now,
            version: { increment: 1 },
          },
          include: { user: { select: this.userSelect() } },
        });

    await this.recordAudit(actor, request, {
      action: "admin.items.delete",
      targetType: "sync_item",
      targetId: id,
      metadata: {
        type: item.type,
        userId: item.userId,
        clientId: item.clientId,
        alreadyDeleted: Boolean(existing.deletedAt),
      },
    });

    return { deleted: true, item: this.toSyncItemView(item) };
  }

  async restoreSyncItem(
    id: string,
    actor: AuthUser,
    request: Request,
  ): Promise<{ restored: true; item: AdminSyncItemView }> {
    const existing = await this.prisma.syncItem.findUnique({
      where: { id },
      include: { user: { select: this.userSelect() } },
    });
    if (!existing) {
      throw new NotFoundException("数据不存在");
    }

    const now = new Date();
    const item = existing.deletedAt
      ? await this.prisma.syncItem.update({
          where: { id },
          data: {
            deletedAt: null,
            serverUpdatedAt: now,
            version: { increment: 1 },
          },
          include: { user: { select: this.userSelect() } },
        })
      : existing;

    await this.recordAudit(actor, request, {
      action: "admin.items.restore",
      targetType: "sync_item",
      targetId: id,
      metadata: {
        type: item.type,
        userId: item.userId,
        clientId: item.clientId,
        alreadyActive: !existing.deletedAt,
      },
    });

    return { restored: true, item: this.toSyncItemView(item) };
  }

  async listAuditLogs(query: AdminAuditLogsQueryDto): Promise<
    PageResult<{
      id: string;
      action: string;
      targetType: string | null;
      targetId: string | null;
      ip: string | null;
      userAgent: string | null;
      metadata: unknown;
      createdAt: string;
      actor: PublicUserView;
    }>
  > {
    const page = query.page;
    const pageSize = query.pageSize;
    const where: Prisma.AuditLogWhereInput = {
      ...(query.action ? { action: query.action } : {}),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.auditLog.findMany({
        where,
        include: { actor: { select: this.userSelect() } },
        orderBy: { createdAt: "desc" },
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.auditLog.count({ where }),
    ]);

    return {
      items: items.map((item) => ({
        id: item.id,
        action: item.action,
        targetType: item.targetType,
        targetId: item.targetId,
        ip: item.ip,
        userAgent: item.userAgent,
        metadata: parseJson(item.metadataJson),
        createdAt: item.createdAt.toISOString(),
        actor: this.toPublicUser(item.actor),
      })),
      total,
      page,
      pageSize,
    };
  }

  async recordAudit(
    actor: AuthUser,
    request: Request,
    input: {
      action: string;
      targetType?: string;
      targetId?: string;
      metadata?: Record<string, unknown>;
    },
  ): Promise<void> {
    await this.prisma.auditLog.create({
      data: {
        actorUserId: actor.id,
        action: input.action,
        targetType: input.targetType,
        targetId: input.targetId,
        ip: request.ip,
        userAgent: request.headers["user-agent"],
        metadataJson: input.metadata ? JSON.stringify(input.metadata) : null,
      },
    });
  }

  private toSyncItemView(
    item: SyncItem & { user: UserRecord },
  ): AdminSyncItemView {
    return {
      id: item.id,
      userId: item.userId,
      username: item.user.username,
      nickname: item.user.nickname,
      deviceId: item.deviceId,
      type: item.type,
      clientId: item.clientId,
      data: parseJson(item.dataJson),
      version: item.version,
      clientUpdatedAt: item.clientUpdatedAt.toISOString(),
      serverUpdatedAt: item.serverUpdatedAt.toISOString(),
      deletedAt: item.deletedAt?.toISOString() ?? null,
    };
  }

  private toPublicUser(user: UserRecord): PublicUserView {
    return {
      id: user.id,
      username: user.username,
      nickname: user.nickname,
      role: user.role,
      status: user.status,
      createdAt: user.createdAt.toISOString(),
      updatedAt: user.updatedAt.toISOString(),
    };
  }

  private userSelect(): Prisma.UserSelect {
    return {
      id: true,
      username: true,
      nickname: true,
      role: true,
      status: true,
      createdAt: true,
      updatedAt: true,
    };
  }

  private buildUserWhere(query: AdminUsersQueryDto): Prisma.UserWhereInput {
    return {
      ...(query.status ? { status: query.status } : {}),
      ...(query.keyword
        ? {
            OR: [
              { username: { contains: query.keyword } },
              { nickname: { contains: query.keyword } },
            ],
          }
        : {}),
    };
  }

  private async collectUserSyncStats(
    userIds: string[],
    today: Date,
  ): Promise<UserSyncStatsBundle> {
    if (userIds.length === 0) {
      return {
        syncCountByUser: new Map(),
        activeSyncCountByUser: new Map(),
        deletedSyncCountByUser: new Map(),
        todaySyncCountByUser: new Map(),
        mediaCountByUser: new Map(),
        latestSyncByUser: new Map(),
        latestMediaByUser: new Map(),
        deviceCountByUser: new Map(),
        latestDeviceSeenByUser: new Map(),
        latestDeviceByUser: new Map(),
      };
    }

    const [
      syncStats,
      activeSyncStats,
      deletedSyncStats,
      todaySyncStats,
      mediaStats,
      deviceStats,
      latestDevices,
    ] = await this.prisma.$transaction([
      this.prisma.syncItem.groupBy({
        by: ["userId"],
        where: { userId: { in: userIds } },
        orderBy: { userId: "asc" },
        _count: { _all: true },
        _max: { serverUpdatedAt: true },
      }),
      this.prisma.syncItem.groupBy({
        by: ["userId"],
        where: { userId: { in: userIds }, deletedAt: null },
        orderBy: { userId: "asc" },
        _count: { _all: true },
      }),
      this.prisma.syncItem.groupBy({
        by: ["userId"],
        where: { userId: { in: userIds }, deletedAt: { not: null } },
        orderBy: { userId: "asc" },
        _count: { _all: true },
      }),
      this.prisma.syncItem.groupBy({
        by: ["userId"],
        where: { userId: { in: userIds }, serverUpdatedAt: { gte: today } },
        orderBy: { userId: "asc" },
        _count: { _all: true },
      }),
      this.prisma.mediaAsset.groupBy({
        by: ["userId"],
        where: { userId: { in: userIds } },
        orderBy: { userId: "asc" },
        _count: { _all: true },
        _max: { uploadedAt: true },
      }),
      this.prisma.device.groupBy({
        by: ["userId"],
        where: { userId: { in: userIds } },
        orderBy: { userId: "asc" },
        _count: { _all: true },
        _max: { lastSeenAt: true },
      }),
      this.prisma.device.findMany({
        where: { userId: { in: userIds } },
        select: {
          id: true,
          userId: true,
          deviceName: true,
          platform: true,
          appVersionName: true,
          appVersionCode: true,
          lastSeenAt: true,
        },
        orderBy: [{ lastSeenAt: "desc" }, { updatedAt: "desc" }],
      }),
    ]);

    const latestDeviceByUser = new Map<
      string,
      {
        id: string;
        deviceName: string;
        platform: string;
        appVersionName: string | null;
        appVersionCode: number | null;
        lastSeenAt: Date | null;
      }
    >();
    for (const device of latestDevices) {
      if (!latestDeviceByUser.has(device.userId)) {
        latestDeviceByUser.set(device.userId, device);
      }
    }

    return {
      syncCountByUser: countMap(syncStats),
      activeSyncCountByUser: countMap(activeSyncStats),
      deletedSyncCountByUser: countMap(deletedSyncStats),
      todaySyncCountByUser: countMap(todaySyncStats),
      mediaCountByUser: countMap(mediaStats),
      latestSyncByUser: maxDateMap(syncStats, "serverUpdatedAt"),
      latestMediaByUser: maxDateMap(mediaStats, "uploadedAt"),
      deviceCountByUser: countMap(deviceStats),
      latestDeviceSeenByUser: maxDateMap(deviceStats, "lastSeenAt"),
      latestDeviceByUser,
    };
  }

  private toSyncHealthUserView(
    user: UserRecord,
    stats: UserSyncStatsBundle,
  ): AdminSyncHealthUserView {
    const latestSyncAt = stats.latestSyncByUser.get(user.id) ?? null;
    const latestDeviceSeenAt = stats.latestDeviceSeenByUser.get(user.id) ?? null;
    const latestMediaUploadedAt = stats.latestMediaByUser.get(user.id) ?? null;
    const latestActivityAt = maxDate([
      latestSyncAt,
      latestDeviceSeenAt,
      latestMediaUploadedAt,
    ]);
    const status = this.getSyncHealthStatus(user, latestActivityAt);
    const latestDevice = stats.latestDeviceByUser.get(user.id) ?? null;

    return {
      user: this.toPublicUser(user),
      status,
      statusLabel: syncHealthStatusLabel(status),
      statusReason: syncHealthStatusReason(status, latestActivityAt),
      deviceCount: stats.deviceCountByUser.get(user.id) ?? 0,
      syncItemCount: stats.syncCountByUser.get(user.id) ?? 0,
      activeSyncItemCount: stats.activeSyncCountByUser.get(user.id) ?? 0,
      deletedSyncItemCount: stats.deletedSyncCountByUser.get(user.id) ?? 0,
      todaySyncCount: stats.todaySyncCountByUser.get(user.id) ?? 0,
      mediaAssetCount: stats.mediaCountByUser.get(user.id) ?? 0,
      latestSyncAt: latestSyncAt?.toISOString() ?? null,
      latestDeviceSeenAt: latestDeviceSeenAt?.toISOString() ?? null,
      latestActivityAt: latestActivityAt?.toISOString() ?? null,
      latestMediaUploadedAt: latestMediaUploadedAt?.toISOString() ?? null,
      latestDevice: latestDevice
        ? {
            id: latestDevice.id,
            deviceName: latestDevice.deviceName,
            platform: latestDevice.platform,
            appVersionName: latestDevice.appVersionName,
            appVersionCode: latestDevice.appVersionCode,
            lastSeenAt: latestDevice.lastSeenAt?.toISOString() ?? null,
          }
        : null,
    };
  }

  private getSyncHealthStatus(
    user: UserRecord,
    latestActivityAt: Date | null,
  ): SyncHealthStatus {
    if (user.status !== "active") {
      return "disabled";
    }
    if (!latestActivityAt) {
      return "no_data";
    }
    const elapsed = Date.now() - latestActivityAt.getTime();
    const warningThreshold = 72 * 60 * 60 * 1000;
    const criticalThreshold = 14 * 24 * 60 * 60 * 1000;
    if (elapsed <= warningThreshold) {
      return "healthy";
    }
    if (elapsed <= criticalThreshold) {
      return "warning";
    }
    return "critical";
  }

  private buildSyncHealthSummary(
    rows: AdminSyncHealthUserView[],
  ): AdminSyncHealthSummaryView {
    const latestActivityAt = maxDate(
      rows.map((row) =>
        row.latestActivityAt ? new Date(row.latestActivityAt) : null,
      ),
    );
    return {
      totalUsers: rows.length,
      activeUsers: rows.filter((row) => row.user.status === "active").length,
      healthyUsers: rows.filter((row) => row.status === "healthy").length,
      warningUsers: rows.filter((row) => row.status === "warning").length,
      criticalUsers: rows.filter((row) => row.status === "critical").length,
      noDataUsers: rows.filter((row) => row.status === "no_data").length,
      disabledUsers: rows.filter((row) => row.status === "disabled").length,
      totalDevices: sum(rows.map((row) => row.deviceCount)),
      totalSyncItems: sum(rows.map((row) => row.syncItemCount)),
      deletedSyncItems: sum(rows.map((row) => row.deletedSyncItemCount)),
      todaySyncCount: sum(rows.map((row) => row.todaySyncCount)),
      latestActivityAt: latestActivityAt?.toISOString() ?? null,
    };
  }

  private mergeSyncTypeStats(
    activeGroups: Array<{
      type: string;
      _count?: true | { _all?: number };
      _max?: { serverUpdatedAt?: Date | null };
    }>,
    deletedGroups: Array<{
      type: string;
      _count?: true | { _all?: number };
      _max?: { serverUpdatedAt?: Date | null };
    }>,
  ): AdminSyncTypeStatView[] {
    const stats = new Map<
      string,
      { activeCount: number; deletedCount: number; latest: Date | null }
    >();
    for (const group of activeGroups) {
      stats.set(group.type, {
        activeCount: readGroupCount(group),
        deletedCount: 0,
        latest: group._max?.serverUpdatedAt ?? null,
      });
    }
    for (const group of deletedGroups) {
      const current = stats.get(group.type) ?? {
        activeCount: 0,
        deletedCount: 0,
        latest: null,
      };
      stats.set(group.type, {
        activeCount: current.activeCount,
        deletedCount: readGroupCount(group),
        latest: maxDate([current.latest, group._max?.serverUpdatedAt ?? null]),
      });
    }
    return [...stats.entries()]
      .map(([type, value]) => ({
        type,
        activeCount: value.activeCount,
        deletedCount: value.deletedCount,
        latestServerUpdatedAt: value.latest?.toISOString() ?? null,
      }))
      .sort(
        (left, right) =>
          right.activeCount +
          right.deletedCount -
          (left.activeCount + left.deletedCount),
      );
  }

  private async findUserOwnedMediaPaths(
    userId: string,
    mediaAssets: Array<{
      id: string;
      filePath: string;
      thumbPath: string | null;
    }>,
  ): Promise<string[]> {
    const paths = [
      ...new Set(
        mediaAssets.flatMap((asset) =>
          asset.thumbPath
            ? [asset.filePath, asset.thumbPath]
            : [asset.filePath],
        ),
      ),
    ];
    if (paths.length === 0) {
      return [];
    }
    const sharedAssets = await this.prisma.mediaAsset.findMany({
      where: {
        userId: { not: userId },
        OR: [{ filePath: { in: paths } }, { thumbPath: { in: paths } }],
      },
      select: { filePath: true, thumbPath: true },
    });
    const sharedPaths = new Set(
      sharedAssets.flatMap((asset) =>
        asset.thumbPath ? [asset.filePath, asset.thumbPath] : [asset.filePath],
      ),
    );
    return paths.filter((path) => !sharedPaths.has(path));
  }
}

function countMap(
  groups: Array<{ userId: string; _count?: true | { _all?: number } }>,
): Map<string, number> {
  return new Map(groups.map((group) => [group.userId, readGroupCount(group)]));
}

function maxDateMap(
  groups: Array<{
    userId: string;
    _max?: Record<string, Date | string | number | null | undefined>;
  }>,
  key: string,
): Map<string, Date> {
  const result = new Map<string, Date>();
  for (const group of groups) {
    const value = group._max?.[key];
    if (value instanceof Date) {
      result.set(group.userId, value);
    }
  }
  return result;
}

function readGroupCount(group: {
  _count?: true | { _all?: number };
}): number {
  if (typeof group._count === "object" && group._count) {
    return group._count._all ?? 0;
  }
  return 0;
}

function maxDate(values: Array<Date | null | undefined>): Date | null {
  let latest: Date | null = null;
  for (const value of values) {
    if (value && (!latest || value.getTime() > latest.getTime())) {
      latest = value;
    }
  }
  return latest;
}

function sum(values: number[]): number {
  return values.reduce((total, value) => total + value, 0);
}

function syncHealthStatusLabel(status: SyncHealthStatus): string {
  const labels: Record<SyncHealthStatus, string> = {
    healthy: "健康",
    warning: "需关注",
    critical: "异常",
    no_data: "无数据",
    disabled: "已停用",
  };
  return labels[status];
}

function syncHealthStatusReason(
  status: SyncHealthStatus,
  latestActivityAt: Date | null,
): string {
  if (status === "disabled") {
    return "账号已停用，不计入活跃同步";
  }
  if (!latestActivityAt) {
    return "没有设备或同步记录";
  }
  if (status === "healthy") {
    return "72 小时内有同步、设备或媒体活动";
  }
  if (status === "warning") {
    return "最近 14 天内有活动，但超过 72 小时未更新";
  }
  return "超过 14 天没有任何同步活动";
}

function parseJson(value: string | null): unknown {
  if (!value) {
    return {};
  }
  try {
    return JSON.parse(value) as unknown;
  } catch {
    return {};
  }
}
