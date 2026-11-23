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

# One Azure Event Hubs namespace and the event hubs the caller names, and
# nothing else: no network, private endpoint, identity, consumer group,
# authorization rule, Capture or resource group, each of which belongs to the
# operator.
#
# Shared access signature authentication is off, so the namespace takes
# requests authenticated with Microsoft Entra ID alone. TLS 1.2 is the oldest
# version a client may connect with, and auto-inflate is off, so the
# namespace keeps the units it is given. The provider writes no network rule
# set unless one is given, so the service's default stands: with public
# network access on, the public endpoint takes requests from every network.
resource "azurerm_eventhub_namespace" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = var.sku
  capacity                      = var.capacity
  auto_inflate_enabled          = false
  local_authentication_enabled  = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags
}

# Each event hub the caller names, with its partition count, keeping its
# events one day.
resource "azurerm_eventhub" "this" {
  for_each = var.eventhubs

  name              = each.key
  namespace_id      = azurerm_eventhub_namespace.this.id
  partition_count   = each.value.partition_count
  message_retention = 1
}

# The provider reports no address for a namespace, so the address is formed
# from its name and servicebus.windows.net, the domain Azure's public cloud
# gives every Event Hubs namespace. Each output waits for every event hub, so a
# reader of it starts after they exist.
locals {
  host = "${azurerm_eventhub_namespace.this.name}.servicebus.windows.net"
}

# The namespace's DNS name.
output "host" {
  value      = local.host
  depends_on = [azurerm_eventhub.this]
}

# The namespace's URL in the form the service reports it.
output "endpoint" {
  value      = "https://${local.host}:443/"
  depends_on = [azurerm_eventhub.this]
}

# The namespace's Kafka endpoint.
output "bootstrap_servers" {
  value      = "${local.host}:9093"
  depends_on = [azurerm_eventhub.this]
}
