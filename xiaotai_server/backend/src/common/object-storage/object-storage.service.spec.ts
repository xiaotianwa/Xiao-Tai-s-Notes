import { ConfigService } from "@nestjs/config";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";

import type { AppConfig } from "../../config/configuration";
import { ObjectStorageService } from "./object-storage.service";

describe("ObjectStorageService", () => {
  let tempDir: string;

  afterEach(async () => {
    if (tempDir) {
      await rm(tempDir, { recursive: true, force: true });
    }
  });

  function serviceWithCos(enabled: boolean, prefix = "xiaotai") {
    const config = {
      get: (key: string) => {
        if (key === "cos") {
          return {
            enabled,
            secretId: "secret-id",
            secretKey: "secret-key",
            bucket: "bucket-123",
            region: "ap-guangzhou",
            prefix,
            publicBaseUrl: "",
          };
        }
        return undefined;
      },
    } as unknown as ConfigService<AppConfig, true>;
    return new ObjectStorageService(config);
  }

  it("stores and reads local files when COS is disabled", async () => {
    tempDir = await mkdtemp(join(tmpdir(), "xiaotai-storage-"));
    const service = serviceWithCos(false);
    const localPath = join(tempDir, "uploads", "a.txt");

    const stored = await service.putObject({
      key: "uploads/a.txt",
      localPath,
      buffer: Buffer.from("hello"),
      contentType: "text/plain",
    });

    expect(stored.locator).toBe(localPath);
    await expect(readFile(localPath, "utf8")).resolves.toBe("hello");
    await expect(
      service.readObject({ locator: localPath, contentType: "text/plain" }),
    ).resolves.toEqual({
      fileName: "a.txt",
      contentType: "text/plain",
      bytes: Buffer.from("hello"),
    });
  });

  it("normalizes COS object keys and locators", () => {
    const service = serviceWithCos(true, "private/xiaotai/");

    expect(service.objectKey("/uploads\\media/a.jpg")).toBe(
      "private/xiaotai/uploads/media/a.jpg",
    );
    expect(
      service.fileNameFromLocator("cos://private/xiaotai/uploads/a.jpg"),
    ).toBe("a.jpg");
  });
});
