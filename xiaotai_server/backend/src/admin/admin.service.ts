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

  async listUsers(
    query: AdminUsersQueryDto,
  ): Promise<PageResult<PublicUserView & { syncItemCount: number }>> {
    const page = query.page;
    const pageSize = query.pageSize;
    const where: Prisma.UserWhereInput = {
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
  ): Promise<PublicUserView & { devices: unknown[]; syncItemCount: number }> {
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
        _count: { select: { syncItems: true } },
      },
    });
    if (!user) {
      throw new NotFoundException("用户不存在");
    }
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
