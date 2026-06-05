#!/usr/bin/env bash
set -euo pipefail

BACKEND_DIR="${BACKEND_DIR:-/opt/xiaotai/xiaotai_server/backend}"
ENV_FILE="${ENV_FILE:-$BACKEND_DIR/.env}"
BACKUP_DIR="${BACKUP_DIR:-/opt/xiaotai/backups/postgres}"
NODE_BIN="${NODE_BIN:-/www/server/nodejs/v20.20.2/bin/node}"
LOCAL_RETENTION_DAYS="${LOCAL_RETENTION_DAYS:-14}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }
die() { echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2; exit 1; }

[[ -f "$ENV_FILE" ]] || die "env file not found: $ENV_FILE"
command -v pg_dump >/dev/null 2>&1 || die "pg_dump is required"
[[ -x "$NODE_BIN" ]] || die "node is required: $NODE_BIN"

mkdir -p "$BACKUP_DIR"

timestamp="$(date '+%Y%m%d%H%M%S')"
backup_file="$BACKUP_DIR/xiaotai-postgres-$timestamp.sql.gz"

database_url="$(
  grep -E '^DATABASE_URL=' "$ENV_FILE" | tail -n 1 | cut -d= -f2-
)"
[[ -n "$database_url" ]] || die "DATABASE_URL is missing"
pg_dump_url="${database_url%%\?*}"

log "dumping postgresql database"
pg_dump "$pg_dump_url" | gzip -9 > "$backup_file"

log "uploading backup to COS"
"$NODE_BIN" - "$ENV_FILE" "$backup_file" <<'NODE'
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const [, , envFile, backupFile] = process.argv;

function readEnv(file) {
  const values = {};
  for (const line of fs.readFileSync(file, "utf8").split(/\r?\n/)) {
    const match = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (match) {
      values[match[1]] = match[2].replace(/^['"]|['"]$/g, "");
    }
  }
  return values;
}

function sha1(value) {
  return crypto.createHash("sha1").update(value).digest("hex");
}

function hmacSha1(key, value) {
  return crypto.createHmac("sha1", key).update(value).digest("hex");
}

function encodeObjectPath(key) {
  return key
    .split("/")
    .map((part) => encodeURIComponent(part))
    .join("/");
}

function authorization(method, objectPath, host, secretId, secretKey) {
  const now = Math.floor(Date.now() / 1000);
  const keyTime = `${now};${now + 600}`;
  const headerString = `host=${encodeURIComponent(host)}`;
  const httpString = `${method.toLowerCase()}\n${objectPath}\n\n${headerString}\n`;
  const stringToSign = `sha1\n${keyTime}\n${sha1(httpString)}\n`;
  const signKey = hmacSha1(secretKey, keyTime);
  const signature = hmacSha1(signKey, stringToSign);
  return [
    "q-sign-algorithm=sha1",
    `q-ak=${encodeURIComponent(secretId)}`,
    `q-sign-time=${keyTime}`,
    `q-key-time=${keyTime}`,
    "q-header-list=host",
    "q-url-param-list=",
    `q-signature=${signature}`,
  ].join("&");
}

async function main() {
  const env = readEnv(envFile);
  for (const key of ["COS_BUCKET", "COS_REGION", "COS_SECRET_ID", "COS_SECRET_KEY"]) {
    if (!env[key]) {
      throw new Error(`${key} is missing`);
    }
  }

  const prefix = (env.COS_PREFIX || "xiaotai").replace(/^\/+|\/+$/g, "");
  const objectKey = [prefix, "backups", "postgres", path.basename(backupFile)]
    .filter(Boolean)
    .join("/");
  const host = `${env.COS_BUCKET}.cos.${env.COS_REGION}.myqcloud.com`;
  const objectPath = `/${encodeObjectPath(objectKey)}`;
  const bytes = fs.readFileSync(backupFile);

  const response = await fetch(`https://${host}${objectPath}`, {
    method: "PUT",
    headers: {
      Authorization: authorization("PUT", objectPath, host, env.COS_SECRET_ID, env.COS_SECRET_KEY),
      "Content-Type": "application/gzip",
      "Content-Length": String(bytes.length),
    },
    body: bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength),
  });

  if (!response.ok) {
    throw new Error(`COS upload failed: ${response.status} ${await response.text()}`);
  }
  console.log(`cos://${objectKey}`);
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
NODE

find "$BACKUP_DIR" -type f -name 'xiaotai-postgres-*.sql.gz' -mtime "+$LOCAL_RETENTION_DAYS" -delete
log "backup completed: $backup_file"
