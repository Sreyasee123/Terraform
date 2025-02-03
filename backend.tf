terraform {
  backend "azurerm" {
    resource_group_name  = "Test-rg"
    storage_account_name = "teststorage01sr"
    container_name       = "prod-tfstate"
    key                  = "prod.terraform.tfstate"
  }
}