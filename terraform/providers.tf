# The subscription comes from the ARM_SUBSCRIPTION_ID environment variable.
# Locally: export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
# In GitHub Actions: set from the AZURE_SUBSCRIPTION_ID secret.
provider "azurerm" {
  features {}
}
