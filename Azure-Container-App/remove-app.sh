#!/bin/bash
set -euo pipefail

ENV_FILE=".skuska.env"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

RESOURCE_GROUP="${RESOURCE_GROUP:-skuska-rg}"

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI is required."
  exit 1
fi

az account show >/dev/null

if [ -x "./backup-db.sh" ] && [ -f "$ENV_FILE" ]; then
  echo "Creating final database backup before removing Azure resources..."

  if ./backup-db.sh; then
    echo "Final database backup created."
  else
    echo "WARNING: Final database backup failed. Resources will still be removed."
  fi
else
  echo "Skipping final backup because backup-db.sh or $ENV_FILE was not found."
fi

echo "Deleting Azure resource group: $RESOURCE_GROUP"
az group delete --name "$RESOURCE_GROUP" --yes --no-wait

echo "Delete started. Azure will remove all application resources in this resource group."
