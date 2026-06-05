#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-/www/wwwroot/xiaotai}"
SERVER_DIR="${PROJECT_ROOT}/xiaotai_server"
BACKEND_DIR="${SERVER_DIR}/backend"
ADMIN_DIR="${SERVER_DIR}/admin"
SERVICE_NAME="${SERVICE_NAME:-xiaotai-backend}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }
die() { echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2; exit 1; }

require_file() {
  local file="$1"
  [[ -f "$file" ]] || die "missing required file: $file"
}

require_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || die "missing required directory: $dir"
}

main() {
  require_dir "$SERVER_DIR"
  require_dir "$BACKEND_DIR"
  require_dir "$ADMIN_DIR"
  require_file "${BACKEND_DIR}/.env"
  require_file "${ADMIN_DIR}/.env.production"

  log "Remove local-only files from server project root"
  find "$PROJECT_ROOT" -mindepth 1 -maxdepth 1 \
    ! -name "xiaotai_server" \
    ! -name "deploy" \
    ! -name ".user.ini" \
    -exec rm -rf -- {} +

  log "Remove generated and development-only files"
  rm -rf -- \
    "${SERVER_DIR}/.idea" \
    "${ADMIN_DIR}/dist" \
    "${ADMIN_DIR}/node_modules" \
    "${ADMIN_DIR}/admin.dev.err.log" \
    "${ADMIN_DIR}/admin.dev.out.log" \
    "${ADMIN_DIR}/tsconfig.tsbuildinfo" \
    "${ADMIN_DIR}/tsconfig.node.tsbuildinfo" \
    "${BACKEND_DIR}/dist" \
    "${BACKEND_DIR}/node_modules"

  log "Install backend dependencies"
  cd "$BACKEND_DIR"
  npm ci
  npm run prisma:generate
  if ! npm run prisma:deploy 2>&1 | tee /tmp/xiaotai-prisma-migrate.log; then
    if grep -q "P3005" /tmp/xiaotai-prisma-migrate.log; then
      log "Prisma migrate skipped: existing production database has not been baselined"
      database_url="$(
        grep -E '^DATABASE_URL=' "${BACKEND_DIR}/.env" | tail -n 1 | cut -d= -f2- | tr -d "\"'"
      )"
      if [[ "$database_url" == file:* ]]; then
        log "Sync local SQLite schema with current Prisma schema"
        npm run prisma:db-push -- --accept-data-loss --skip-generate
      else
        log "Non-SQLite database is not baselined; schema push skipped"
      fi
    else
      die "Prisma migrate deploy failed"
    fi
  fi
  npm run build

  log "Install admin dependencies and build static assets"
  cd "$ADMIN_DIR"
  npm ci
  npm run build

  log "Restart PM2 service"
  if pm2 describe "$SERVICE_NAME" >/dev/null 2>&1; then
    pm2 restart "$SERVICE_NAME" --update-env
  else
    pm2 start "${SERVER_DIR}/ecosystem.config.cjs"
  fi
  pm2 save

  log "Verify backend health"
  for attempt in {1..20}; do
    if curl -fsS "http://127.0.0.1:3100/health" >/dev/null; then
      break
    fi
    if [[ "$attempt" -eq 20 ]]; then
      die "backend health check failed"
    fi
    sleep 1
  done
  rm -rf -- "${PROJECT_ROOT}/deploy"
  log "Done"
}

main "$@"
