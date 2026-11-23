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

# One record set in the operator's Azure DNS zone, and nothing else: the zone
# and its resource group belong to the operator, and each record resource names
# them as its parent. The provider keeps each record type as a resource of its
# own, so each is declared here once and created only for the type var.type
# names: exactly one of them exists.

resource "azurerm_dns_a_record" "this" {
  count               = var.type == "A" ? 1 : 0
  name                = var.name
  zone_name           = var.zone_name
  resource_group_name = var.resource_group_name
  ttl                 = var.ttl
  records             = var.records
  tags                = var.tags
}

resource "azurerm_dns_aaaa_record" "this" {
  count               = var.type == "AAAA" ? 1 : 0
  name                = var.name
  zone_name           = var.zone_name
  resource_group_name = var.resource_group_name
  ttl                 = var.ttl
  records             = var.records
  tags                = var.tags
}

# A CNAME record set holds one record.
resource "azurerm_dns_cname_record" "this" {
  count               = var.type == "CNAME" ? 1 : 0
  name                = var.name
  zone_name           = var.zone_name
  resource_group_name = var.resource_group_name
  ttl                 = var.ttl
  record              = var.records[0]
  tags                = var.tags
}

resource "azurerm_dns_ns_record" "this" {
  count               = var.type == "NS" ? 1 : 0
  name                = var.name
  zone_name           = var.zone_name
  resource_group_name = var.resource_group_name
  ttl                 = var.ttl
  records             = var.records
  tags                = var.tags
}

resource "azurerm_dns_ptr_record" "this" {
  count               = var.type == "PTR" ? 1 : 0
  name                = var.name
  zone_name           = var.zone_name
  resource_group_name = var.resource_group_name
  ttl                 = var.ttl
  records             = var.records
  tags                = var.tags
}

# The provider takes an MX record's preference as a string.
resource "azurerm_dns_mx_record" "this" {
  count               = var.type == "MX" ? 1 : 0
  name                = var.name
  zone_name           = var.zone_name
  resource_group_name = var.resource_group_name
  ttl                 = var.ttl
  tags                = var.tags

  dynamic "record" {
    for_each = var.mx_records
    content {
      preference = tostring(record.value.preference)
      exchange   = record.value.exchange
    }
  }
}

resource "azurerm_dns_srv_record" "this" {
  count               = var.type == "SRV" ? 1 : 0
  name                = var.name
  zone_name           = var.zone_name
  resource_group_name = var.resource_group_name
  ttl                 = var.ttl
  tags                = var.tags

  dynamic "record" {
    for_each = var.srv_records
    content {
      priority = record.value.priority
      weight   = record.value.weight
      port     = record.value.port
      target   = record.value.target
    }
  }
}

resource "azurerm_dns_caa_record" "this" {
  count               = var.type == "CAA" ? 1 : 0
  name                = var.name
  zone_name           = var.zone_name
  resource_group_name = var.resource_group_name
  ttl                 = var.ttl
  tags                = var.tags

  dynamic "record" {
    for_each = var.caa_records
    content {
      flags = record.value.flags
      tag   = record.value.tag
      value = record.value.value
    }
  }
}

# Each text becomes one TXT record, which the provider divides into strings of
# 254 bytes when it is longer.
resource "azurerm_dns_txt_record" "this" {
  count               = var.type == "TXT" ? 1 : 0
  name                = var.name
  zone_name           = var.zone_name
  resource_group_name = var.resource_group_name
  ttl                 = var.ttl
  tags                = var.tags

  dynamic "record" {
    for_each = var.records
    content {
      value = record.value
    }
  }
}

# The record set's fully qualified name, as the service reports it, without
# its trailing dot.
output "host" {
  value = trimsuffix(one(concat(
    azurerm_dns_a_record.this[*].fqdn,
    azurerm_dns_aaaa_record.this[*].fqdn,
    azurerm_dns_cname_record.this[*].fqdn,
    azurerm_dns_ns_record.this[*].fqdn,
    azurerm_dns_ptr_record.this[*].fqdn,
    azurerm_dns_mx_record.this[*].fqdn,
    azurerm_dns_srv_record.this[*].fqdn,
    azurerm_dns_caa_record.this[*].fqdn,
    azurerm_dns_txt_record.this[*].fqdn,
  )), ".")
}
