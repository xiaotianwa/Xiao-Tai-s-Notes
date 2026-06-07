import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { DeviceUsageReport, Prisma } from "@prisma/client";
import type { Request } from "express";

import type { AuthUser } from "../auth/auth-user";
import { PrismaService } from "../common/prisma/prisma.service";
import { getClientIp, getUserAgent } from "../common/request-context";
import type { AckPushDto } from "./dto/ack-push.dto";
import type { CreatePushDto, UpdatePushDto } from "./dto/create-push.dto";
import type {
  QueryMonitorDevicesDto,
  QueryMonitorUsageDto,
  QueryPushDto,
} from "./dto/query-monitor.dto";

export interface PageResult<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
}

export interface MonitorTodayUsageItem {
  packageName: string;
  appName: string;
  totalMillis: number;
}

export interface MonitorDeviceSummaryView {
  userId: string;
  username: string;
  nickname: string;
  deviceId: string;
  deviceName: string | null;
  lastSeenAt: string;
  screenOn: boolean;
  foregroundPackage: string | null;
  foregroundAppName: string | null;
}

export interface MonitorUsageReportView {
  id: string;
  userId: string;
  username: string;
  nickname: string;
  deviceId: string;
  deviceName: string | null;
  screenOn: boolean;
  foregroundPackage: string | null;
  foregroundAppName: string | null;
  foregroundSinceMillis: number | null;
  todayUsage: MonitorTodayUsageItem[];
  capturedAt: string;
  createdAt: string;
}

interface MonitorUserView {
  username: string;
  nickname: string;
}

type DeviceUsageReportView = DeviceUsageReport;

@Injectable()
export class MonitorService {
  constructor(private readonly prisma: PrismaService) {}

  async listDevices(
    query: QueryMonitorDevicesDto,
  ): Promise<MonitorDeviceSummaryView[]> {
    const where: Prisma.DeviceUsageReportWhereInput = {
      ...(query.userId ? { userId: query.userId } : {}),
    };
    const reports = await this.prisma.deviceUsageReport.findMany({
      where,
      orderBy: { capturedAt: "desc" },
      take: 1000,
    });
    const latestByDevice = new Map<string, DeviceUsageReportView>();
    for (const report of reports) {
      const key = `${report.userId}:${report.deviceId}`;
      if (!latestByDevice.has(key)) {
        latestByDevice.set(key, report);
      }
    }
    const latestReports = [...latestByDevice.values()];
    const users = await this.loadUsers(latestReports.map((item) => item.userId));
    return latestReports.map((report) =>
      this.toDeviceView(report, users.get(report.userId)),
    );
  }

  async latestUsage(
    query: QueryMonitorUsageDto,
  ): Promise<MonitorUsageReportView | null> {
    const where = this.buildUsageWhere(query);
    const report = await this.prisma.deviceUsageReport.findFirst({
      where,
      orderBy: { capturedAt: "desc" },
    });
    if (!report) {
      return null;
    }
    const users = await this.loadUsers([report.userId]);
    return this.toUsageReportView(report, users.get(report.userId));
  }

  async listUsage(
    query: QueryMonitorUsageDto,
  ): Promise<PageResult<MonitorUsageReportView>> {
    const where = this.buildUsageWhere(query);
    const [items, total] = await this.prisma.$transaction([
      this.prisma.deviceUsageReport.findMany({
        where,
        orderBy: { capturedAt: "desc" },
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
      }),
      this.prisma.deviceUsageReport.count({ where }),
    ]);
    const users = await this.loadUsers(items.map((item) => item.userId));
    return {
      items: items.map((item) =>
        this.toUsageReportView(item, users.get(item.userId)),
      ),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  async pendingPushes(user: AuthUser, deviceId: string) {
    const now = new Date();
    const items = await this.prisma.forcePush.findMany({
      where: {
        userId: user.id,
        enabled: true,
        deliveredAt: null,
        OR: [{ deviceId }, { deviceId: null }],
        AND: [
          {
            OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
          },
        ],
      },
      orderBy: { createdAt: "asc" },
      take: 5,
    });
    return items.map((item) => ({
      id: item.id,
      title: item.title,
      content: item.content,
      level: item.level,
    }));
  }

  async ackPush(
    user: AuthUser,
    input: AckPushDto,
  ): Promise<{ ackedAt: string }> {
    const ackedAt = new Date();
    await this.prisma.forcePush.updateMany({
      where: {
        id: input.id,
        userId: user.id,
        OR: [{ deviceId: input.deviceId }, { deviceId: null }],
        deliveredAt: null,
      },
      data: { deliveredAt: ackedAt },
    });
    return { ackedAt: ackedAt.toISOString() };
  }

  async createPush(actor: AuthUser, request: Request, input: CreatePushDto) {
    await this.assertUserExists(input.userId);
    const expiresAt = parseOptionalDate(input.expiresAt);
    const push = await this.prisma.forcePush.create({
      data: {
        userId: input.userId,
        deviceId: null,
        title: input.title,
        content: input.content,
        level: input.level ?? "info",
        createdBy: actor.id,
        expiresAt,
      },
    });
    await this.recordAudit(actor, request, {
      action: "admin.monitor.push.create",
      targetId: push.id,
      metadata: { userId: push.userId },
    });
    return this.toPushView(push);
  }

  async listPushes(query: QueryPushDto): Promise<PageResult<unknown>> {
    const where: Prisma.ForcePushWhereInput = {
      ...(query.userId ? { userId: query.userId } : {}),
      ...(query.level ? { level: query.level } : {}),
      ...(query.enabled != null ? { enabled: query.enabled === "true" } : {}),
      ...(query.since || query.until
        ? {
            createdAt: {
              ...(query.since ? { gte: new Date(query.since) } : {}),
              ...(query.until ? { lte: new Date(query.until) } : {}),
            },
          }
        : {}),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.forcePush.findMany({
        where,
        orderBy: { createdAt: "desc" },
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
      }),
      this.prisma.forcePush.count({ where }),
    ]);
    const users = await this.loadUsers(items.map((item) => item.userId));
    return {
      items: items.map((item) => this.toPushView(item, users.get(item.userId))),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  async updatePush(
    id: string,
    actor: AuthUser,
    request: Request,
    input: UpdatePushDto,
  ) {
    const existing = await this.prisma.forcePush.findUnique({ where: { id } });
    if (!existing) {
      throw new NotFoundException("强提醒不存在");
    }
    const push = await this.prisma.forcePush.update({
      where: { id },
      data: {
        ...(input.title !== undefined ? { title: input.title } : {}),
        ...(input.content !== undefined ? { content: input.content } : {}),
        ...(input.level !== undefined ? { level: input.level } : {}),
        ...(input.enabled !== undefined ? { enabled: input.enabled } : {}),
        ...(input.expiresAt !== undefined
          ? { expiresAt: input.expiresAt ? new Date(input.expiresAt) : null }
          : {}),
      },
    });
    await this.recordAudit(actor, request, {
      action: "admin.monitor.push.update",
      targetId: id,
      metadata: { enabled: push.enabled },
    });
    return this.toPushView(push);
  }

  async deletePush(
    id: string,
    actor: AuthUser,
    request: Request,
  ): Promise<{ success: true }> {
    await this.prisma.forcePush.delete({ where: { id } }).catch((error) => {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2025"
      ) {
        throw new NotFoundException("强提醒不存在");
      }
      throw error;
    });
    await this.recordAudit(actor, request, {
      action: "admin.monitor.push.delete",
      targetId: id,
    });
    return { success: true };
  }

  private async assertUserExists(userId: string): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true },
    });
    if (!user) {
      throw new BadRequestException("目标用户不存在");
    }
  }

  private async loadUsers(userIds: string[]) {
    const ids = [...new Set(userIds)].filter(Boolean);
    if (ids.length === 0) {
      return new Map<string, { username: string; nickname: string }>();
    }
    const users = await this.prisma.user.findMany({
      where: { id: { in: ids } },
      select: { id: true, username: true, nickname: true },
    });
    return new Map(users.map((user) => [user.id, user]));
  }

  private buildUsageWhere(
    query: QueryMonitorUsageDto,
  ): Prisma.DeviceUsageReportWhereInput {
    return {
      ...(query.userId ? { userId: query.userId } : {}),
      ...(query.deviceId ? { deviceId: query.deviceId } : {}),
      ...(query.since || query.until
        ? {
            capturedAt: {
              ...(query.since ? { gte: new Date(query.since) } : {}),
              ...(query.until ? { lte: new Date(query.until) } : {}),
            },
          }
        : {}),
    };
  }

  private toDeviceView(
    report: DeviceUsageReportView,
    user?: MonitorUserView,
  ): MonitorDeviceSummaryView {
    return {
      userId: report.userId,
      username: user?.username ?? "",
      nickname: user?.nickname ?? "",
      deviceId: report.deviceId,
      deviceName: report.deviceName,
      lastSeenAt: report.capturedAt.toISOString(),
      screenOn: report.screenOn,
      foregroundPackage: report.foregroundPackage,
      foregroundAppName: report.foregroundAppName,
    };
  }

  private toUsageReportView(
    report: DeviceUsageReportView,
    user?: MonitorUserView,
  ): MonitorUsageReportView {
    return {
      id: report.id,
      userId: report.userId,
      username: user?.username ?? "",
      nickname: user?.nickname ?? "",
      deviceId: report.deviceId,
      deviceName: report.deviceName,
      screenOn: report.screenOn,
      foregroundPackage: report.foregroundPackage,
      foregroundAppName: report.foregroundAppName,
      foregroundSinceMillis:
        report.foregroundSinceMs == null
          ? null
          : Number(report.foregroundSinceMs),
      todayUsage: parseTodayUsage(report.todayUsage),
      capturedAt: report.capturedAt.toISOString(),
      createdAt: report.createdAt.toISOString(),
    };
  }

  private async recordAudit(
    actor: AuthUser,
    request: Request,
    input: {
      action: string;
      targetType?: string;
      targetId: string;
      metadata?: Record<string, unknown>;
    },
  ): Promise<void> {
    await this.prisma.auditLog.create({
      data: {
        actorUserId: actor.id,
        action: input.action,
        targetType: input.targetType ?? "force_push",
        targetId: input.targetId,
        ip: getClientIp(request),
        userAgent: getUserAgent(request),
        metadataJson: input.metadata ? JSON.stringify(input.metadata) : null,
      },
    });
  }

  private toPushView(
    push: {
      id: string;
      userId: string;
      deviceId: string | null;
      title: string;
      content: string;
      level: string;
      enabled: boolean;
      deliveredAt: Date | null;
      createdBy: string;
      createdAt: Date;
      updatedAt: Date;
      expiresAt: Date | null;
    },
    user?: { username: string; nickname: string },
  ) {
    return {
      id: push.id,
      userId: push.userId,
      username: user?.username ?? "",
      nickname: user?.nickname ?? "",
      deviceId: push.deviceId,
      title: push.title,
      content: push.content,
      level: push.level,
      enabled: push.enabled,
      deliveredAt: push.deliveredAt?.toISOString() ?? null,
      createdBy: push.createdBy,
      createdAt: push.createdAt.toISOString(),
      updatedAt: push.updatedAt.toISOString(),
      expiresAt: push.expiresAt?.toISOString() ?? null,
    };
  }
}

function parseOptionalDate(value: string | undefined): Date | null {
  if (!value) {
    return null;
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new BadRequestException("expiresAt 不是有效时间");
  }
  return date;
}

function parseTodayUsage(value: Prisma.JsonValue): MonitorTodayUsageItem[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.flatMap((item) => {
    if (typeof item !== "object" || item === null || Array.isArray(item)) {
      return [];
    }
    const packageName = readString(item, "packageName");
    if (!packageName) {
      return [];
    }
    return [
      {
        packageName,
        appName: readString(item, "appName") ?? packageName,
        totalMillis: readNumber(item, "totalMillis") ?? 0,
      },
    ];
  });
}

function readString(value: object, key: string): string | null {
  const next = (value as Record<string, unknown>)[key];
  return typeof next === "string" ? next : null;
}

function readNumber(value: object, key: string): number | null {
  const next = (value as Record<string, unknown>)[key];
  return typeof next === "number" && Number.isFinite(next) ? next : null;
}
