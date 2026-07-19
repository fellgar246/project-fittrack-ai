# GitHub OIDC + Remote State Bootstrap (Block 6.3)

One-time admin bootstrap for FitTrack AI CI/CD. Run with interactive `az login` — **never** store admin credentials in GitHub.

## What this creates

| Resource | Name | Purpose |
|----------|------|---------|
| Storage account | `stfittrackaidevtf01` | Terraform remote state (separate from app blob storage) |
| Blob container | `tfstate` | State blob container |
| Plan UAMI | `id-fittrack-github-plan` | Read-only Terraform plan in CI |
| Deploy UAMI | `id-fittrack-github-deploy` | Protected deployment writes |

## Federated credential subjects

Issuer: `https://token.actions.githubusercontent.com`  
Audience: `api://AzureADTokenExchange`

| Identity | Subject |
|----------|---------|
| Plan | `repo:fellgar246/project-fittrack-ai:ref:refs/heads/main` |
| Plan | `repo:fellgar246/project-fittrack-ai:pull_request` |
| Deploy | `repo:fellgar246/project-fittrack-ai:environment:development` |

## RBAC

| Role | Plan UAMI | Deploy UAMI |
|------|-----------|-------------|
| Reader | `rg-fittrack-ai-dev` | — |
| Storage Blob Data Contributor | `tfstate` container | `tfstate` container |
| Contributor | — | `rg-fittrack-ai-dev` |
| AcrPush | — | `acrfittrackaidevdev01` |
| Key Vault Secrets User | — | `kvfittrackaidevdev01` |

**Not granted:** User Access Administrator, Owner, subscription-wide Contributor.

## Run bootstrap

```bash
cd infra/terraform/azure/bootstrap/github-oidc
./bootstrap-github-oidc.sh
```

The script is idempotent. It prints GitHub variable values (non-secret) at the end.

## Migrate local state to remote

After adding the `backend "azurerm"` block to `environments/dev/versions.tf`:

```bash
cd infra/terraform/azure/environments/dev
export ARM_SUBSCRIPTION_ID="79639552-00e8-43f6-b721-92290a8d36e9"

terraform init \
  -backend-config="resource_group_name=rg-fittrack-ai-dev" \
  -backend-config="storage_account_name=stfittrackaidevtf01" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=fittrack-ai-dev.tfstate"
```

Confirm state migration when prompted. Verify with a plan using real local tfvars (not example-only OpenAI values):

```bash
terraform plan \
  -var-file="terraform.azure-openai.example.tfvars" \
  -var-file="terraform.azure-openai.local.tfvars" \
  -var-file="terraform.blob-storage.example.tfvars"
```

Expect **No changes** when inputs match cloud.

## Verify bootstrap

```bash
az identity list -g rg-fittrack-ai-dev --query "[?contains(name,'github')].{name:name, clientId:clientId}" -o table
az storage container list --account-name stfittrackaidevtf01 --auth-mode login -o table
```

## Rotation / teardown

- Delete federated credentials before deleting UAMIs.
- Remove role assignments, then identities, then state storage (only after backing up state).
- Bootstrap identities are **not** managed by main dev Terraform (avoids circular dependency).

## Client IDs (post-bootstrap)

| Identity | Client ID |
|----------|-----------|
| Plan | `e2799123-394b-4953-a921-376acb3df106` |
| Deploy | `388aa74b-6490-4c25-9b32-b14afc464470` |

Store these as GitHub **variables** (`AZURE_PLAN_CLIENT_ID`, environment `AZURE_DEPLOY_CLIENT_ID`), not secrets.
