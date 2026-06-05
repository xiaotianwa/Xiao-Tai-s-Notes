import {
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { createHash, createHmac } from "node:crypto";
import { createReadStream } from "node:fs";
import { copyFile, mkdir, readFile, rm, stat, writeFile } from "node:fs/promises";
import { basename, dirname } from "node:path";

import type { AppConfig } from "../../config/configuration";

const cosLocatorPrefix = "cos://";

export interface StoredObject {
  locator: string;
}

export interface StoreObjectInput {
  key: string;
  localPath: string;
  buffer?: Buffer;
  sourcePath?: string;
  contentType: string;
}

export interface ReadObjectInput {
  locator?: string | null;
  key?: string;
  localPath?: string;
  fileName?: string;
  contentType: string;
}

@Injectable()
export class ObjectStorageService {
  constructor(private readonly configService: ConfigService<AppConfig, true>) {}

  get cosEnabled(): boolean {
    return this.configService.get("cos", { infer: true }).enabled;
  }

  async putObject(input: StoreObjectInput): Promise<StoredObject> {
    if (!input.buffer && !input.sourcePath) {
      throw new ServiceUnavailableException("Storage source is required");
    }

    if (!this.cosEnabled) {
      await mkdir(dirname(input.localPath), { recursive: true });
      if (input.sourcePath) {
        await copyFile(input.sourcePath, input.localPath);
      } else if (input.buffer) {
        await writeFile(input.localPath, input.buffer);
      }
      return { locator: input.localPath };
    }

    const key = this.objectKey(input.key);
    const body = input.buffer ?? createReadStream(input.sourcePath!);
    const contentLength = input.buffer?.length ?? (await stat(input.sourcePath!)).size;
    await this.cosRequest("PUT", key, body, input.contentType, contentLength);
    return { locator: this.toCosLocator(key) };
  }

  async readObject(input: ReadObjectInput): Promise<{
    fileName: string;
    contentType: string;
    bytes: Buffer;
  }> {
    const locator = input.locator ?? null;
    if (locator && this.isCosLocator(locator)) {
      return this.readCosObject(
        this.keyFromLocator(locator),
        input.fileName,
        input.contentType,
      );
    }

    if (input.key && this.cosEnabled) {
      try {
        return await this.readCosObject(
          this.objectKey(input.key),
          input.fileName,
          input.contentType,
        );
      } catch (error) {
        if (!this.isNotFoundError(error) || !input.localPath) {
          throw error;
        }
      }
    }

    if (locator && !this.isCosLocator(locator)) {
      return this.readLocalObject(locator, input.fileName, input.contentType);
    }
    if (input.localPath) {
      return this.readLocalObject(
        input.localPath,
        input.fileName,
        input.contentType,
      );
    }
    throw new NotFoundException("File does not exist");
  }

  async deleteObject(locatorOrPath: string): Promise<void> {
    if (this.isCosLocator(locatorOrPath)) {
      await this.cosRequest("DELETE", this.keyFromLocator(locatorOrPath)).catch(
        (error: unknown) => {
          if (!this.isNotFoundError(error)) {
            throw error;
          }
        },
      );
      return;
    }
    await rm(locatorOrPath, { force: true });
  }

  isCosLocator(value: string): boolean {
    return value.startsWith(cosLocatorPrefix);
  }

  fileNameFromLocator(locator: string): string {
    return basename(
      this.isCosLocator(locator) ? this.keyFromLocator(locator) : locator,
    );
  }

  publicUrl(locatorOrPath: string): string | null {
    if (!this.isCosLocator(locatorOrPath)) {
      return null;
    }
    const key = this.keyFromLocator(locatorOrPath);
    const publicBaseUrl = this.configService
      .get("cos", { infer: true })
      .publicBaseUrl.replace(/\/+$/g, "");
    if (publicBaseUrl) {
      return `${publicBaseUrl}/${this.encodeObjectPath(key)}`;
    }
    return `https://${this.cosBucket()}.cos.${this.cosRegion()}.myqcloud.com/${this.encodeObjectPath(key)}`;
  }

  objectKey(key: string): string {
    const cleanKey = key.replace(/^\/+/, "").replace(/\\/g, "/");
    const prefix = this.configService
      .get("cos", { infer: true })
      .prefix.replace(/^\/+|\/+$/g, "")
      .replace(/\\/g, "/");
    return prefix ? `${prefix}/${cleanKey}` : cleanKey;
  }

  private async readCosObject(
    key: string,
    fileName: string | undefined,
    contentType: string,
  ) {
    try {
      const response = await this.cosRequest("GET", key);
      const bytes = Buffer.from(await response.arrayBuffer());
      return {
        fileName: fileName ?? basename(key),
        contentType,
        bytes,
      };
    } catch (error) {
      if (this.isNotFoundError(error)) {
        throw new NotFoundException("File does not exist");
      }
      throw new ServiceUnavailableException("Object storage is unavailable");
    }
  }

  private async readLocalObject(
    path: string,
    fileName: string | undefined,
    contentType: string,
  ) {
    const bytes = await readFile(path).catch(() => null);
    if (!bytes) {
      throw new NotFoundException("File does not exist");
    }
    return {
      fileName: fileName ?? basename(path),
      contentType,
      bytes,
    };
  }

  private async cosRequest(
    method: "GET" | "PUT" | "DELETE",
    key: string,
    body?: Buffer | NodeJS.ReadableStream,
    contentType?: string,
    contentLength?: number,
  ): Promise<Response> {
    const host = `${this.cosBucket()}.cos.${this.cosRegion()}.myqcloud.com`;
    const path = `/${this.encodeObjectPath(key)}`;
    const headers: Record<string, string> = {
      Authorization: this.authorization(method, path, host),
    };
    if (contentType) {
      headers["Content-Type"] = contentType;
    }
    if (contentLength !== undefined) {
      headers["Content-Length"] = String(contentLength);
    }
    const requestBody = Buffer.isBuffer(body)
      ? body.buffer.slice(body.byteOffset, body.byteOffset + body.byteLength)
      : body;

    const response = await fetch(`https://${host}${path}`, {
      method,
      headers,
      body: requestBody as BodyInit | undefined,
      duplex: body && !Buffer.isBuffer(body) ? "half" : undefined,
    } as RequestInit & { duplex?: "half" });
    if (response.status === 404) {
      throw new NotFoundException("File does not exist");
    }
    if (!response.ok) {
      throw new ServiceUnavailableException("Object storage is unavailable");
    }
    return response;
  }

  private authorization(
    method: "GET" | "PUT" | "DELETE",
    path: string,
    host: string,
  ): string {
    const cos = this.configService.get("cos", { infer: true });
    const now = Math.floor(Date.now() / 1000);
    const keyTime = `${now};${now + 600}`;
    const headerString = `host=${encodeURIComponent(host)}`;
    const httpString = `${method.toLowerCase()}\n${path}\n\n${headerString}\n`;
    const stringToSign = `sha1\n${keyTime}\n${this.sha1(httpString)}\n`;
    const signKey = this.hmacSha1(cos.secretKey, keyTime);
    const signature = this.hmacSha1(signKey, stringToSign);

    return [
      "q-sign-algorithm=sha1",
      `q-ak=${encodeURIComponent(cos.secretId)}`,
      `q-sign-time=${keyTime}`,
      `q-key-time=${keyTime}`,
      "q-header-list=host",
      "q-url-param-list=",
      `q-signature=${signature}`,
    ].join("&");
  }

  private encodeObjectPath(key: string): string {
    return key
      .split("/")
      .map((part) => encodeURIComponent(part))
      .join("/");
  }

  private sha1(value: string): string {
    return createHash("sha1").update(value).digest("hex");
  }

  private hmacSha1(key: string, value: string): string {
    return createHmac("sha1", key).update(value).digest("hex");
  }

  private cosBucket(): string {
    return this.configService.get("cos", { infer: true }).bucket;
  }

  private cosRegion(): string {
    return this.configService.get("cos", { infer: true }).region;
  }

  private toCosLocator(key: string): string {
    return `${cosLocatorPrefix}${key}`;
  }

  private keyFromLocator(locator: string): string {
    return locator.slice(cosLocatorPrefix.length);
  }

  private isNotFoundError(error: unknown): boolean {
    if (error instanceof NotFoundException) {
      return true;
    }
    if (typeof error !== "object" || error === null) {
      return false;
    }
    const record = error as {
      status?: number;
      statusCode?: number;
      code?: string;
    };
    return (
      record.status === 404 ||
      record.statusCode === 404 ||
      record.code === "NoSuchKey"
    );
  }
}
