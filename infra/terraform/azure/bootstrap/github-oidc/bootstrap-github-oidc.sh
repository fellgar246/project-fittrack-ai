#!/usr/bin/env bash
# One-time admin bootstrap for Block 6.3 — remote Terraform state + GitHub OIDC UAMIs.
# Run with an interactive az login that can create identities and assign RBAC.
# Idempotent: safe to re-run; skips resources that already exist.
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-fittrack-ai-dev}"
LOCATION="${LOCATION:-eastus}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-79639552-00e8-43f6-b721-92290a8d36e9}"

STATE_STORAGE_ACCOUNT="${STATE_STORAGE_ACCOUNT:-stfittrackaidevtf01}"
STATE_CONTAINER="${STATE_CONTAINER:-tfstate}"
STATE_KEY="${STATE_KEY:-fittrack-ai-dev.tfstate}"

PLAN_IDENTITY_NAME="${PLAN_IDENTITY_NAME:-id-fittrack-github-plan}"
DEPLOY_IDENTITY_NAME="${DEPLOY_IDENTITY_NAME:-id-fittrack-github-deploy}"

ACR_NAME="${ACR_NAME:-acrfittrackaidevdev01}"
KEY_VAULT_NAME="${KEY_VAULT_NAME:-kvfittrackaidevdev01}"

GITHUB_REPO="${GITHUB_REPO:-fellgar246/project-fittrack-ai}"
GITHUB_ENVIRONMENT="${GITHUB_ENVIRONMENT:-development}"

RG_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"
ACR_SCOPE="${RG_SCOPE}/providers/Microsoft.ContainerRegistry/registries/${ACR_NAME}"
KV_SCOPE="${RG_SCOPE}/providers/Microsoft.KeyVault/vaults/${KEY_VAULT_NAME}"

log() { printf '==> %s\n' "$*"; }

ensure_subscription() {
  local current
  current="$(az account show --query id -o tsv)"
  if [[ "${current}" != "${SUBSCRIPTION_ID}" ]]; then
    log "Setting subscription to ${SUBSCRIPTION_ID}"
    az account set --subscription "${SUBSCRIPTION_ID}"
  fi
}

ensure_storage_account() {
  if az storage account show --name "${STATE_STORAGE_ACCOUNT}" --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
    log "Storage account ${STATE_STORAGE_ACCOUNT} already exists"
  else
    log "Creating storage account ${STATE_STORAGE_ACCOUNT}"
    az storage account create \
      --name "${STATE_STORAGE_ACCOUNT}" \
      --resource-group "${RESOURCE_GROUP}" \
      --location "${LOCATION}" \
      --sku Standard_LRS \
      --kind StorageV2 \
      --allow-blob-public-access false \
      --min-tls-version TLS1_2 \
      --allow-shared-key-access false
  fi

  if az storage container show \
    --name "${STATE_CONTAINER}" \
    --account-name "${STATE_STORAGE_ACCOUNT}" \
    --auth-mode login >/dev/null 2>&1; then
    log "Container ${STATE_CONTAINER} already exists"
  else
    log "Creating blob container ${STATE_CONTAINER}"
    az storage container create \
      --name "${STATE_CONTAINER}" \
      --account-name "${STATE_STORAGE_ACCOUNT}" \
      --auth-mode login \
      --public-access off
  fi
}

ensure_identity() {
  local name="$1"
  if az identity show --resource-group "${RESOURCE_GROUP}" --name "${name}" >/dev/null 2>&1; then
    log "Managed identity ${name} already exists"
  else
    log "Creating managed identity ${name}"
    az identity create \
      --resource-group "${RESOURCE_GROUP}" \
      --name "${name}" \
      --location "${LOCATION}" \
      --tags managed_by=bootstrap block=6.3 purpose=github-oidc
  fi
}

ensure_federated_credential() {
  local identity_name="$1"
  local cred_name="$2"
  local subject="$3"
  local issuer="https://token.actions.githubusercontent.com"
  local audience="api://AzureADTokenExchange"

  if az identity federated-credential show \
    --identity-name "${identity_name}" \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${cred_name}" >/dev/null 2>&1; then
    log "Federated credential ${cred_name} on ${identity_name} already exists"
  else
    log "Creating federated credential ${cred_name} on ${identity_name} (subject=${subject})"
    az identity federated-credential create \
      --name "${cred_name}" \
      --identity-name "${identity_name}" \
      --resource-group "${RESOURCE_GROUP}" \
      --issuer "${issuer}" \
      --subject "${subject}" \
      --audiences "${audience}"
  fi
}

ensure_role() {
  local assignee="$1"
  local role="$2"
  local scope="$3"
  local existing
  existing="$(az role assignment list \
    --assignee "${assignee}" \
    --role "${role}" \
    --scope "${scope}" \
    --query "[0].id" -o tsv 2>/dev/null || true)"
  if [[ -n "${existing}" && "${existing}" != "null" ]]; then
    log "Role ${role} already assigned to ${assignee} at scope"
  else
    log "Assigning ${role} to ${assignee}"
    az role assignment create \
      --assignee "${assignee}" \
      --role "${role}" \
      --scope "${scope}" \
      --only-show-errors
  fi
}

main() {
  ensure_subscription
  ensure_storage_account
  ensure_identity "${PLAN_IDENTITY_NAME}"
  ensure_identity "${DEPLOY_IDENTITY_NAME}"

  ensure_federated_credential "${PLAN_IDENTITY_NAME}" "github-main" \
    "repo:${GITHUB_REPO}:ref:refs/heads/main"
  ensure_federated_credential "${PLAN_IDENTITY_NAME}" "github-pull-request" \
    "repo:${GITHUB_REPO}:pull_request"
  ensure_federated_credential "${DEPLOY_IDENTITY_NAME}" "github-environment-development" \
    "repo:${GITHUB_REPO}:environment:${GITHUB_ENVIRONMENT}"

  local plan_client_id deploy_client_id state_container_id
  plan_client_id="$(az identity show -g "${RESOURCE_GROUP}" -n "${PLAN_IDENTITY_NAME}" --query clientId -o tsv)"
  deploy_client_id="$(az identity show -g "${RESOURCE_GROUP}" -n "${DEPLOY_IDENTITY_NAME}" --query clientId -o tsv)"
  state_container_id="$(az storage container show \
    --account-name "${STATE_STORAGE_ACCOUNT}" \
    --name "${STATE_CONTAINER}" \
    --auth-mode login \
    --query id -o tsv 2>/dev/null || true)"
  if [[ -z "${state_container_id}" ]]; then
    state_container_id="${RG_SCOPE}/providers/Microsoft.Storage/storageAccounts/${STATE_STORAGE_ACCOUNT}/blobServices/default/containers/${STATE_CONTAINER}"
  fi

  ensure_role "${plan_client_id}" "Reader" "${RG_SCOPE}"
  ensure_role "${plan_client_id}" "Storage Blob Data Contributor" "${state_container_id}"
  ensure_role "${deploy_client_id}" "Contributor" "${RG_SCOPE}"
  ensure_role "${deploy_client_id}" "AcrPush" "${ACR_SCOPE}"
  ensure_role "${deploy_client_id}" "Storage Blob Data Contributor" "${state_container_id}"
  ensure_role "${deploy_client_id}" "Key Vault Secrets User" "${KV_SCOPE}"

  local tenant_id
  tenant_id="$(az account show --query tenantId -o tsv)"

  cat <<EOF

Bootstrap complete. Configure GitHub with these non-secret values:

Repository variables:
  TERRAFORM_CLOUD_PLAN_ENABLED=true
  AZURE_TENANT_ID=${tenant_id}
  AZURE_SUBSCRIPTION_ID=${SUBSCRIPTION_ID}
  AZURE_PLAN_CLIENT_ID=${plan_client_id}
  TF_BACKEND_RESOURCE_GROUP_NAME=${RESOURCE_GROUP}
  TF_BACKEND_STORAGE_ACCOUNT_NAME=${STATE_STORAGE_ACCOUNT}
  TF_BACKEND_CONTAINER_NAME=${STATE_CONTAINER}
  TF_BACKEND_STATE_KEY=${STATE_KEY}
  TF_VAR_api_ai_provider=azure
  TF_VAR_api_image_tag=block-5.8-amd64-fix
  AZURE_RESOURCE_GROUP=${RESOURCE_GROUP}
  AZURE_ACR_NAME=${ACR_NAME}
  AZURE_CONTAINER_APP_NAME=ca-fittrack-ai-api-dev
  API_BASE_URL=https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io

Environment "development" variable:
  AZURE_DEPLOY_CLIENT_ID=${deploy_client_id}

Next: migrate local Terraform state (see README.md).

EOF
}

main "$@"
