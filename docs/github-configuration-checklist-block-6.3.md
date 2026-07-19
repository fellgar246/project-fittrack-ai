# GitHub Configuration Checklist — Block 6.3

Complete after running [`bootstrap-github-oidc.sh`](../infra/terraform/azure/bootstrap/github-oidc/bootstrap-github-oidc.sh).

## Environment: `development`

- [ ] Create environment named `development`
- [ ] Restrict deployment branch to `main`
- [ ] Add required reviewer(s) if available on your GitHub plan
- [ ] Set variable `AZURE_DEPLOY_CLIENT_ID` = `388aa74b-6490-4c25-9b32-b14afc464470`
- [ ] Copy deploy-time secrets (OpenAI `TF_VAR_*`) if environment isolation is required

## Repository variables

- [ ] `TERRAFORM_CLOUD_PLAN_ENABLED` = `true`
- [ ] `AZURE_TENANT_ID` = `c3a907a5-9880-40af-b083-9be8604bddc1`
- [ ] `AZURE_SUBSCRIPTION_ID` = `79639552-00e8-43f6-b721-92290a8d36e9`
- [ ] `AZURE_PLAN_CLIENT_ID` = `e2799123-394b-4953-a921-376acb3df106`
- [ ] `TF_BACKEND_RESOURCE_GROUP_NAME` = `rg-fittrack-ai-dev`
- [ ] `TF_BACKEND_STORAGE_ACCOUNT_NAME` = `stfittrackaidevtf01`
- [ ] `TF_BACKEND_CONTAINER_NAME` = `tfstate`
- [ ] `TF_BACKEND_STATE_KEY` = `fittrack-ai-dev.tfstate`
- [ ] `TF_VAR_owner` = `felipe`
- [ ] `TF_VAR_unique_suffix` = `dev01`
- [ ] `TF_VAR_api_ai_provider` = `azure`
- [ ] `TF_VAR_api_image_tag` = `block-5.8-amd64-fix`
- [ ] `TF_VAR_api_azure_openai_api_version` = *(from Key Vault / local tfvars)*
- [ ] `AZURE_RESOURCE_GROUP` = `rg-fittrack-ai-dev`
- [ ] `AZURE_ACR_NAME` = `acrfittrackaidevdev01`
- [ ] `AZURE_CONTAINER_APP_NAME` = `ca-fittrack-ai-api-dev`
- [ ] `API_BASE_URL` = `https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io`

## Repository secrets

- [ ] `TF_VAR_api_azure_openai_endpoint`
- [ ] `TF_VAR_api_azure_openai_api_key`
- [ ] `TF_VAR_api_azure_openai_deployment`

## Validation sequence

- [ ] Push changes; **Terraform quality** passes
- [ ] **Terraform plan safety** passes with OIDC (after variables/secrets configured)
- [ ] Manual **Backend Deploy** on `main` completes (health HTTP 200)
- [ ] Post-deploy cloud plan shows no drift (update `TF_VAR_api_image_tag` to new SHA if needed)

## Branch protection (recommended)

- [ ] Require **Backend quality** for backend changes
- [ ] Require **Terraform quality** for infra changes
- [ ] Optionally require **Terraform plan safety** after Block 6.3 validation
