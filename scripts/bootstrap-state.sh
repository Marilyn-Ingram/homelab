#!/usr/bin/env bash
# Creates the Azure Storage account that holds Terraform's state file.
# Run ONCE, after `az login`, from the repo's top folder:
#   bash scripts/bootstrap-state.sh
set -euo pipefail

LOCATION="${LOCATION:-eastus}"
RG="rg-homelab-tfstate"
# Storage account names must be globally unique, 3-24 lowercase letters/numbers.
SA="tfstate$(printf '%04x%04x' "$RANDOM" "$RANDOM")"
CONTAINER="tfstate"

echo "Creating resource group $RG in $LOCATION..."
az group create --name "$RG" --location "$LOCATION" --output none

echo "Creating storage account $SA (this takes about a minute)..."
az storage account create \
  --name "$SA" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --output none

echo "Creating container $CONTAINER..."
ACCOUNT_KEY=$(az storage account keys list --resource-group "$RG" --account-name "$SA" --query '[0].value' -o tsv)
az storage container create \
  --name "$CONTAINER" \
  --account-name "$SA" \
  --account-key "$ACCOUNT_KEY" \
  --output none

cat > terraform/backend.hcl <<EOF
resource_group_name  = "$RG"
storage_account_name = "$SA"
container_name       = "$CONTAINER"
key                  = "homelab.tfstate"
EOF

echo
echo "Done. Wrote terraform/backend.hcl (it's in .gitignore)."
echo "Save these for your GitHub secrets:"
echo "  TFSTATE_RG = $RG"
echo "  TFSTATE_SA = $SA"
