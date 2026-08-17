terraform {
  backend "azurerm" {
    resource_group_name  = "RG-TerraformState"
    storage_account_name = "tfstatentfslab07"
    container_name       = "tfstate"
    key                  = "08-rbac.terraform.tfstate"
    # Lab 07 uses a different key in this same container.
    # Same storage account, different key = no collision, no shared blast radius.
  }
}
