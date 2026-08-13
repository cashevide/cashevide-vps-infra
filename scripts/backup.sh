#!/bin/bash
set -euo pipefail

# --- Config ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
CASHEVIDE_DIR="/opt/cashevide-api"
BACKUP_DIR="/opt/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="cashevide_backup_${TIMESTAMP}.sql"

# --- Load R2 credentials from this repo's own .env ---
if [ -f "$INFRA_DIR/.env" ]; then
  set -a
  source "$INFRA_DIR/.env"
  set +a
else
  echo "ERROR: $INFRA_DIR/.env not found. Copy .env.example and fill it in."
  exit 1
fi

# --- Load DB credentials from cashevide-api's .env ---
if [ -f "$CASHEVIDE_DIR/.env" ]; then
  set -a
  source "$CASHEVIDE_DIR/.env"
  set +a
else
  echo "ERROR: $CASHEVIDE_DIR/.env not found."
  exit 1
fi

mkdir -p "$BACKUP_DIR"

# --- 1. Dump the database ---
echo "[$(date)] Starting backup: $BACKUP_FILE"
cd "$CASHEVIDE_DIR"
docker compose exec -T db pg_dump -U "$DB_USER" --clean --if-exists "$DB_NAME" >"$BACKUP_DIR/$BACKUP_FILE"

if [ ! -s "$BACKUP_DIR/$BACKUP_FILE" ]; then
  echo "ERROR: Backup file is empty. Aborting upload."
  exit 1
fi
echo "[$(date)] Dump complete: $(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)"

# --- 2. Upload to Cloudflare R2 (S3-compatible API) ---
echo "[$(date)] Uploading to R2..."
AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
  AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
  aws s3 cp "$BACKUP_DIR/$BACKUP_FILE" "s3://$R2_BUCKET_NAME/$BACKUP_FILE" \
  --endpoint-url "$R2_ENDPOINT"

echo "[$(date)] Upload complete."

# --- 3. Clean up old local backups ---
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
echo "[$(date)] Removing local backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "cashevide_backup_*.sql" -mtime +"$RETENTION_DAYS" -delete

echo "[$(date)] Backup finished successfully."
