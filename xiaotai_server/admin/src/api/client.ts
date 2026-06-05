import type { ApiEnvelope, ApiErrorDetail } from './types';
import {
  getAdminAccessToken,
  notifyAdminSessionExpired,
} from '../auth/storage';

const configuredApiBaseUrl = import.meta.env.VITE_API_BASE_URL?.trim();

export const apiBaseUrl =
  configuredApiBaseUrl && configuredApiBaseUrl.length > 0
    ? configuredApiBaseUrl.replace(/\/$/, '')
    : import.meta.env.PROD
      ? '/api/v1'
      : 'http://localhost:3100/api/v1';

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly code?: number,
    readonly details: ApiErrorDetail[] = [],
    readonly requestId?: string,
  ) {
    super(message);
  }
}

const statusFallbackMessage: Record<number, string> = {
  0: '无法连接后端服务，请检查后端是否启动以及地址是否正确',
  400: '请求参数不正确',
  401: '登录已失效，请重新登录',
  403: '没有权限执行该操作',
  404: '请求的资源不存在',
  409: '操作发生冲突，请刷新后重试',
  422: '提交的数据不符合要求',
  429: '请求过于频繁，请稍后再试',
  500: '服务暂时不可用，请稍后重试',
  502: '后端网关异常，请稍后重试',
  503: '服务暂时不可用，请稍后重试',
  504: '后端响应超时，请稍后重试',
};

function buildErrorMessage(
  base: string | undefined,
  status: number,
  details: ApiErrorDetail[],
): string {
  const fallback = statusFallbackMessage[status] ?? `请求失败：HTTP ${status}`;
  const head = base && base.trim().length > 0 ? base.trim() : fallback;
  if (details.length === 0) {
    return head;
  }
  const reasons = details
    .map((item) => (item.field ? `${item.field}：${item.reason}` : item.reason))
    .filter((text) => text && text.length > 0);
  if (reasons.length === 0 || head.includes(reasons[0]!)) {
    return head;
  }
  return `${head}（${reasons.join('；')}）`;
}

export async function requestApi<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  const token = getAdminAccessToken();
  const headers = new Headers(options.headers);
  if (!(options.body instanceof FormData)) {
    headers.set('Content-Type', 'application/json');
  }
  if (token) {
    headers.set('Authorization', `Bearer ${token}`);
  }

  let response: Response;
  try {
    response = await fetch(`${apiBaseUrl}${path}`, {
      ...options,
      headers,
    });
  } catch (error) {
    const reason = error instanceof Error ? error.message : '未知网络错误';
    throw new ApiError(
      `无法连接后端服务：${reason}（请确认后端已启动，地址 ${apiBaseUrl}）`,
      0,
    );
  }

  const raw = await response.text();
  const unauthorizedStatus = response.status === 401;
  if (unauthorizedStatus) {
    notifyAdminSessionExpired();
  }
  const envelope = parseEnvelope<T>(raw);
  if (!response.ok || envelope.code !== 0) {
    if (!unauthorizedStatus && envelope.code === 40100) {
      notifyAdminSessionExpired();
    }
    const details = envelope.details ?? [];
    throw new ApiError(
      buildErrorMessage(envelope.message, response.status, details),
      response.status,
      envelope.code,
      details,
      envelope.requestId,
    );
  }
  return envelope.data;
}

export interface UploadProgress {
  loaded: number;
  total: number | null;
  percent: number;
}

export function requestUpload<T>(
  path: string,
  form: FormData,
  options: {
    method?: 'POST' | 'PUT' | 'PATCH';
    onProgress?: (progress: UploadProgress) => void;
  } = {},
): Promise<T> {
  const token = getAdminAccessToken();
  const method = options.method ?? 'POST';

  return new Promise<T>((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open(method, `${apiBaseUrl}${path}`);
    if (token) {
      xhr.setRequestHeader('Authorization', `Bearer ${token}`);
    }

    xhr.upload.onprogress = (event) => {
      const total = event.lengthComputable ? event.total : null;
      const percent =
        total && total > 0
          ? Math.min(99, Math.round((event.loaded / total) * 100))
          : 0;
      options.onProgress?.({
        loaded: event.loaded,
        total,
        percent,
      });
    };

    xhr.onerror = () => {
      reject(new ApiError('无法连接后端服务，请检查网络后重试', 0));
    };
    xhr.onabort = () => {
      reject(new ApiError('上传已取消', 0));
    };
    xhr.onload = () => {
      const unauthorizedStatus = xhr.status === 401;
      if (unauthorizedStatus) {
        notifyAdminSessionExpired();
      }
      try {
        const envelope = parseEnvelope<T>(xhr.responseText);
        if (xhr.status < 200 || xhr.status >= 300 || envelope.code !== 0) {
          if (!unauthorizedStatus && envelope.code === 40100) {
            notifyAdminSessionExpired();
          }
          const details = envelope.details ?? [];
          reject(
            new ApiError(
              buildErrorMessage(envelope.message, xhr.status, details),
              xhr.status,
              envelope.code,
              details,
              envelope.requestId,
            ),
          );
          return;
        }
        options.onProgress?.({
          loaded: 1,
          total: 1,
          percent: 100,
        });
        resolve(envelope.data);
      } catch (error) {
        reject(error);
      }
    };

    xhr.send(form);
  });
}

export async function requestBlob(
  path: string,
  options: RequestInit = {},
): Promise<Blob> {
  const token = getAdminAccessToken();
  const headers = new Headers(options.headers);
  if (token) {
    headers.set('Authorization', `Bearer ${token}`);
  }

  let response: Response;
  try {
    response = await fetch(`${apiBaseUrl}${path}`, { ...options, headers });
  } catch (error) {
    const reason = error instanceof Error ? error.message : '未知网络错误';
    throw new ApiError(
      `无法下载文件：${reason}（地址 ${apiBaseUrl}）`,
      0,
    );
  }
  if (!response.ok) {
    if (response.status === 401) {
      notifyAdminSessionExpired();
    }
    let detailText = '';
    try {
      const text = await response.text();
      if (text) {
        const parsed = JSON.parse(text) as ApiEnvelope<unknown>;
        if (parsed && typeof parsed.message === 'string') {
          detailText = `：${parsed.message}`;
        }
      }
    } catch {
      // ignore: body 可能不是 JSON
    }
    throw new ApiError(
      `${statusFallbackMessage[response.status] ?? `文件请求失败：HTTP ${response.status}`}${detailText}`,
      response.status,
    );
  }
  return response.blob();
}

export async function requestDownloadBlob(
  url: string,
  options: RequestInit = {},
): Promise<Blob> {
  let response: Response;
  try {
    response = await fetch(url, options);
  } catch (error) {
    const reason = error instanceof Error ? error.message : '未知网络错误';
    throw new ApiError(`无法下载文件：${reason}`, 0);
  }

  if (!response.ok) {
    let detailText = '';
    try {
      const text = await response.text();
      if (text) {
        const parsed = JSON.parse(text) as ApiEnvelope<unknown>;
        if (parsed && typeof parsed.message === 'string') {
          detailText = `：${parsed.message}`;
        }
      }
    } catch {
      // ignore: download response may be binary or plain text.
    }
    throw new ApiError(
      `${statusFallbackMessage[response.status] ?? `文件下载失败：HTTP ${response.status}`}${detailText}`,
      response.status,
    );
  }

  return response.blob();
}

export function resolveApiAssetUrl(path: string): string {
  if (/^https?:\/\//i.test(path)) {
    return path;
  }
  if (apiBaseUrl.startsWith('/')) {
    return path;
  }
  return `${apiBaseUrl.replace(/\/api\/v1$/, '')}${path}`;
}

function parseEnvelope<T>(raw: string): ApiEnvelope<T> {
  if (!raw) {
    return { code: -1, data: null as T, message: '后端没有返回内容' };
  }
  let decoded: unknown;
  try {
    decoded = JSON.parse(raw);
  } catch (error) {
    const reason = error instanceof Error ? error.message : '未知 JSON 错误';
    const preview = raw.length > 120 ? `${raw.slice(0, 120)}…` : raw;
    throw new ApiError(`后端响应不是合法 JSON：${reason}（原始内容：${preview}）`, 0);
  }
  if (!isEnvelope(decoded)) {
    throw new ApiError('后端响应格式不正确，缺少 code/data/message 字段', 0);
  }
  return decoded as ApiEnvelope<T>;
}

function isEnvelope(value: unknown): value is ApiEnvelope<unknown> {
  if (typeof value !== 'object' || value === null) {
    return false;
  }
  const record = value as Record<string, unknown>;
  return (
    typeof record.code === 'number' &&
    'data' in record &&
    typeof record.message === 'string'
  );
}
