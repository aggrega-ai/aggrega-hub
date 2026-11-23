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

# One Azure Front Door profile, at the location global, which the provider
# writes, with 60 seconds for an origin to answer a forwarded request. Its
# endpoint, origin group, origin, route and security policy are named after
# it. No custom domain, rule set, secret, firewall policy, DNS record or
# resource group is declared: each belongs to the operator.
resource "azurerm_cdn_frontdoor_profile" "this" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  sku_name                 = var.sku_name
  response_timeout_seconds = 60
  tags                     = var.tags
}

# The endpoint, enabled. The service gives it a host name of its own, its name
# followed by a hash Front Door generates, shared by endpoints of its name
# across the Microsoft Entra tenant, the service's default.
resource "azurerm_cdn_frontdoor_endpoint" "this" {
  name                     = var.name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  enabled                  = true
  tags                     = var.tags
}

# The origin group, balancing over its one origin with 4 samples, 3 of them
# successful, and 50 milliseconds of added latency, with session affinity off.
# No health_probe block is written, so no health probe is sent, which
# Microsoft documents as open to an origin group holding a single origin.
resource "azurerm_cdn_frontdoor_origin_group" "this" {
  name                     = var.name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  session_affinity_enabled = false

  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 3
    additional_latency_in_milliseconds = 50
  }
}

# The origin: the host the upstream publishes, sent as the Host header too,
# reached over HTTPS on port 443, its certificate's name checked.
resource "azurerm_cdn_frontdoor_origin" "this" {
  name                           = var.name
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.this.id
  enabled                        = true
  host_name                      = var.origin_host_name
  origin_host_header             = var.origin_host_name
  http_port                      = 80
  https_port                     = 443
  certificate_name_check_enabled = true
  priority                       = 1
  weight                         = 1000
}

# The route, enabled, linking the endpoint's own domain to the origin group for
# every path. It takes HTTP and HTTPS, redirects HTTP to HTTPS and forwards
# over HTTPS alone. No cache block is written, which leaves caching off.
resource "azurerm_cdn_frontdoor_route" "this" {
  name                          = var.name
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.this.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.this.id]
  enabled                       = true
  supported_protocols           = ["Http", "Https"]
  patterns_to_match             = ["/*"]
  forwarding_protocol           = "HttpsOnly"
  https_redirect_enabled        = true
  link_to_default_domain        = true
}

# The security policy, while a firewall policy is named: it associates the
# operator's policy with the endpoint's own domain for every path. The policy
# is referenced, never created or changed.
resource "azurerm_cdn_frontdoor_security_policy" "this" {
  count = var.waf_policy_id == null ? 0 : 1

  name                     = var.name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = var.waf_policy_id

      association {
        patterns_to_match = ["/*"]

        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.this.id
        }
      }
    }
  }
}

# The endpoint's host name, as the service reports it.
output "host" {
  value = azurerm_cdn_frontdoor_endpoint.this.host_name
}

# The address a client sends its requests to.
output "endpoint" {
  value = "https://${azurerm_cdn_frontdoor_endpoint.this.host_name}"
}
