import type { AuthUser } from "../auth/auth-user";
import type { PrismaService } from "../common/prisma/prisma.service";
import { SyncService } from "./sync.service";

describe("SyncService", () => {
  const user: AuthUser = {
    id: "user_1",
    username: "tester",
    nickname: "Tester",
    role: "user",
    status: "active",
  };

  function createService() {
    const syncItem = {
      findMany: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
    };
    const prisma = {
      syncItem,
      $transaction: jest
        .fn()
        .mockImplementation((operations: Array<Promise<unknown>>) =>
          Promise.all(operations),
        ),
    } as unknown as PrismaService;

    return {
      service: new SyncService(prisma),
      syncItem,
    };
  }

  it("filters soft-deleted records from the first full pull", async () => {
    const { service, syncItem } = createService();

    await service.pullItems(user, { page: 1, pageSize: 100 });

    expect(syncItem.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          userId: "user_1",
          deletedAt: null,
        },
      }),
    );
    expect(syncItem.count).toHaveBeenCalledWith({
      where: {
        userId: "user_1",
        deletedAt: null,
      },
    });
  });

  it("keeps soft-deleted records in incremental pulls", async () => {
    const { service, syncItem } = createService();
    const since = "2026-05-26T00:00:00.000Z";

    await service.pullItems(user, { page: 1, pageSize: 100, since });

    expect(syncItem.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          userId: "user_1",
          serverUpdatedAt: { gt: new Date(since) },
        },
      }),
    );
    expect(syncItem.count).toHaveBeenCalledWith({
      where: {
        userId: "user_1",
        serverUpdatedAt: { gt: new Date(since) },
      },
    });
  });
});
