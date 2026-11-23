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

# The identity Terraform runs as, read when it plans. The vault authenticates
# requests against the tenant of that identity.
data "azurerm_client_config" "current" {}

# One Azure Key Vault, and nothing else: no secret, key, certificate, access
# policy, role assignment, network, private endpoint or resource group, each
# of which belongs to the operator.
#
# The vault authorizes reads and writes of its contents with Azure
# role-based access control, so it ignores access policies, and Azure
# Resource Manager may read its secrets while it deploys a template, so a
# Key Vault reference in a template resolves. Neither virtual machines nor
# Azure Disk Encryption read the vault on a grant of its own. The provider
# turns soft delete on for every vault it creates. No network rule set is
# written: the provider sends none when it creates the vault, and with public
# network access on, the public endpoint takes requests from every network.
resource "azurerm_key_vault" "this" {
  name                            = var.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  sku_name                        = var.sku_name
  rbac_authorization_enabled      = true
  enabled_for_template_deployment = true
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = false
  soft_delete_retention_days      = var.soft_delete_retention_days
  purge_protection_enabled        = var.purge_protection_enabled
  public_network_access_enabled   = var.public_network_access_enabled
  tags                            = var.tags
}

# The vault's DNS name, the host of the URI the service reports.
output "host" {
  value = split("/", azurerm_key_vault.this.vault_uri)[2]
}

# The vault's URI, as the service reports it.
output "endpoint" {
  value = azurerm_key_vault.this.vault_uri
}
