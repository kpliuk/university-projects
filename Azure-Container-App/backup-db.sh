#!/bin/bash
set -euo pipefail

ENV_FILE=".skuska.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "$ENV_FILE was not found. Run prepare-app.sh first."
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

BACKUP_FILE="backup-${DB_NAME}-$(date +%Y%m%d-%H%M%S).sql"
TMP_DIR="$(mktemp -d)"

STORAGE_KEY="$(az storage account keys list \
  --resource-group "$RESOURCE_GROUP" \
  --account-name "$STORAGE_ACCOUNT" \
  --query "[0].value" \
  -o tsv)"

az storage file download \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" \
  --share-name "$STORAGE_SHARE" \
  --path latest.sql \
  --dest "$TMP_DIR" >/dev/null

mv "$TMP_DIR/latest.sql" "$BACKUP_FILE"
rmdir "$TMP_DIR"

echo "Backup saved to $BACKUP_FILE"
