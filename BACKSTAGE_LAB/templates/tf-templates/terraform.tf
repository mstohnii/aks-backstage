provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "${{ values.name }}"
  location = "North Europe"
}
