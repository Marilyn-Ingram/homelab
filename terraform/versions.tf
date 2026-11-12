terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # Remote state lives in an Azure Storage account so your laptop and
  # GitHub Actions share one copy. Values come from backend.hcl (local)
  # or -backend-config flags (GitHub Actions). See README, Part 1.
  backend "azurerm" {}
}
