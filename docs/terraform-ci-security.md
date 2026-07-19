# FitTrack AI — Terraform CI and Security Checks (Block 6.2)

**Block:** 6.2  
**Scope:** Terraform static validation, IaC security scanning, file/secret hygiene, and plan-safety tooling. **No `terraform apply`**, no Azure deployment, no cloud-backed plan until Block 6.3.

---

## 1. Objective

Automated infrastructure quality gates detect, on pull requests and pushes to `main`:

- Formatting errors
- Invalid Terraform configuration
- Provider initialization failures (static)
- Common infrastructure security issues (Trivy)
- Leaked secrets or committed local Terraform files (Gitleaks + hygiene)
- Destroys and replacements in plan JSON (script + unit tests; cloud plan in Block 6.3)

This block clearly separates:

| Layer | Block 6.2 | Block 6.3+ |
|-------|-----------|------------|
| Configuration validation | Yes | Yes |
| Static security validation | Yes | Yes |
| Cloud-backed Terraform plan | Scaffolded, skipped | Enabled with OIDC |
| Deployment (`apply`) | No | Protected apply |

---

## 2. Workflow

Single workflow: [`.github/workflows/terraform-ci.yml`](../.github/workflows/terraform-ci.yml)

| Job | Check name | Runs when |
|-----|------------|-----------|
| `terraform-quality` | **Terraform quality** | Always (PR, push, manual, forks) |
| `terraform-plan` | **Terraform plan safety** | Only when Block 6.3 gates are enabled |
| `terraform-plan-skipped` | **Terraform plan safety** | When plan job is not enabled (mutually exclusive) |

Related Block 6.1 workflows are unchanged:

- [Backend CI](../.github/workflows/backend-ci.yml) → **Backend quality**
- [Flutter CI](../.github/workflows/flutter-ci.yml) → **Flutter quality**

---

## 3. Triggers

```yaml
pull_request:
  paths: [infra/terraform/**, .github/workflows/terraform-ci.yml]
push:
  branches: [main]
  paths: [infra/terraform/**, .github/workflows/terraform-ci.yml]
workflow_dispatch:
```

Changes to `backend/**` or `mobile/**` alone do **not** trigger Terraform CI.

---

## 4. Path filters and branch protection

When configuring branch protection on `main`:

- Require **Terraform quality** for infrastructure PRs.
- **Terraform plan safety** is optional until Block 6.3 enables cloud plan.
- PRs that touch only backend/mobile may pass without Terraform checks — path filters are intentional.

---

## 5. Permissions

Workflow default:

```yaml
permissions:
  contents: read
```

The cloud plan job (Block 6.3) adds `id-token: write` only on that job for Azure OIDC. Block 6.2 does not grant `actions: write`, `pull-requests: write`, or `deployments: write`.

---

## 6. Fork behavior

| Check | Fork PR | Internal PR |
|-------|---------|-------------|
| Terraform quality | Runs | Runs |
| Gitleaks / Trivy / hygiene | Runs | Runs |
| Cloud Terraform plan | Skipped (success) | Skipped until Block 6.3 |

Fork PRs never receive Azure credentials. The skipped plan job writes to `$GITHUB_STEP_SUMMARY`:

> Cloud plan skipped because Azure credentials are unavailable for fork pull requests.

This skip is **not** a failure.

---

## 7. Static validation (Job A)

Working directories:

| Step | Directory |
|------|-----------|
| `terraform fmt -check -recursive` | `infra/terraform/azure/` |
| `terraform init -backend=false` | `infra/terraform/azure/environments/dev/` |
| `terraform validate` | `infra/terraform/azure/environments/dev/` |

Environment:

```yaml
TF_IN_AUTOMATION: true
TF_INPUT: false
```

Terraform version in CI: **1.10.5** (matches `required_version = ">= 1.9.0"`).

Fix formatting locally:

```bash
cd infra/terraform/azure
terraform fmt -recursive
```

---

## 8. Init strategy

Static validation uses:

```bash
terraform init -backend=false -input=false
```

This downloads providers from `.terraform.lock.hcl`, validates configuration, and **does not** access remote state or require Azure credentials.

Do not run `terraform init -upgrade` in CI.

---

## 9. Provider lockfile

[`.terraform.lock.hcl`](../infra/terraform/azure/environments/dev/.terraform.lock.hcl) is committed for reproducible installs. Accidental lockfile changes are detected via normal Git review — CI does not regenerate the lockfile.

---

## 10. Security scanner — Trivy

Tool: [Trivy config scan](https://aquasecurity.github.io/trivy/) via `aquasecurity/trivy-action@0.28.0`

| Setting | Value |
|---------|-------|
| Scan target | `infra/terraform/azure` |
| Tfvars context | `terraform.azure-openai.example.tfvars` |
| Blocking severity | CRITICAL, HIGH |
| Ignore file | [`.trivyignore`](../.trivyignore) |

Local parity:

```bash
docker run --rm -v "$(pwd):/repo" -w /repo aquasec/trivy:0.58.1 config \
  --severity CRITICAL,HIGH \
  --ignorefile .trivyignore \
  --tf-vars infra/terraform/azure/environments/dev/terraform.azure-openai.example.tfvars \
  infra/terraform/azure
```

---

## 11. Severity policy

| Severity | CI behavior |
|----------|-------------|
| CRITICAL | Blocking |
| HIGH | Blocking |
| MEDIUM | Warning / documented baseline (`.trivyignore` or future remediation) |
| LOW | Informational |

---

## 12. Baseline exceptions (Block 6.2)

| Rule ID | Finding | Disposition |
|---------|---------|-------------|
| AVD-AZU-0013 | Key Vault network ACL not specified | Accepted dev portfolio risk — documented in `.trivyignore` |
| AVD-AZU-0016 | Key Vault purge protection disabled | MEDIUM — documented, not blocking in 6.2 |

Other dev risks (PostgreSQL public access, storage public access, external Container App ingress) are documented for future remediation; they may not appear in static scans without full module evaluation.

---

## 13. File hygiene

The workflow fails if Git tracks:

- `*.tfstate`, `*.tfstate.*`
- `*.tfplan`
- bare `*.tfvars` (excluding `*.example.tfvars` and `terraform.tfvars.example`)
- `.terraform/` directories

Allowed: all committed `*.example.tfvars` files under `environments/dev/`.

---

## 14. Secret scanning — Gitleaks

Tool: `gitleaks/gitleaks-action@v2` with [`.gitleaks.toml`](../.gitleaks.toml)

- Scans full Git history on checkout (`fetch-depth: 0`)
- Does not print detected secret values
- Allowlists documented false positives (README curl examples, test fixtures, example tfvars placeholders)

Local parity:

```bash
docker run --rm -v "$(pwd):/repo" -w /repo zricethezav/gitleaks:v8.21.2 \
  detect --source=/repo --config=/repo/.gitleaks.toml
```

**Never commit** `terraform.azure-openai.local.tfvars` or other local tfvars.

---

## 15. Plan strategy (Block 6.2)

Cloud-backed `terraform plan` is **intentionally disabled** in Block 6.2 because:

1. Terraform state is **local only** — not available in CI runners.
2. **No Azure OIDC** federated credentials are configured yet.
3. **Example tfvars alone are unsafe** — `api_ai_provider = "fake"` in `terraform.azure-openai.example.tfvars` previously produced **3 destroys** of Azure OpenAI Key Vault secrets when real state uses `azure`.

Safe local plan (requires gitignored local tfvars):

```bash
cd infra/terraform/azure/environments/dev
terraform plan \
  -var-file="terraform.azure-openai.example.tfvars" \
  -var-file="terraform.azure-openai.local.tfvars" \
  -var-file="terraform.blob-storage.example.tfvars"
```

---

## 16. Azure authentication (Block 6.3 — implemented)

The plan job uses:

- Azure OIDC (`azure/login@v2`) with `id-fittrack-github-plan`
- `ARM_USE_OIDC=true`, `ARM_USE_AZUREAD=true`
- `AZURE_PLAN_CLIENT_ID` repository variable (not a client secret)
- Subscription guard after login

Repository variable gate: `TERRAFORM_CLOUD_PLAN_ENABLED=true`.

Full runbook: [docs/azure-oidc-protected-deployment.md](azure-oidc-protected-deployment.md)

---

## 17. Remote state (Block 6.3 — implemented)

| Variable | Value |
|----------|-------|
| `TF_BACKEND_RESOURCE_GROUP_NAME` | `rg-fittrack-ai-dev` |
| `TF_BACKEND_STORAGE_ACCOUNT_NAME` | `stfittrackaidevtf01` |
| `TF_BACKEND_CONTAINER_NAME` | `tfstate` |
| `TF_BACKEND_STATE_KEY` | `fittrack-ai-dev.tfstate` |

Backend block in `environments/dev/versions.tf` uses `use_azuread_auth = true`.

---

## 18. CI inputs (Block 6.3 activation)

| Input | Secret? | Future CI source |
|-------|---------|------------------|
| `ARM_SUBSCRIPTION_ID` | No | GitHub secret / var |
| `ARM_TENANT_ID` | No | GitHub secret |
| `ARM_CLIENT_ID` | No | `AZURE_PLAN_CLIENT_ID` repository variable |
| `api_ai_provider` | Low | Secret — **must be `azure` for real state** |
| `api_azure_openai_endpoint` | Yes | `TF_VAR_api_azure_openai_endpoint` |
| `api_azure_openai_api_key` | Yes | `TF_VAR_api_azure_openai_api_key` |
| `api_azure_openai_deployment` | Yes | `TF_VAR_api_azure_openai_deployment` |
| `api_azure_openai_api_version` | No | GitHub variable |
| `owner`, `unique_suffix` | No | GitHub variables |

---

## 19. Detailed exit code (Block 6.3 plan job)

| Code | Meaning | CI action |
|------|---------|-----------|
| 0 | No changes | Continue to safety gate |
| 1 | Error | Fail job |
| 2 | Changes present | Continue to safety gate |

---

## 20. Plan JSON analysis

When cloud plan is enabled:

```bash
terraform show -json terraform-ci.tfplan > terraform-plan.json
python3 infra/terraform/scripts/check_plan_safety.py terraform-plan.json
```

The script never prints `before`/`after` values. Plan files are deleted at job end — **not uploaded as artifacts**.

---

## 21. Destroy and replacement detection

Policy:

| Action | Block 6.2 gate |
|--------|----------------|
| Adds | Allowed |
| Updates | Allowed (visible in summary) |
| Destroys | **Fail** |
| Replacements | **Fail** |

Script: [`infra/terraform/scripts/check_plan_safety.py`](../infra/terraform/scripts/check_plan_safety.py)

Unit tests: [`infra/terraform/scripts/tests/`](../infra/terraform/scripts/tests/)

---

## 22. GitHub step summary

The plan safety script writes counts only:

```text
Terraform Plan Safety Summary

Adds: 2
Changes: 1
Destroys: 0
Replacements: 0

Safety gate: Passed
```

When plan is skipped, the summary explains why (fork vs Block 6.3 pending).

---

## 23. Artifacts policy

Do **not** upload:

- `terraform-ci.tfplan`
- `terraform-plan.json`
- tfvars with secrets
- Terraform state

---

## 24. Local parity

```bash
# Format
cd infra/terraform/azure
terraform fmt -check -recursive

# Validate (no Azure)
cd environments/dev
terraform init -backend=false
terraform validate

# Plan safety tests
python3 -m unittest discover -s infra/terraform/scripts/tests -p 'test_*.py' -v

# Trivy (Docker)
docker run --rm -v "$(pwd):/repo" -w /repo aquasec/trivy:0.58.1 config \
  --severity CRITICAL,HIGH --ignorefile .trivyignore \
  --tf-vars infra/terraform/azure/environments/dev/terraform.azure-openai.example.tfvars \
  infra/terraform/azure

# Gitleaks (Docker)
docker run --rm -v "$(pwd):/repo" -w /repo zricethezav/gitleaks:v8.21.2 \
  detect --source=/repo --config=/repo/.gitleaks.toml
```

---

## 25. Troubleshooting

### `terraform fmt` fails in CI

Run `terraform fmt -recursive` from `infra/terraform/azure/` and commit.

### `terraform validate` fails after provider change

Run `terraform init -backend=false` locally; commit updated `.terraform.lock.hcl` if providers changed intentionally.

### Trivy CRITICAL/HIGH finding

Review whether it is a real issue or dev-environment accepted risk. Document in `.trivyignore` with reason — do not disable the scanner globally.

### Gitleaks fails on example placeholders

Add a documented allowlist entry in `.gitleaks.toml` — never allowlist `*.local.tfvars`.

### Plan job always skipped

Expected in Block 6.2. Enable in Block 6.3 with OIDC, remote backend, and `TERRAFORM_CLOUD_PLAN_ENABLED=true`.

### Fork PR shows skipped plan

Expected. Maintainers can run `workflow_dispatch` on an internal branch after Block 6.3.

---

## 26. Known limitations

- Cloud plan omitted in Block 6.2 (no remote state, no OIDC)
- No `terraform apply` or deployment approval
- No cost estimation or Terraform Cloud
- No drift detection schedule
- Trivy static scan does not guarantee full runtime security
- `validate` does not detect cloud drift
- Scanner baselines may require updates when modules are enabled
- GitHub-hosted validation requires commit/push

---

## 27. Required checks (branch protection)

| Check | Recommend required? |
|-------|---------------------|
| **Terraform quality** | Yes — when PR touches `infra/terraform/**` |
| **Terraform plan safety** | Optional until Block 6.3 enables cloud plan |

Configure manually under GitHub → Settings → Branches / Rulesets.

---

## 28. Next block

**Block 6.3 — Azure OIDC + Protected Backend Deployment**

- Federated identity for GitHub Actions
- Remote Terraform state backend
- Enable cloud-backed plan with real inputs
- Protected `terraform apply`, ACR push, migrations, smoke tests
- No long-lived Azure client secrets

---

## Action pinning

| Action | Version |
|--------|---------|
| `actions/checkout` | v4 |
| `hashicorp/setup-terraform` | v3 |
| `aquasecurity/trivy-action` | 0.28.0 |
| `gitleaks/gitleaks-action` | v2 |
| `azure/login` | v2 (Block 6.3 plan job only) |

Major version pinning balances maintainability vs SHA pinning for supply-chain control.

---

## Badge

After the first successful run on `main`:

```markdown
![Terraform CI](https://github.com/fellgar246/project-fittrack-ai/actions/workflows/terraform-ci.yml/badge.svg)
```
