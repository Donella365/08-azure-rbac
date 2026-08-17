terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0" # matches Lab 07's provider version for consistency
    }
  }
}

provider "azurerm" {
  features {}
}
