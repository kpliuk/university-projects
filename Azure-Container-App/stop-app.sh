#!/bin/bash
set -euo pipefail

ENV_FILE=".skuska.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "$ENV_FILE was not found. Run prepare-app.sh first."
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI is required."
  exit 1
fi

az account show >/dev/null

echo "Creating final database backup before stopping the app..."
if [ -x "./backup-db.sh" ]; then
  ./backup-db.sh || echo "WARNING: Backup failed, continuing with stop."
fi

az containerapp update \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --min-replicas 0 \
  --max-replicas 1 >/dev/null

az containerapp ingress disable \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" >/dev/null

echo "Application stopped."
echo "Minimum replicas set to 0 and public ingress disabled."
echo "The app can be started again with ./start-app.sh."
