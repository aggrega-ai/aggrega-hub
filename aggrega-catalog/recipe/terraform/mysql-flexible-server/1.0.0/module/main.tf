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

# One Azure Database for MySQL flexible server with private access: it takes an
# address in the caller's delegated subnet, its name resolves through the
# caller's private DNS zone, and public access is off. The module declares the
# server, its one database and the server parameters the caller names, and
# nothing else: no network, subnet, DNS zone, firewall rule or resource group,
# each of which belongs to the operator.
#
# The server is created with the storage size the caller gives, and storage
# auto-grow is on: the service grows the storage as it fills, which keeps a full
# server from turning read-only, and the service keeps auto-grow on for every
# server with high availability. Storage the service has grown cannot be shrunk,
# so the size the service reports afterwards is not read back as a change to
# undo, and a later change to storage_size_gb is not applied to a server that
# exists.
#
# A server with zone-redundant high availability swaps its primary and standby
# zones when it fails over, so the zones the service reports afterwards are not
# read back as changes to undo either.
resource "azurerm_mysql_flexible_server" "this" {
  name                   = var.name
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = var.mysql_version
  sku_name               = var.sku_name
  zone                   = var.zone
  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password
  delegated_subnet_id    = var.delegated_subnet_id
  private_dns_zone_id    = var.private_dns_zone_id
  public_network_access  = "Disabled"
  backup_retention_days  = var.backup_retention_days
  tags                   = var.tags

  storage {
    size_gb           = var.storage_size_gb
    auto_grow_enabled = true
  }

  dynamic "high_availability" {
    for_each = var.high_availability_mode == null ? [] : [var.high_availability_mode]
    content {
      mode = high_availability.value
    }
  }

  lifecycle {
    ignore_changes = [zone, high_availability[0].standby_availability_zone, storage[0].size_gb]
  }
}

# The database the caller names, with its default character set and collation.
resource "azurerm_mysql_flexible_database" "this" {
  name                = var.database_name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.this.name
  charset             = var.charset
  collation           = var.collation
}

# One server parameter for each entry of server_configuration, set to the
# entry's config.
resource "azurerm_mysql_flexible_server_configuration" "this" {
  for_each = var.server_configuration

  name                = each.value.name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.this.name
  value               = each.value.config
}

# The server's name under mysql.database.azure.com, which resolves to its
# private address through the caller's private DNS zone.
output "fqdn" {
  value = azurerm_mysql_flexible_server.this.fqdn
}
