# blob_storage

Provisions a private Azure Storage account and blob container for FitTrack AI progress photos.

## Resources

- `azurerm_storage_account` with HTTPS-only access, TLS 1.2, public blob access disabled, and shared key access disabled
- Private blob container created through the ARM plane (`azapi_resource`) so Terraform does not require account keys
- RBAC for the API managed identity:
  - `Storage Blob Delegator` at storage account scope
  - `Storage Blob Data Contributor` at container scope

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | — | Storage account name (3–24 lowercase alphanumeric). |
| `resource_group_name` | `string` | — | Resource group name. |
| `location` | `string` | — | Azure region. |
| `container_name` | `string` | `progress-photos` | Private container name. |
| `api_identity_principal_id` | `string` | `""` | API UAMI principal ID for RBAC. |

## Outputs

| Name | Description |
| --- | --- |
| `id` | Storage account ID |
| `name` | Storage account name |
| `primary_blob_endpoint` | Blob endpoint URL |
| `container_name` | Container name |
| `container_id` | Container resource ID |
