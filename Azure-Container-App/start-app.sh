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

az containerapp update \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --min-replicas 1 \
  --max-replicas 1 >/dev/null

az containerapp ingress enable \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --type external \
  --target-port 80 \
  --transport auto >/dev/null

echo "Application started."
echo "URL: ${APP_URL:-run ./prepare-app.sh to refresh APP_URL}"
