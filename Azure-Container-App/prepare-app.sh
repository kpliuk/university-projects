#!/bin/bash
set -euo pipefail

REQUESTED_LOCATION="${LOCATION:-}"
REQUESTED_RESOURCE_GROUP="${RESOURCE_GROUP:-}"

APP_PREFIX="${APP_PREFIX:-skuska}"
LOCATION="${LOCATION:-norwayeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-${APP_PREFIX}-rg}"
CONTAINER_ENV_RESOURCE_GROUP="${CONTAINER_ENV_RESOURCE_GROUP:-$RESOURCE_GROUP}"
ALLOWED_LOCATIONS="${ALLOWED_LOCATIONS:-norwayeast}"

ENV_FILE=".skuska.env"

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI is required. Install it and run: az login"
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to build and push container images."
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required to generate DB_PASSWORD."
  exit 1
fi

az account show >/dev/null

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

if [ -n "$REQUESTED_LOCATION" ]; then
  LOCATION="$REQUESTED_LOCATION"
fi

if [ -n "$REQUESTED_RESOURCE_GROUP" ]; then
  RESOURCE_GROUP="$REQUESTED_RESOURCE_GROUP"
fi

CONTAINER_ENV_RESOURCE_GROUP="${CONTAINER_ENV_RESOURCE_GROUP:-$RESOURCE_GROUP}"
SUFFIX="${SUFFIX:-$(date +%s | tail -c 7)}"
ACR_NAME="${ACR_NAME:-${APP_PREFIX}acr${SUFFIX}}"
CONTAINER_ENV="${CONTAINER_ENV:-${APP_PREFIX}-env}"
APP_NAME="${APP_NAME:-${APP_PREFIX}-app}"
STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-${APP_PREFIX}st${SUFFIX}}"
STORAGE_ACCOUNT="$(echo "$STORAGE_ACCOUNT" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9' | cut -c1-24)"
STORAGE_SHARE="${STORAGE_SHARE:-pgbackup}"
STORAGE_MOUNT_NAME="${STORAGE_MOUNT_NAME:-postgres-backup-storage}"
DB_NAME="${DB_NAME:-appdb}"
DB_USER="${DB_USER:-appuser}"
DB_PASSWORD="${DB_PASSWORD:-$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 24)}"

cat > "$ENV_FILE" <<EOF
APP_PREFIX=$APP_PREFIX
LOCATION=$LOCATION
ALLOWED_LOCATIONS="$ALLOWED_LOCATIONS"
RESOURCE_GROUP=$RESOURCE_GROUP
CONTAINER_ENV_RESOURCE_GROUP=$CONTAINER_ENV_RESOURCE_GROUP
SUFFIX=$SUFFIX
ACR_NAME=$ACR_NAME
CONTAINER_ENV=$CONTAINER_ENV
APP_NAME=$APP_NAME
STORAGE_ACCOUNT=$STORAGE_ACCOUNT
STORAGE_SHARE=$STORAGE_SHARE
STORAGE_MOUNT_NAME=$STORAGE_MOUNT_NAME
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
EOF

wait_for_provider() {
  local namespace="$1"
  local state=""

  echo "Registering Azure provider: $namespace"
  az provider register --namespace "$namespace" >/dev/null

  for _ in $(seq 1 60); do
    state="$(az provider show --namespace "$namespace" --query registrationState -o tsv 2>/dev/null || true)"
    echo "  $namespace state: ${state:-unknown}"

    if [ "$state" = "Registered" ]; then
      return 0
    fi

    sleep 10
  done

  echo "Provider $namespace was not registered after 10 minutes."
  exit 1
}

wait_for_acr() {
  local state=""

  echo "Waiting for Azure Container Registry: $ACR_NAME"

  for _ in $(seq 1 60); do
    state="$(az acr show \
      --resource-group "$RESOURCE_GROUP" \
      --name "$ACR_NAME" \
      --query provisioningState \
      -o tsv 2>/dev/null || true)"

    echo "  $ACR_NAME state: ${state:-not found yet}"

    if [ "$state" = "Succeeded" ]; then
      return 0
    fi

    if [ "$state" = "Failed" ]; then
      echo "Azure Container Registry provisioning failed."
      exit 1
    fi

    sleep 10
  done

  echo "Azure Container Registry was not ready after 10 minutes."
  exit 1
}

get_acr_credentials() {
  for _ in $(seq 1 30); do
    ACR_LOGIN_SERVER="$(az acr show --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --query loginServer -o tsv 2>/dev/null || true)"
    ACR_USERNAME="$(az acr credential show --name "$ACR_NAME" --query username -o tsv 2>/dev/null || true)"
    ACR_PASSWORD="$(az acr credential show --name "$ACR_NAME" --query passwords[0].value -o tsv 2>/dev/null || true)"

    if [ -n "$ACR_LOGIN_SERVER" ] && [ -n "$ACR_USERNAME" ] && [ -n "$ACR_PASSWORD" ]; then
      return 0
    fi

    echo "  ACR credentials are not ready yet..."
    sleep 10
  done

  echo "Could not read Azure Container Registry credentials."
  exit 1
}

yaml_quote() {
  printf "'%s'" "$(printf "%s" "$1" | sed "s/'/''/g")"
}

ensure_container_env() {
  local existing_env=""
  local candidate=""
  local candidates="${CONTAINER_ENV_LOCATIONS:-$ALLOWED_LOCATIONS}"

  if az containerapp env show \
    --resource-group "$CONTAINER_ENV_RESOURCE_GROUP" \
    --name "$CONTAINER_ENV" >/dev/null 2>&1; then
    echo "Using existing Container Apps environment: $CONTAINER_ENV in $CONTAINER_ENV_RESOURCE_GROUP"
    return 0
  fi

  existing_env="$(az containerapp env list \
    --query "[?name=='$CONTAINER_ENV'] | [0].resourceGroup" \
    -o tsv 2>/dev/null || true)"

  if [ -n "$existing_env" ] && [ "$existing_env" != "None" ]; then
    CONTAINER_ENV_RESOURCE_GROUP="$existing_env"
    echo "Found existing Container Apps environment: $CONTAINER_ENV in $CONTAINER_ENV_RESOURCE_GROUP"
    return 0
  fi

  echo "Creating one Container Apps environment: $CONTAINER_ENV"

  for candidate in $candidates; do
    echo "  Trying Container Apps environment region: $candidate"

    if az containerapp env create \
      --resource-group "$CONTAINER_ENV_RESOURCE_GROUP" \
      --name "$CONTAINER_ENV" \
      --location "$candidate" >/dev/null 2>&1; then
      LOCATION="$candidate"
      echo "  Created Container Apps environment in $LOCATION"
      return 0
    fi
  done

  echo
  echo "Could not create Container Apps environment in tested regions."
  echo "Your subscription likely blocks Container Apps environments or reached the regional quota."
  echo "List existing environments with:"
  echo "  az containerapp env list -o table"
  echo
  echo "If Azure Portal shows an existing environment, rerun with:"
  echo "  CONTAINER_ENV=<existing-env-name> CONTAINER_ENV_RESOURCE_GROUP=<existing-env-rg> ./prepare-app.sh"
  echo
  echo "You can also provide your own region list:"
  echo "  CONTAINER_ENV_LOCATIONS=\"region1 region2 region3\" ./prepare-app.sh"
  exit 1
}

echo "Installing/updating Azure Container Apps extension..."
az extension add --name containerapp --upgrade >/dev/null

wait_for_provider "Microsoft.App"
wait_for_provider "Microsoft.OperationalInsights"
wait_for_provider "Microsoft.ContainerRegistry"
wait_for_provider "Microsoft.Storage"

EXISTING_RESOURCE_GROUP_LOCATION="$(az group show --name "$RESOURCE_GROUP" --query location -o tsv 2>/dev/null || true)"

if [ -n "$EXISTING_RESOURCE_GROUP_LOCATION" ]; then
  LOCATION="$EXISTING_RESOURCE_GROUP_LOCATION"
  echo "Using existing resource group $RESOURCE_GROUP in $LOCATION..."
else
  echo "Creating resource group in $LOCATION..."
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" >/dev/null
fi

if [ "$CONTAINER_ENV_RESOURCE_GROUP" != "$RESOURCE_GROUP" ]; then
  az group show --name "$CONTAINER_ENV_RESOURCE_GROUP" >/dev/null
fi

echo "Creating Azure Container Registry..."
if ! az acr show --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" >/dev/null 2>&1; then
  az acr create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$ACR_NAME" \
    --sku Basic \
    --admin-enabled true >/dev/null
fi

wait_for_acr
az acr update --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --admin-enabled true >/dev/null
get_acr_credentials

echo "Logging in to Azure Container Registry..."
az acr login --name "$ACR_NAME" >/dev/null

echo "Building and pushing backend image..."
docker build -t "$ACR_LOGIN_SERVER/${APP_PREFIX}-backend:latest" ./backend
docker push "$ACR_LOGIN_SERVER/${APP_PREFIX}-backend:latest"

echo "Building and pushing frontend image..."
docker build --build-arg API_BASE_URL=/api -t "$ACR_LOGIN_SERVER/${APP_PREFIX}-frontend:latest" ./frontend
docker push "$ACR_LOGIN_SERVER/${APP_PREFIX}-frontend:latest"

echo "Building and pushing postgres image..."
docker build -t "$ACR_LOGIN_SERVER/${APP_PREFIX}-postgres:latest" ./postgres
docker push "$ACR_LOGIN_SERVER/${APP_PREFIX}-postgres:latest"

ensure_container_env

CONTAINER_ENV_ID="$(az containerapp env show \
  --resource-group "$CONTAINER_ENV_RESOURCE_GROUP" \
  --name "$CONTAINER_ENV" \
  --query id -o tsv)"

echo "Creating Azure Storage Account for persistent PostgreSQL backups..."
if ! az storage account show --resource-group "$RESOURCE_GROUP" --name "$STORAGE_ACCOUNT" >/dev/null 2>&1; then
  az storage account create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$STORAGE_ACCOUNT" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 >/dev/null
fi

STORAGE_KEY="$(az storage account keys list \
  --resource-group "$RESOURCE_GROUP" \
  --account-name "$STORAGE_ACCOUNT" \
  --query "[0].value" \
  -o tsv)"

echo "Creating Azure Files share for persistent PostgreSQL backups..."
az storage share create \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" \
  --name "$STORAGE_SHARE" \
  --quota 5 >/dev/null

echo "Connecting Azure Files share to Container Apps environment..."
az containerapp env storage set \
  --resource-group "$CONTAINER_ENV_RESOURCE_GROUP" \
  --name "$CONTAINER_ENV" \
  --storage-name "$STORAGE_MOUNT_NAME" \
  --storage-type AzureFile \
  --azure-file-account-name "$STORAGE_ACCOUNT" \
  --azure-file-account-key "$STORAGE_KEY" \
  --azure-file-share-name "$STORAGE_SHARE" \
  --access-mode ReadWrite >/dev/null

APP_YAML=".skuska-containerapp.yaml"
REGISTRY_PASSWORD_YAML="$(yaml_quote "$ACR_PASSWORD")"
DB_PASSWORD_YAML="$(yaml_quote "$DB_PASSWORD")"

cat > "$APP_YAML" <<EOF
properties:
  managedEnvironmentId: $CONTAINER_ENV_ID
  configuration:
    activeRevisionsMode: Single
    secrets:
      - name: registry-password
        value: $REGISTRY_PASSWORD_YAML
      - name: db-password
        value: $DB_PASSWORD_YAML
    registries:
      - server: $ACR_LOGIN_SERVER
        username: $ACR_USERNAME
        passwordSecretRef: registry-password
    ingress:
      external: true
      targetPort: 80
      transport: auto
      allowInsecure: false
  template:
    containers:
      - name: frontend
        image: $ACR_LOGIN_SERVER/${APP_PREFIX}-frontend:latest
        resources:
          cpu: 0.25
          memory: 0.5Gi
      - name: backend
        image: $ACR_LOGIN_SERVER/${APP_PREFIX}-backend:latest
        env:
          - name: DB_HOST
            value: 127.0.0.1
          - name: DB_PORT
            value: "5432"
          - name: DB_USER
            value: $DB_USER
          - name: DB_PASSWORD
            secretRef: db-password
          - name: DB_NAME
            value: $DB_NAME
          - name: DB_SSL
            value: "false"
        resources:
          cpu: 0.5
          memory: 1Gi
      - name: postgres
        image: $ACR_LOGIN_SERVER/${APP_PREFIX}-postgres:latest
        env:
          - name: POSTGRES_USER
            value: $DB_USER
          - name: POSTGRES_PASSWORD
            secretRef: db-password
          - name: POSTGRES_DB
            value: $DB_NAME
          - name: PGDATA
            value: /tmp/postgres-data
          - name: BACKUP_DIR
            value: /backup
          - name: BACKUP_INTERVAL_SECONDS
            value: "60"
        resources:
          cpu: 0.5
          memory: 1Gi
        volumeMounts:
          - volumeName: postgres-backup
            mountPath: /backup
    scale:
      minReplicas: 1
      maxReplicas: 1
    volumes:
      - name: postgres-backup
        storageType: AzureFile
        storageName: $STORAGE_MOUNT_NAME
EOF

echo "Deploying one Container App with three containers: frontend, backend, postgres..."
az containerapp delete --resource-group "$RESOURCE_GROUP" --name "$APP_NAME" --yes >/dev/null 2>&1 || true
az containerapp create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$APP_NAME" \
  --environment "$CONTAINER_ENV_ID" \
  --yaml "$APP_YAML" >/dev/null

APP_FQDN="$(az containerapp show --resource-group "$RESOURCE_GROUP" --name "$APP_NAME" --query properties.configuration.ingress.fqdn -o tsv)"

rm -f "$APP_YAML"

grep -v -E '^(LOCATION|ACR_LOGIN_SERVER|APP_URL|CONTAINER_ENV_RESOURCE_GROUP)=' "$ENV_FILE" > "${ENV_FILE}.tmp"
mv "${ENV_FILE}.tmp" "$ENV_FILE"

cat >> "$ENV_FILE" <<EOF
LOCATION=$LOCATION
CONTAINER_ENV_RESOURCE_GROUP=$CONTAINER_ENV_RESOURCE_GROUP
ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER
APP_URL=https://$APP_FQDN
EOF

echo
echo "Application is ready:"
echo "URL: https://$APP_FQDN"
echo "Container App: $APP_NAME"
echo "Containers: frontend, backend, postgres"
echo "Environment: $CONTAINER_ENV in $CONTAINER_ENV_RESOURCE_GROUP"
echo "Persistent backup volume: Azure Files share $STORAGE_SHARE mounted to postgres at /backup"
echo
echo "Local deployment values were saved to $ENV_FILE. Do not commit this file."
