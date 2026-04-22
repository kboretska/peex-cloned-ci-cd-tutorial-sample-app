resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg"
  location = var.location

  tags = {
    Environment = var.environment
    Project     = var.prefix
  }
}
