# FitTrack AI — Teardown Guide

## Warning

This project creates real Azure resources. Keeping them running may incur cost.

Do not run teardown commands unless you intentionally want to remove the backend/cloud demo
environment.

## Main cost-generating resources

- Azure PostgreSQL Flexible Server
- Azure Container Apps
- Log Analytics workspace
- Azure Container Registry
- Azure Key Vault operations
- Azure OpenAI usage

## Before teardown

Confirm that:

- You no longer need the cloud demo.
- You have captured screenshots or demo evidence if needed.
- Your documentation is committed.
- No secrets are committed.
- You understand that destroying resources may remove the working cloud environment.

## Preview destroy

From:

```bash
cd infra/terraform/azure/environments/dev
```

Run:

```bash
terraform plan -destroy \
  -var-file="terraform.azure-openai.example.tfvars" \
  -var-file="terraform.azure-openai.local.tfvars"
```

Review the plan carefully.

## Destroy

Only if you intentionally want to remove the demo:

```bash
terraform destroy \
  -var-file="terraform.azure-openai.example.tfvars" \
  -var-file="terraform.azure-openai.local.tfvars"
```

Do not use `-auto-approve` unless you fully understand the impact.

## Verify

Check the Resource Group:

```bash
az group show --name rg-fittrack-ai-dev
```

If the Resource Group was destroyed, this should fail or return not found.

## Do not commit

Never commit:

```text
terraform.azure-openai.local.tfvars
terraform.tfvars
.env
*.tfstate
.terraform/
```

## Notes

This teardown guide is for cost control and cleanup. It should not be executed as part of
Block 4.24.
