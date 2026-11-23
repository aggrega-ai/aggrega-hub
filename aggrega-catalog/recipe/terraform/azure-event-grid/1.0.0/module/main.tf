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

# One Azure Event Grid custom topic, and nothing else: no event subscription,
# network, private endpoint, identity, IP rule or resource group, each of
# which belongs to the operator or to a subscriber.
#
# Access key and shared access signature authentication is off, so the topic
# takes requests authenticated with Microsoft Entra ID alone, and TLS 1.2 is
# the oldest version a publisher may connect with. The provider writes no IP
# rule unless one is given, so with public network access on, the public
# endpoint takes events from every network.
resource "azurerm_eventgrid_topic" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  input_schema                  = var.input_schema
  local_auth_enabled            = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags
}

# The topic's DNS name, the host of the endpoint the service reports.
output "host" {
  value = split("/", azurerm_eventgrid_topic.this.endpoint)[2]
}

# The URL a publisher sends events to, as the service reports it.
output "endpoint" {
  value = azurerm_eventgrid_topic.this.endpoint
}
