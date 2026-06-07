import type { Request } from "express";

import { getClientIp, getUserAgent } from "./request-context";

function requestOf(input: {
  headers?: Record<string, string | string[] | undefined>;
  ip?: string;
  remoteAddress?: string;
}): Request {
  return {
    headers: input.headers ?? {},
    ip: input.ip,
    socket: { remoteAddress: input.remoteAddress },
  } as Request;
}

describe("request context", () => {
  it("prefers the first forwarded client IP over the reverse proxy IP", () => {
    const request = requestOf({
      headers: {
        "x-forwarded-for": "203.0.113.8, 127.0.0.1",
        "x-real-ip": "198.51.100.9",
      },
      ip: "::ffff:127.0.0.1",
    });

    expect(getClientIp(request)).toBe("203.0.113.8");
  });

  it("normalizes IPv4-mapped loopback addresses", () => {
    const request = requestOf({ ip: "::ffff:127.0.0.1" });

    expect(getClientIp(request)).toBe("127.0.0.1");
  });

  it("returns a single user agent value", () => {
    const request = requestOf({
      headers: { "user-agent": ["first-agent", "second-agent"] },
    });

    expect(getUserAgent(request)).toBe("first-agent");
  });
});
