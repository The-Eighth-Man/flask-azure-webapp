terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {}
}

# Variables
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "flask-app-rg"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "mexicocentral"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "flask-webapp"
}

variable "db_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

# Random suffix for unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.resource_group_name}-${random_string.suffix.result}"
  location = var.location

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.app_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = var.environment
  }
}

# Subnet for App Service
resource "azurerm_subnet" "app_service" {
  name                 = "app-service-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "app-service-delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Subnet for Private Endpoints (no delegation for SQL)
resource "azurerm_subnet" "private_endpoints" {
  name                 = "private-endpoints-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Private DNS Zone for Azure SQL
resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

# Link Private DNS Zone to VNET
resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = "sql-vnet-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

# Azure SQL Server
resource "azurerm_mssql_server" "main" {
  name                         = "${var.app_name}-sql-${random_string.suffix.result}"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = "adminuser"
  administrator_login_password = var.db_admin_password

  public_network_access_enabled = false

  tags = {
    Environment = var.environment
  }
}

# Azure SQL Database
resource "azurerm_mssql_database" "main" {
  name                        = "appdb"
  server_id                   = azurerm_mssql_server.main.id
  sku_name                    = "Basic"
  storage_account_type        = "Local"
  zone_redundant              = false

  tags = {
    Environment = var.environment
  }
}

# Private Endpoint for SQL Server
resource "azurerm_private_endpoint" "sql" {
  name                = "${var.app_name}-sql-endpoint-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "sql-private-connection"
    private_connection_resource_id = azurerm_mssql_server.main.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }

  private_dns_zone_group {
    name                 = "sql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }

  tags = {
    Environment = var.environment
  }
}

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = "${var.app_name}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "B1"

  tags = {
    Environment = var.environment
  }
}

# App Service
resource "azurerm_linux_web_app" "main" {
  name                = "${var.app_name}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    always_on = true

    application_stack {
      python_version = "3.11"
    }

    vnet_route_all_enabled = true
  }

  app_settings = {
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    "DB_HOST"     = azurerm_mssql_server.main.fully_qualified_domain_name
    "DB_NAME"     = azurerm_mssql_database.main.name
    "DB_USER"     = "${azurerm_mssql_server.main.administrator_login}@${azurerm_mssql_server.main.name}"
    "DB_PASSWORD" = var.db_admin_password
    "DB_PORT"     = "1433"
    "DB_TYPE"     = "mssql"
  }

  virtual_network_subnet_id = azurerm_subnet.app_service.id

  tags = {
    Environment = var.environment
  }

  depends_on = [
    azurerm_mssql_server.main,
    azurerm_mssql_database.main,
    azurerm_private_endpoint.sql
  ]
}

# Outputs
output "app_service_name" {
  value       = azurerm_linux_web_app.main.name
  description = "Name of the App Service"
}

output "app_service_url" {
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
  description = "URL of the App Service"
}

output "sql_server_name" {
  value       = azurerm_mssql_server.main.name
  description = "Name of the SQL Server"
}

output "sql_server_fqdn" {
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
  description = "FQDN of the SQL Server"
  sensitive   = true
}

output "private_endpoint_ip" {
  value       = azurerm_private_endpoint.sql.private_service_connection[0].private_ip_address
  description = "Private IP address of the SQL Server endpoint"
  sensitive   = true
}

output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Name of the resource group"
}

output "vnet_name" {
  value       = azurerm_virtual_network.main.name
  description = "Name of the virtual network"
}
