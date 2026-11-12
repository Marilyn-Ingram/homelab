#!/usr/bin/env bash
# Lets GitHub Actions sign in to Azure WITHOUT storing a password (OIDC).
# Creates an app registration, gives it Contributor on your subscription,
# and trusts tokens from your GitHub repo.
#
# Usage, after `az login`, from the repo's top folder:
#   bash scripts/setup-github-oidc.sh YOUR_GITHUB_USERNAME/homelab
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: bash scripts/setup-github-oidc.sh <github-user>/<repo>"
  exit 1
fi

REPO="$1"
APP_NAME="github-${REPO//\//-}"
SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "Creating app registration $APP_NAME..."
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
az ad sp create --id "$APP_ID" --output none

echo "Giving it Contributor on subscription $SUB_ID..."
# New service principals can take a few seconds to appear, so retry.
for attempt in 1 2 3 4 5 6; do
  if az role assignment create \
       --assignee "$APP_ID" \
       --role Contributor \
       --scope "/subscriptions/$SUB_ID" \
       --output none; then
    break
  fi
  echo "Not ready yet (attempt $attempt), waiting 10 seconds..."
  sleep 10
done

add_credential () {
  local name="$1" subject="$2"
  echo "Trusting GitHub tokens for: $subject"
  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"$name\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"$subject\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" --output none
}

# Pull requests (terraform plan) and the "lab" environment (deploy + destroy).
add_credential "pull-requests"   "repo:${REPO}:pull_request"
add_credential "lab-environment" "repo:${REPO}:environment:lab"

echo
echo "Done. Add these as GitHub repository secrets:"
echo "  AZURE_CLIENT_ID       = $APP_ID"
echo "  AZURE_TENANT_ID       = $TENANT_ID"
echo "  AZURE_SUBSCRIPTION_ID = $SUB_ID"
