# Example file to preview Block 5.8 blob storage wiring.
#
# Usage (plan only):
#   terraform plan \
#     -var-file="terraform.azure-openai.example.tfvars" \
#     -var-file="terraform.blob-storage.example.tfvars"
#
# Do not put real secrets in this file.

create_blob_storage = true

blob_storage_account_tier          = "Standard"
blob_storage_replication_type      = "LRS"
blob_public_network_access_enabled = true

progress_photo_max_bytes          = 5242880
progress_photo_upload_ttl_seconds = 300
progress_photo_read_ttl_seconds   = 300
