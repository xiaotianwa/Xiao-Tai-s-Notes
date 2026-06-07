import type { AdminSyncItem } from "../api/types";
import { formatDateTime, typeLabel } from "./format";

export interface SyncBusinessSummary {
  title: string;
  description: string;
  meta: string[];
}

export function buildSyncItemSummary(item: AdminSyncItem): SyncBusinessSummary {
  const data = readRecord(item.data);
  const deletedPrefix = item.deletedAt ? "已删除 · " : "";
  const fallbackTitle = `${deletedPrefix}${typeLabel(item.type)} / ${item.clientId}`;
  switch (item.type) {
    case "entry":
      return {
        title: deletedPrefix + firstText(data, ["title"], fallbackTitle),
        description: clipText(firstText(data, ["content"], "暂无正文")),
        meta: compact([
          firstText(data, ["kindLabel", "kind"]),
          firstText(data, ["mood"]),
          readStringList(data, "tags").join("、"),
        ]),
      };
    case "memo":
      return {
        title: deletedPrefix + firstText(data, ["title"], fallbackTitle),
        description: clipText(firstText(data, ["content"], "暂无内容")),
        meta: compact([
          readBoolean(data, "pinned") ? "置顶" : "",
          firstText(data, ["mood"]),
          readStringList(data, "tags").join("、"),
        ]),
      };
    case "reminder":
      return {
        title: deletedPrefix + firstText(data, ["title"], fallbackTitle),
        description: compact([
          formatDateTime(readString(data, "scheduledAt")),
          firstText(data, ["repeatRule"]),
        ]).join(" · "),
        meta: compact([
          readBoolean(data, "completed") ? "已完成" : "待提醒",
          firstText(data, ["priority"]),
        ]),
      };
    case "anniversary":
      return {
        title: deletedPrefix + firstText(data, ["title"], fallbackTitle),
        description: compact([
          formatDateTime(readString(data, "date")),
          firstText(data, ["note"], "暂无备注"),
        ]).join(" · "),
        meta: compact([
          firstText(data, ["category"]),
          readBoolean(data, "showCountUp") ? "正数日" : "倒数日",
          readBoolean(data, "pinnedOnHome") ? "首页显示" : "",
        ]),
      };
    case "place":
      return {
        title: deletedPrefix + firstText(data, ["title"], fallbackTitle),
        description: clipText(firstText(data, ["description"], "暂无描述")),
        meta: compact([
          firstText(data, ["category"]),
          firstText(data, ["colorName"]),
        ]),
      };
    case "couple_task":
      return {
        title: deletedPrefix + firstText(data, ["title"], fallbackTitle),
        description: compact([
          readBoolean(data, "completed") ? "已完成" : "未完成",
          formatDateTime(readString(data, "completedAt")),
        ]).join(" · "),
        meta: compact([`序号 ${readNumber(data, "index") ?? "-"}`]),
      };
    case "weekly_goal":
      return {
        title: deletedPrefix + firstText(data, ["title"], fallbackTitle),
        description: formatGoalProgress(data),
        meta: compact([
          firstText(data, ["period"]),
          firstText(data, ["unit"]),
          firstText(data, ["colorName"]),
        ]),
      };
    case "money_record":
      return {
        title: deletedPrefix + firstText(data, ["title"], fallbackTitle),
        description: compact([
          readString(data, "type") === "income" ? "收入" : "支出",
          formatAmount(readNumber(data, "amountCents")),
          firstText(data, ["category"]),
          formatDateTime(readString(data, "happenedAt")),
        ]).join(" · "),
        meta: compact([
          firstText(data, ["owner"]),
          firstText(data, ["paymentMethod"]),
        ]),
      };
    case "ai_message":
      return {
        title:
          deletedPrefix +
          `${aiRoleLabel(readString(data, "role"))} / ${item.clientId}`,
        description: clipText(firstText(data, ["content"], "暂无对话内容")),
        meta: compact([formatDateTime(readString(data, "createdAt"))]),
      };
    case "settings":
      return {
        title: `${deletedPrefix}个人资料与偏好设置`,
        description: compact([
          firstText(data, ["profileName"]),
          firstText(data, ["profileMotto"]),
          `主题 ${firstText(data, ["themeId"], "-")}`,
        ]).join(" · "),
        meta: compact([
          readBoolean(data, "notificationsEnabled") ? "通知开启" : "通知关闭",
          readBoolean(data, "lockPreviewEnabled") ? "锁屏预览" : "",
        ]),
      };
    default:
      return {
        title:
          deletedPrefix + firstText(data, ["title", "name", "id"], fallbackTitle),
        description: clipText(JSON.stringify(data)),
        meta: [],
      };
  }
}

function readRecord(value: unknown): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

function firstText(
  data: Record<string, unknown>,
  keys: string[],
  fallback = "",
): string {
  for (const key of keys) {
    const value = readString(data, key);
    if (value) {
      return value;
    }
  }
  return fallback;
}

function readString(data: Record<string, unknown>, key: string): string {
  const value = data[key];
  if (typeof value === "string") {
    return value.trim();
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  return "";
}

function readNumber(
  data: Record<string, unknown>,
  key: string,
): number | undefined {
  const value = data[key];
  return typeof value === "number" && Number.isFinite(value)
    ? value
    : undefined;
}

function readBoolean(data: Record<string, unknown>, key: string): boolean {
  return data[key] === true;
}

function readStringList(
  data: Record<string, unknown>,
  key: string,
): string[] {
  const value = data[key];
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter((item): item is string => typeof item === "string");
}

function compact(values: Array<string | undefined>): string[] {
  return values
    .map((value) => value?.trim() ?? "")
    .filter(
      (value, index, array) => value.length > 0 && array.indexOf(value) === index,
    );
}

function clipText(value: string): string {
  const normalized = value.replace(/\s+/g, " ").trim();
  if (!normalized) {
    return "-";
  }
  return normalized.length > 86 ? `${normalized.slice(0, 86)}...` : normalized;
}

function formatGoalProgress(data: Record<string, unknown>): string {
  const current = readNumber(data, "currentValue");
  const target = readNumber(data, "targetValue");
  const unit = readString(data, "unit");
  if (current === undefined && target === undefined) {
    return "暂无进度";
  }
  return `${current ?? 0}/${target ?? "-"}${unit}`;
}

function formatAmount(cents?: number): string {
  if (cents === undefined) {
    return "金额未知";
  }
  return `${(cents / 100).toFixed(2)} 元`;
}

function aiRoleLabel(role: string): string {
  if (role === "user") {
    return "用户";
  }
  if (role === "assistant") {
    return "助手";
  }
  return role || "AI 对话";
}
