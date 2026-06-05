import {
  BadRequestException,
  Injectable,
  ServiceUnavailableException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";

import type { AppConfig } from "../config/configuration";

interface QWeatherNowPayload {
  code?: string;
  now?: {
    obsTime?: string;
    temp?: string;
    feelsLike?: string;
    text?: string;
    windDir?: string;
    windScale?: string;
    humidity?: string;
  };
}

interface QWeatherIndicesPayload {
  code?: string;
  daily?: Array<{
    type?: string;
    name?: string;
    level?: string;
    category?: string;
    text?: string;
  }>;
}

interface QWeatherLookupPayload {
  code?: string;
  location?: Array<{
    id?: string;
    name?: string;
    adm2?: string;
  }>;
}

export interface WeatherNowView {
  cityName: string;
  locationQuery: string;
  observedAt: string;
  temp: string;
  feelsLike: string;
  text: string;
  windDir: string;
  windScale: string;
  humidity: string;
}

export interface WeatherIndexView {
  type: string;
  name: string;
  level: string;
  category: string;
  text: string;
}

@Injectable()
export class WeatherService {
  constructor(private readonly configService: ConfigService<AppConfig, true>) {}

  async now(location?: string): Promise<WeatherNowView> {
    const resolved = await this.resolveLocation(location);
    const payload = await this.requestQWeather<QWeatherNowPayload>(
      "/v7/weather/now",
      {
        location: resolved.query,
        lang: "zh",
      },
    );
    if (!payload.now) {
      throw new ServiceUnavailableException("天气服务返回为空");
    }
    return {
      cityName: resolved.cityName,
      locationQuery: resolved.query,
      observedAt: payload.now.obsTime ?? new Date().toISOString(),
      temp: payload.now.temp ?? "--",
      feelsLike: payload.now.feelsLike ?? "--",
      text: payload.now.text ?? "未知",
      windDir: payload.now.windDir ?? "未知风向",
      windScale: payload.now.windScale ?? "--",
      humidity: payload.now.humidity ?? "--",
    };
  }

  async indices(location?: string): Promise<WeatherIndexView[]> {
    const resolved = await this.resolveLocation(location);
    const payload = await this.requestQWeather<QWeatherIndicesPayload>(
      "/v7/indices/1d",
      {
        location: resolved.query,
        type: "3,9,7",
        lang: "zh",
      },
    );
    return (payload.daily ?? [])
      .map((item) => ({
        type: item.type ?? "",
        name: item.name ?? "生活指数",
        level: item.level ?? "--",
        category: item.category ?? "--",
        text: item.text ?? "暂无建议",
      }))
      .sort((a, b) => this.indexOrder(a.type) - this.indexOrder(b.type));
  }

  private async resolveLocation(location?: string): Promise<{
    query: string;
    cityName: string;
  }> {
    const trimmed =
      location?.trim() ||
      this.configService.get("qweatherLocation", { infer: true });
    if (!trimmed) {
      throw new BadRequestException("缺少天气定位信息");
    }
    const cityName = this.configService.get("qweatherCityName", {
      infer: true,
    });
    if (!trimmed.includes(",")) {
      return { query: trimmed, cityName };
    }
    const lookup = await this.lookupLocation(trimmed);
    return lookup ?? { query: trimmed, cityName: "当前位置" };
  }

  private async lookupLocation(query: string): Promise<{
    query: string;
    cityName: string;
  } | null> {
    try {
      const payload = await this.requestQWeather<QWeatherLookupPayload>(
        "/geo/v2/city/lookup",
        {
          location: query,
          range: "cn",
          lang: "zh",
        },
      );
      const first = payload.location?.[0];
      if (!first?.id) {
        return null;
      }
      const name = first.name || first.adm2 || query;
      const cityName =
        first.adm2 && first.adm2 !== name ? `${first.adm2}${name}` : name;
      return { query: first.id, cityName };
    } catch {
      return null;
    }
  }

  private async requestQWeather<T extends { code?: string }>(
    path: string,
    query: Record<string, string>,
  ): Promise<T> {
    const apiKey = this.configService.get("qweatherApiKey", { infer: true });
    const jwt = this.configService.get("qweatherJwt", { infer: true });
    if (!apiKey && !jwt) {
      throw new ServiceUnavailableException("后端缺少和风天气凭据");
    }
    const host = this.configService.get("qweatherHost", { infer: true });
    const url = new URL(
      `https://${host.replace(/^https?:\/\//, "").split("/")[0]}${path}`,
    );
    for (const [key, value] of Object.entries(query)) {
      url.searchParams.set(key, value);
    }
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);
    try {
      const response = await fetch(url, {
        headers: jwt
          ? { Authorization: `Bearer ${jwt}` }
          : { "X-QW-Api-Key": apiKey },
        signal: controller.signal,
      });
      const data = (await response.json()) as T;
      if (!response.ok || data.code !== "200") {
        throw new ServiceUnavailableException(this.messageForCode(data.code));
      }
      return data;
    } catch (error) {
      if (error instanceof ServiceUnavailableException) {
        throw error;
      }
      throw new ServiceUnavailableException("天气服务暂时不可用");
    } finally {
      clearTimeout(timeout);
    }
  }

  private messageForCode(code?: string): string {
    if (code === "204") return "天气服务没有找到当前位置";
    if (code === "400") return "天气请求参数不正确";
    if (code === "401") return "天气认证失败，请检查后端天气凭据";
    if (code === "402") return "天气服务配额不足或已欠费";
    if (code === "403") return "天气服务无访问权限，请检查项目订阅";
    if (code === "429") return "天气请求过于频繁，请稍后再试";
    return `天气服务返回异常：${code ?? "未知错误"}`;
  }

  private indexOrder(type: string): number {
    if (type === "3") return 0;
    if (type === "9") return 1;
    if (type === "7") return 2;
    return 99;
  }
}
