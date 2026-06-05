import { Injectable, ServiceUnavailableException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";

import type { AppConfig } from "../config/configuration";

interface BigModelChatPayload {
  choices?: BigModelChoice[];
  error?: {
    message?: string;
  };
  message?: string;
}

interface BigModelChoice {
  message?: {
    content?: unknown;
    reasoning_content?: unknown;
  };
  delta?: {
    content?: unknown;
  };
}

export interface AiChatView {
  answer: string;
  model: string;
}

@Injectable()
export class AiService {
  constructor(private readonly configService: ConfigService<AppConfig, true>) {}

  async chat(message: string): Promise<AiChatView> {
    const trimmed = message.trim();
    if (!trimmed) {
      throw new ServiceUnavailableException("先写一点想问小助手的内容吧");
    }
    const apiKey = this.configService.get("bigModelApiKey", { infer: true });
    if (!apiKey) {
      throw new ServiceUnavailableException("后端缺少 BIGMODEL_API_KEY");
    }
    const endpoint = this.configService.get("bigModelEndpoint", {
      infer: true,
    });
    const model = this.configService.get("bigModelModel", { infer: true });
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 18000);
    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          messages: [
            {
              role: "system",
              content:
                "你是婷婷小笨笔记里的生活助手。必须优先回答用户原问题，不要改变问题类型。用户消息可能包含应用上下文、个人资料、最近记录和最近对话，这些内容视为可信背景；用户询问身份、人物关系或最近记录时必须优先使用这些背景，不要泛泛回答。回答要简短、具体、直接；只有当用户明确询问天气、穿衣、出门或城市情况时，才结合天气背景给建议。不要使用横线、下划线或空白占位。",
            },
            { role: "user", content: trimmed },
          ],
          thinking: { type: "disabled" },
          max_tokens: 1024,
          stream: false,
        }),
        signal: controller.signal,
      });
      const payload = (await response.json()) as BigModelChatPayload;
      if (!response.ok) {
        throw new ServiceUnavailableException(
          this.messageForStatus(response.status, payload),
        );
      }
      const choice = payload.choices?.[0];
      const answer = this.extractChoiceContent(choice).trim();
      if (!answer) {
        throw new ServiceUnavailableException(
          "AI 暂时没有返回有效回复，请稍后再试",
        );
      }
      return { answer, model };
    } catch (error) {
      if (error instanceof ServiceUnavailableException) {
        throw error;
      }
      throw new ServiceUnavailableException("AI 服务暂时不可用，请稍后再试");
    } finally {
      clearTimeout(timeout);
    }
  }

  private extractChoiceContent(choice: BigModelChoice | undefined): string {
    if (!choice) {
      return "";
    }
    const content = this.stringifyContent(choice.message?.content);
    if (content) {
      return content;
    }
    const reasoning = this.stringifyContent(choice.message?.reasoning_content);
    if (reasoning) {
      return reasoning;
    }
    return this.stringifyContent(choice.delta?.content);
  }

  private stringifyContent(content: unknown): string {
    if (content == null) {
      return "";
    }
    if (typeof content === "string") {
      return content.trim();
    }
    if (Array.isArray(content)) {
      return content
        .map((item) => this.stringifyContentItem(item))
        .join("")
        .trim();
    }
    if (
      typeof content === "number" ||
      typeof content === "boolean" ||
      typeof content === "bigint"
    ) {
      return String(content).trim();
    }
    if (typeof content === "object") {
      try {
        return JSON.stringify(content).trim();
      } catch {
        return "";
      }
    }
    return "";
  }

  private stringifyContentItem(item: unknown): string {
    if (typeof item === "string") {
      return item;
    }
    if (typeof item === "object" && item !== null) {
      const record = item as Record<string, unknown>;
      return (
        this.stringifyContent(record.text) ||
        this.stringifyContent(record.content)
      );
    }
    return this.stringifyContent(item);
  }

  private messageForStatus(
    statusCode: number,
    payload: BigModelChatPayload,
  ): string {
    const detail = payload.error?.message ?? payload.message;
    const message = (() => {
      if (statusCode === 401) return "AI 认证失败，请检查后端 BIGMODEL_API_KEY";
      if (statusCode === 403) return "AI 服务无访问权限，请检查模型权限";
      if (statusCode === 429)
        return "AI 请求过于频繁或额度暂不可用，请稍后再试";
      if (statusCode === 500 || statusCode === 502 || statusCode === 503) {
        return "AI 服务暂时不可用，请稍后再试";
      }
      return `AI 服务暂时不可用：HTTP ${statusCode}`;
    })();
    if (!detail) {
      return message;
    }
    return `${message}（${detail}）`;
  }
}
