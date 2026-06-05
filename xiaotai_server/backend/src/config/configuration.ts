export type JwtExpiresIn = `${number}${"s" | "m" | "h" | "d"}`;

export interface AppConfig {
  nodeEnv: string;
  port: number;
  databaseUrl: string;
  jwtAccessSecret: string;
  jwtRefreshSecret: string;
  jwtAccessExpiresIn: JwtExpiresIn;
  jwtRefreshExpiresIn: JwtExpiresIn;
  storageRoot: string;
  qweatherApiKey: string;
  qweatherJwt: string;
  qweatherHost: string;
  qweatherLocation: string;
  qweatherCityName: string;
  bigModelApiKey: string;
  bigModelModel: string;
  bigModelEndpoint: string;
  publicBaseUrl: string;
  corsOrigins: string[] | true;
  cos: CosConfig;
}

export interface CosConfig {
  enabled: boolean;
  secretId: string;
  secretKey: string;
  bucket: string;
  region: string;
  prefix: string;
  publicBaseUrl: string;
}

function requiredEnv(name: string): string {
  const value = process.env[name];
  if (!value || value.trim().length === 0) {
    throw new Error(`${name} is required`);
  }
  return value;
}

function jwtExpiresInEnv(name: string, fallback: JwtExpiresIn): JwtExpiresIn {
  const value = process.env[name] ?? fallback;
  if (!/^\d+[smhd]$/.test(value)) {
    throw new Error(`${name} must use a duration like 30m or 30d`);
  }
  return value as JwtExpiresIn;
}

function booleanEnv(name: string, fallback = false): boolean {
  const value = process.env[name];
  if (value == null || value.trim().length === 0) {
    return fallback;
  }
  return ["1", "true", "yes", "on"].includes(value.trim().toLowerCase());
}

function optionalTrimmedEnv(name: string, fallback = ""): string {
  return (process.env[name] ?? fallback).trim();
}

function listEnv(name: string): string[] {
  return (process.env[name] ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
}

function corsOriginsEnv(nodeEnv: string): string[] | true {
  const origins = listEnv("CORS_ORIGINS");
  if (origins.length > 0) {
    return origins;
  }
  return nodeEnv === "production" ? [] : true;
}

function cosConfig(): CosConfig {
  const enabled = booleanEnv("COS_ENABLED", false);
  return {
    enabled,
    secretId: enabled
      ? requiredEnv("COS_SECRET_ID")
      : optionalTrimmedEnv("COS_SECRET_ID"),
    secretKey: enabled
      ? requiredEnv("COS_SECRET_KEY")
      : optionalTrimmedEnv("COS_SECRET_KEY"),
    bucket: enabled
      ? requiredEnv("COS_BUCKET")
      : optionalTrimmedEnv("COS_BUCKET"),
    region: enabled
      ? requiredEnv("COS_REGION")
      : optionalTrimmedEnv("COS_REGION"),
    prefix: optionalTrimmedEnv("COS_PREFIX", "xiaotai"),
    publicBaseUrl: optionalTrimmedEnv("COS_PUBLIC_BASE_URL"),
  };
}

export function configuration(): AppConfig {
  const nodeEnv = process.env.NODE_ENV ?? "development";
  return {
    nodeEnv,
    port: Number(process.env.PORT ?? 3000),
    databaseUrl: requiredEnv("DATABASE_URL"),
    jwtAccessSecret: requiredEnv("JWT_ACCESS_SECRET"),
    jwtRefreshSecret: requiredEnv("JWT_REFRESH_SECRET"),
    jwtAccessExpiresIn: jwtExpiresInEnv("JWT_ACCESS_EXPIRES_IN", "7d"),
    jwtRefreshExpiresIn: jwtExpiresInEnv("JWT_REFRESH_EXPIRES_IN", "30d"),
    storageRoot: process.env.APP_STORAGE_ROOT ?? "storage",
    qweatherApiKey: process.env.QWEATHER_API_KEY ?? "",
    qweatherJwt: process.env.QWEATHER_JWT ?? "",
    qweatherHost: process.env.QWEATHER_HOST ?? "p72tupd6nv.re.qweatherapi.com",
    qweatherLocation: process.env.QWEATHER_LOCATION ?? "101040100",
    qweatherCityName: process.env.QWEATHER_CITY_NAME ?? "重庆",
    bigModelApiKey: process.env.BIGMODEL_API_KEY ?? "",
    bigModelModel: process.env.BIGMODEL_MODEL ?? "deepseek-v4-pro-202606",
    bigModelEndpoint:
      process.env.BIGMODEL_ENDPOINT ??
      "https://tokenhub.tencentmaas.com/v1/chat/completions",
    publicBaseUrl: optionalTrimmedEnv("PUBLIC_BASE_URL"),
    corsOrigins: corsOriginsEnv(nodeEnv),
    cos: cosConfig(),
  };
}
