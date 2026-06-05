import type { AuthUser } from "../auth/auth-user";
import type { PrismaService } from "../common/prisma/prisma.service";
import { MonitorService } from "./monitor.service";
import type { Request } from "express";

interface TestForcePushRecord {
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
}

interface TestForcePushModel {
  findMany: jest.Mock<Promise<TestForcePushRecord[]>, [TestFindManyArgs]>;
  updateMany: jest.Mock<Promise<{ count: number }>, [TestUpdateManyArgs]>;
  create: jest.Mock<Promise<TestForcePushRecord>, [TestCreateArgs]>;
  findUnique: jest.Mock<Promise<TestForcePushRecord | null>, [unknown]>;
  update: jest.Mock<Promise<TestForcePushRecord>, [unknown]>;
  delete: jest.Mock<Promise<TestForcePushRecord>, [unknown]>;
  count: jest.Mock<Promise<number>, [unknown]>;
}

interface TestUserModel {
  findMany: jest.Mock<
    Promise<Array<{ id: string; username: string; nickname: string }>>,
    [unknown]
  >;
  findUnique: jest.Mock<Promise<{ id: string } | null>, [unknown]>;
}

interface TestAuditLogModel {
  create: jest.Mock<Promise<{ id: string }>, [TestAuditCreateArgs]>;
}

interface TestFindManyArgs {
  where: {
    userId?: string;
    enabled?: boolean;
    deliveredAt?: null;
    OR?: Array<{ deviceId: string } | { deviceId: null }>;
    AND?: Array<{
      OR: Array<{ expiresAt: null } | { expiresAt: { gt: Date } }>;
    }>;
  };
  orderBy?: { createdAt: "asc" | "desc" };
  take?: number;
}

interface TestUpdateManyArgs {
  where: {
    id: string;
    userId: string;
    OR: Array<{ deviceId: string } | { deviceId: null }>;
    deliveredAt: null;
  };
  data: { deliveredAt: Date };
}

interface TestCreateArgs {
  data: {
    userId: string;
    deviceId: string | null;
    title: string;
    content: string;
    level: string;
    createdBy: string;
    expiresAt: Date | null;
  };
}

interface TestAuditCreateArgs {
  data: {
    actorUserId: string;
    action: string;
    targetType: string;
    targetId: string;
    ip: string | undefined;
    userAgent: string | undefined;
    metadataJson: string | null;
  };
}

const pushCreatedAt = new Date("2026-05-29T02:00:00.000Z");

function createForcePushRecord(
  input: Partial<TestForcePushRecord> = {},
): TestForcePushRecord {
  return {
    id: "push_1",
    userId: "user_1",
    deviceId: null,
    title: "回消息",
    content: "看一下手机",
    level: "warn",
    enabled: true,
    deliveredAt: null,
    createdBy: "admin_1",
    createdAt: pushCreatedAt,
    updatedAt: pushCreatedAt,
    expiresAt: null,
    ...input,
  };
}

function mockAsync<Result, Args extends unknown[]>(
  value: Result,
): jest.Mock<Promise<Result>, Args> {
  return jest.fn<Promise<Result>, Args>().mockResolvedValue(value);
}

describe("MonitorService", () => {
  const user: AuthUser = {
    id: "user_1",
    username: "tester",
    nickname: "Tester",
    role: "user",
    status: "active",
  };

  function createService() {
    const forcePush: TestForcePushModel = {
      findMany: mockAsync<TestForcePushRecord[], [TestFindManyArgs]>([]),
      updateMany: mockAsync<{ count: number }, [TestUpdateManyArgs]>({
        count: 1,
      }),
      create: mockAsync<TestForcePushRecord, [TestCreateArgs]>(
        createForcePushRecord(),
      ),
      findUnique: mockAsync<TestForcePushRecord | null, [unknown]>(null),
      update: mockAsync<TestForcePushRecord, [unknown]>(
        createForcePushRecord(),
      ),
      delete: mockAsync<TestForcePushRecord, [unknown]>(
        createForcePushRecord(),
      ),
      count: mockAsync<number, [unknown]>(0),
    };
    const userModel: TestUserModel = {
      findMany: mockAsync<
        Array<{ id: string; username: string; nickname: string }>,
        [unknown]
      >([]),
      findUnique: mockAsync<{ id: string } | null, [unknown]>(null),
    };
    const auditLog: TestAuditLogModel = {
      create: mockAsync<{ id: string }, [TestAuditCreateArgs]>({
        id: "audit_1",
      }),
    };
    const prisma = {
      forcePush,
      user: userModel,
      auditLog,
      $transaction: jest
        .fn()
        .mockImplementation((operations: Array<Promise<unknown>>) =>
          Promise.all(operations),
        ),
    } as unknown as PrismaService;

    return {
      service: new MonitorService(prisma),
      forcePush,
      userModel,
      auditLog,
    };
  }

  it("polls only enabled undelivered pushes for the current user and device", async () => {
    const { service, forcePush } = createService();
    forcePush.findMany.mockResolvedValue([
      createForcePushRecord({
        id: "push_1",
        title: "回消息",
        content: "看一下手机",
        level: "warn",
      }),
    ]);

    await expect(service.pendingPushes(user, "device_1")).resolves.toEqual([
      {
        id: "push_1",
        title: "回消息",
        content: "看一下手机",
        level: "warn",
      },
    ]);

    const args = forcePush.findMany.mock.calls[0][0];
    expect(args.where.userId).toBe("user_1");
    expect(args.where.enabled).toBe(true);
    expect(args.where.deliveredAt).toBeNull();
    expect(args.where.OR).toEqual([{ deviceId: "device_1" }, { deviceId: null }]);
    expect(args.orderBy).toEqual({ createdAt: "asc" });
    expect(args.take).toBe(5);
  });

  it("filters pending pushes by expiration time", async () => {
    const { service, forcePush } = createService();

    await service.pendingPushes(user, "device_1");

    const args = forcePush.findMany.mock.calls[0][0];
    expect(args.where.AND).toHaveLength(1);
    expect(args.where.AND?.[0].OR[0]).toEqual({ expiresAt: null });
    const expiryCondition = args.where.AND?.[0].OR[1];
    if (
      !expiryCondition ||
      !("expiresAt" in expiryCondition) ||
      expiryCondition.expiresAt === null
    ) {
      throw new Error("force push expiration filter changed");
    }
    expect(expiryCondition.expiresAt.gt).toBeInstanceOf(Date);
  });

  it("acks a push idempotently for the current user and device", async () => {
    const { service, forcePush } = createService();

    const result = await service.ackPush(user, {
      deviceId: "device_1",
      id: "push_1",
    });

    expect(result.ackedAt).toEqual(expect.any(String));
    const args = forcePush.updateMany.mock.calls[0][0];
    expect(args.where).toEqual({
      id: "push_1",
      userId: "user_1",
      OR: [{ deviceId: "device_1" }, { deviceId: null }],
      deliveredAt: null,
    });
    expect(args.data.deliveredAt).toBeInstanceOf(Date);
  });

  it("creates a user-level push and records an audit log", async () => {
    const { service, forcePush, userModel, auditLog } = createService();
    userModel.findUnique.mockResolvedValue({ id: "user_2" });
    forcePush.create.mockResolvedValue(
      createForcePushRecord({
        id: "push_2",
        userId: "user_2",
        deviceId: null,
        title: "Check phone",
        content: "Please reply",
        level: "critical",
        expiresAt: null,
      }),
    );
    const request = {
      ip: "127.0.0.1",
      headers: { "user-agent": "jest" },
    } as unknown as Request;

    const result = await service.createPush(
      { ...user, id: "admin_1", role: "admin" },
      request,
      {
        userId: "user_2",
        title: "Check phone",
        content: "Please reply",
        level: "critical",
      },
    );

    expect(result).toEqual(
      expect.objectContaining({
        id: "push_2",
        userId: "user_2",
        deviceId: null,
        level: "critical",
      }),
    );
    expect(userModel.findUnique).toHaveBeenCalledWith({
      where: { id: "user_2" },
      select: { id: true },
    });
    const createArgs = forcePush.create.mock.calls[0][0];
    expect(createArgs.data.userId).toBe("user_2");
    expect(createArgs.data.deviceId).toBeNull();
    const auditArgs = auditLog.create.mock.calls[0][0];
    expect(auditArgs.data.action).toBe("admin.monitor.push.create");
    expect(auditArgs.data.targetId).toBe("push_2");
  });
});
