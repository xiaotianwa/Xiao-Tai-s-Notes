import { configuration } from "./configuration";

describe("configuration", () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = {
      ...originalEnv,
      DATABASE_URL: "file:../data/test.db",
      JWT_ACCESS_SECRET: "test-access-secret",
      JWT_REFRESH_SECRET: "test-refresh-secret",
    };
    delete process.env.NODE_ENV;
    delete process.env.PUBLIC_BASE_URL;
    delete process.env.CORS_ORIGINS;
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  it("loads required config with defaults", () => {
    const config = configuration();

    expect(config.port).toBe(3000);
    expect(config.databaseUrl).toBe("file:../data/test.db");
    expect(config.jwtAccessExpiresIn).toBe("7d");
    expect(config.jwtRefreshExpiresIn).toBe("30d");
    expect(config.corsOrigins).toBe(true);
  });

  it("loads public domain and CORS origins from env", () => {
    process.env.PUBLIC_BASE_URL = "https://api.example.com";
    process.env.CORS_ORIGINS =
      "https://admin.example.com, https://www.example.com";

    const config = configuration();

    expect(config.publicBaseUrl).toBe("https://api.example.com");
    expect(config.corsOrigins).toEqual([
      "https://admin.example.com",
      "https://www.example.com",
    ]);
  });

  it("does not allow arbitrary browser origins in production by default", () => {
    process.env.NODE_ENV = "production";
    delete process.env.CORS_ORIGINS;

    const config = configuration();

    expect(config.corsOrigins).toEqual([]);
  });

  it("throws when required secrets are missing", () => {
    delete process.env.JWT_ACCESS_SECRET;

    expect(() => configuration()).toThrow("JWT_ACCESS_SECRET is required");
  });

  it("throws when token duration format is unsupported", () => {
    process.env.JWT_REFRESH_EXPIRES_IN = "30 days";

    expect(() => configuration()).toThrow(
      "JWT_REFRESH_EXPIRES_IN must use a duration like 30m or 30d",
    );
  });

  it("requires Tencent COS credentials when COS storage is enabled", () => {
    process.env.COS_ENABLED = "true";

    expect(() => configuration()).toThrow("COS_SECRET_ID is required");
  });

  it("loads Tencent COS storage config from env", () => {
    process.env.COS_ENABLED = "true";
    process.env.COS_SECRET_ID = "secret-id";
    process.env.COS_SECRET_KEY = "secret-key";
    process.env.COS_BUCKET = "bucket-123";
    process.env.COS_REGION = "ap-guangzhou";
    process.env.COS_PREFIX = "private/xiaotai";

    const config = configuration();

    expect(config.cos).toEqual(
      expect.objectContaining({
        enabled: true,
        secretId: "secret-id",
        secretKey: "secret-key",
        bucket: "bucket-123",
        region: "ap-guangzhou",
        prefix: "private/xiaotai",
      }),
    );
  });
});
