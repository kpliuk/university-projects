#!/bin/bash
set -euo pipefail

ENV_FILE=".skuska.env"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

RESOURCE_GROUP="${RESOURCE_GROUP:-skuska-rg}"
APP_NAME="${APP_NAME:-skuska-app}"

echo "Frontend logs:"
az containerapp logs show --resource-group "$RESOURCE_GROUP" --name "$APP_NAME" --container frontend --tail 50

echo
echo "Backend logs:"
az containerapp logs show --resource-group "$RESOURCE_GROUP" --name "$APP_NAME" --container backend --tail 50

echo
echo "Postgres logs:"
az containerapp logs show --resource-group "$RESOURCE_GROUP" --name "$APP_NAME" --container postgres --tail 50
