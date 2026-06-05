import { ConfigService } from "@nestjs/config";

import type { AppConfig } from "../config/configuration";
import { AiService } from "./ai.service";

interface AiChatRequestBody {
  model: string;
  messages: Array<{ role: string; content: string }>;
}

describe("AiService", () => {
  const originalFetch = global.fetch;

  afterEach(() => {
    global.fetch = originalFetch;
    jest.restoreAllMocks();
  });

  function createService() {
    const values = {
      bigModelApiKey: "test-key",
      bigModelEndpoint: "https://example.com/chat/completions",
      bigModelModel: "glm-test",
    };
    const config = {
      get: (key: string) => values[key as keyof typeof values],
    } as unknown as ConfigService<AppConfig, true>;
    return new AiService(config);
  }

  it("sends user prompt to configured BigModel endpoint", async () => {
    const fetchMock = jest.fn<
      Promise<Response>,
      [RequestInfo | URL, RequestInit?]
    >();
    fetchMock.mockResolvedValue({
      ok: true,
      status: 200,
      json: () =>
        Promise.resolve({
        choices: [{ message: { content: "已接入大模型" } }],
      }),
    } as Response);
    global.fetch = fetchMock;

    await expect(createService().chat("我是谁")).resolves.toEqual({
      answer: "已接入大模型",
      model: "glm-test",
    });

    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe("https://example.com/chat/completions");
    expect(init?.method).toBe("POST");
    if (!isStringRecord(init?.headers)) {
      throw new Error("AI request headers shape changed");
    }
    expect(init.headers.Authorization).toBe("Bearer test-key");
    expect(init.headers["Content-Type"]).toBe("application/json");
    if (typeof init?.body !== "string") {
      throw new Error("AI request body should be JSON text");
    }
    const parsedBody = parseJson(init.body);
    if (!isAiChatRequestBody(parsedBody)) {
      throw new Error("AI request body shape changed");
    }
    const body = parsedBody;
    expect(body.model).toBe("glm-test");
    expect(body.messages[0].role).toBe("system");
    expect(body.messages[1]).toEqual({ role: "user", content: "我是谁" });
  });
});

function isAiChatRequestBody(value: unknown): value is AiChatRequestBody {
  if (typeof value !== "object" || value === null) {
    return false;
  }
  const record = value as Record<string, unknown>;
  return (
    typeof record.model === "string" &&
    Array.isArray(record.messages) &&
    record.messages.every(
      (message) =>
        typeof message === "object" &&
        message !== null &&
        typeof (message as Record<string, unknown>).role === "string" &&
        typeof (message as Record<string, unknown>).content === "string",
    )
  );
}

function isStringRecord(value: unknown): value is Record<string, string> {
  return (
    typeof value === "object" &&
    value !== null &&
    Object.values(value).every((item) => typeof item === "string")
  );
}

function parseJson(value: string): unknown {
  return JSON.parse(value) as unknown;
}
