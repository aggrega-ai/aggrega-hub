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

# One standard general-purpose v2 storage account, and nothing else but its
# containers: no network, private endpoint, network rule, identity, role
# assignment, file share, queue, table or resource group, each of which
# belongs to the operator.
#
# Shared Key authorization is off, so the account takes requests authorized
# with Microsoft Entra ID alone; no container takes an anonymous request; and
# TLS 1.2 over HTTPS is the oldest a client may connect with. With no
# network_rules block the provider creates the account with the service's
# default network rule set, allowing every network, and leaves the rule set
# alone afterwards. A deleted blob and a deleted container are kept seven
# days.
resource "azurerm_storage_account" "this" {
  name                             = var.name
  resource_group_name              = var.resource_group_name
  location                         = var.location
  account_kind                     = "StorageV2"
  account_tier                     = var.account_tier
  account_replication_type         = var.account_replication_type
  access_tier                      = var.access_tier
  is_hns_enabled                   = var.is_hns_enabled
  shared_access_key_enabled        = false
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  local_user_enabled               = false
  min_tls_version                  = "TLS1_2"
  https_traffic_only_enabled       = true
  public_network_access            = var.public_network_access
  tags                             = var.tags

  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }
}

# One private container for each name the caller passes.
resource "azurerm_storage_container" "this" {
  for_each = var.containers

  name                  = each.key
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

# The DNS name of the account's blob service, as the provider reports it.
output "host" {
  value      = azurerm_storage_account.this.primary_blob_host
  depends_on = [azurerm_storage_container.this]
}

# The URL of the account's blob service, as the service reports it.
output "endpoint" {
  value      = azurerm_storage_account.this.primary_blob_endpoint
  depends_on = [azurerm_storage_container.this]
}

# The URL of the account's Data Lake Storage endpoint, as the service reports
# it.
output "dfs_endpoint" {
  value      = azurerm_storage_account.this.primary_dfs_endpoint
  depends_on = [azurerm_storage_container.this]
}
