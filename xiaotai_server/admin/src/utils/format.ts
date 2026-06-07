export function formatDateTime(value?: string | null): string {
  if (!value) {
    return "-";
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "-";
  }
  return formatChineseDateTime(date);
}

export function formatDateTimeFull(value?: string | null): string {
  return formatDateTime(value);
}

function formatChineseDateTime(date: Date): string {
  return `${date.getFullYear()}年${pad2(date.getMonth() + 1)}月${pad2(
    date.getDate(),
  )}日 ${pad2(date.getHours())}:${pad2(date.getMinutes())}:${pad2(
    date.getSeconds(),
  )}`;
}

function pad2(value: number): string {
  return String(value).padStart(2, "0");
}

export function formatCount(value: number): string {
  return new Intl.NumberFormat("zh-CN").format(value);
}

export function formatFileSize(value?: number | null): string {
  if (!value || value <= 0) {
    return "-";
  }
  const units = ["B", "KB", "MB", "GB"];
  let size = value;
  let index = 0;
  while (size >= 1024 && index < units.length - 1) {
    size /= 1024;
    index += 1;
  }
  return `${size.toFixed(index === 0 ? 0 : 1)} ${units[index]}`;
}

export function typeLabel(type: string): string {
  const labels: Record<string, string> = {
    entry: "记录",
    memo: "备忘录",
    reminder: "提醒",
    weekly_goal: "本周目标",
    anniversary: "纪念日",
    place: "想去的地方",
    couple_task: "情侣事项",
    money_record: "记账",
    ai_message: "AI 对话",
    ai_memory: "AI 记忆",
    settings: "设置",
    weather_cache: "天气缓存",
  };
  return labels[type] ?? type;
}
