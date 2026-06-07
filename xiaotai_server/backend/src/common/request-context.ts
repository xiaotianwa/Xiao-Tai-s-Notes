import type { Request } from "express";

export function getClientIp(request: Request): string | null {
  const candidates = [
    firstForwardedIp(headerToString(request.headers["x-forwarded-for"])),
    headerToString(request.headers["x-real-ip"]),
    headerToString(request.headers["cf-connecting-ip"]),
    request.ip,
    request.socket?.remoteAddress,
  ];

  for (const candidate of candidates) {
    const normalized = normalizeIp(candidate);
    if (normalized) {
      return normalized;
    }
  }
  return null;
}

export function getUserAgent(request: Request): string | null {
  return headerToString(request.headers["user-agent"]) ?? null;
}

function headerToString(value: string | string[] | undefined): string | null {
  if (Array.isArray(value)) {
    return value.find((item) => item.trim().length > 0)?.trim() ?? null;
  }
  const normalized = value?.trim();
  return normalized ? normalized : null;
}

function firstForwardedIp(value: string | null): string | null {
  return value?.split(",")[0]?.trim() || null;
}

function normalizeIp(value: string | null | undefined): string | null {
  const trimmed = value?.trim();
  if (!trimmed) {
    return null;
  }

  if (trimmed === "::1") {
    return "127.0.0.1";
  }
  if (trimmed.startsWith("::ffff:")) {
    return trimmed.slice("::ffff:".length);
  }
  if (/^\d{1,3}(?:\.\d{1,3}){3}:\d+$/.test(trimmed)) {
    return trimmed.replace(/:\d+$/, "");
  }
  return trimmed;
}
