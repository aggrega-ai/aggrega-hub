# required_providers pins hashicorp/azurerm so the engine installs a provider
# whose resource schema this module was written against. It is a range rather
# than an exact version because every Azure module in one root configuration
# shares one installed provider, and two exact pins that differ fail init. The
# constraint string is the one the Aggrega catalog conventions' "One Azure
# provider constraint for every Azure body" section states; this file repeats
# it deliberately, because a vendored module is copied byte for byte and imports
# nothing.
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.14"
    }
  }
}

# One Azure SQL Managed Instance in the caller's delegated subnet: it takes its
# address in that subnet, and its public endpoint is off, so it takes
# connections only on its endpoint inside the virtual network. The module
# declares the instance and its one database, and nothing else: no network,
# subnet, route table, network security group, identity, DNS zone or resource
# group, each of which belongs to the operator.
#
# The connection type is Redirect, the service's default: a client opens its
# connection on port 1433 and then reaches the node hosting the database
# directly, so it must be allowed to reach port 1433 across the whole subnet's
# address range. TLS 1.2 is the oldest version a client may connect with. Backups are kept on geo-redundant storage,
# the service's default, or on geo-zone-redundant storage while the instance
# is zone redundant, since the service makes an instance zone redundant only
# while its backups are kept on zone-redundant or geo-zone-redundant storage,
# and geo-zone-redundant storage keeps the copy in the paired region that
# geo-redundant storage gives.
resource "azurerm_mssql_managed_instance" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  sku_name                     = var.sku_name
  vcores                       = var.vcores
  license_type                 = var.license_type
  storage_size_in_gb           = var.storage_size_in_gb
  subnet_id                    = var.subnet_id
  administrator_login          = var.administrator_login
  administrator_login_password = var.administrator_login_password
  collation                    = var.collation
  database_format              = var.database_format
  zone_redundant_enabled       = var.zone_redundant_enabled
  storage_account_type         = var.zone_redundant_enabled ? "GZRS" : "GRS"
  proxy_override               = "Redirect"
  public_data_endpoint_enabled = false
  minimum_tls_version          = "1.2"
  tags                         = var.tags
}

# The database the caller names. It takes the instance's collation, which
# SQL Server gives a database created without one of its own, and keeps its
# automated backups for point-in-time restore short_term_retention_days days.
resource "azurerm_mssql_managed_database" "this" {
  name                      = var.database_name
  managed_instance_id       = azurerm_mssql_managed_instance.this.id
  short_term_retention_days = var.short_term_retention_days
}

# The instance's name under database.windows.net, which resolves to its
# address inside the virtual network.
output "fqdn" {
  value = azurerm_mssql_managed_instance.this.fqdn
}
