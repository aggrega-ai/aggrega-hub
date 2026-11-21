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

# The user-assigned identity the image is pulled with, read so that its client
# ID can be given to App Service, which names a pulling identity by its client
# ID rather than by its resource ID. The identity's resource group and name are
# the fifth and ninth segments of the resource ID the caller passes; the
# provider reads the identity in the subscription Terraform runs against. It is
# read, not created.
data "azurerm_user_assigned_identity" "registry" {
  count = var.registry_identity == null ? 0 : 1

  resource_group_name = split("/", var.registry_identity)[4]
  name                = split("/", var.registry_identity)[8]
}

# One App Service app running the caller's image as a Linux custom container on
# the caller's App Service plan. The module declares the app and nothing else:
# no plan, network, subnet, identity, registry, Key Vault, private endpoint or
# resource group, each of which belongs to the operator.
#
# Who reaches the app. Public network access is off, so the app's default host
# name answers no request from the internet; a private endpoint the operator
# creates for the app is the way in. Plain HTTP is redirected to HTTPS, which
# App Service terminates at its front ends, and the request reaches the
# container on the port WEBSITES_PORT names. Session affinity is off: the app
# is stateless, so any instance of the plan may serve any request. The FTP and
# Web Deploy publishing endpoints refuse basic authentication and FTP is
# disabled, since the app runs an image and nothing is published to it.
#
# Always On is on, so App Service keeps the app loaded while no request
# arrives, sending a request to its root every five minutes.
#
# Outbound. With virtual_network_subnet_id set, the app joins that subnet by
# regional virtual network integration and routes all its outbound traffic
# through it, so a server with private access in the operator's network, and
# the private DNS zone its name resolves through, are reached from the app.
#
# The registry. The image is pulled from registry_url, either with the
# user-assigned identity registry_identity names or with registry_username
# and the password App Service reads from the Key Vault secret
# registry_password_secret_id names, through a Key Vault reference App Service
# resolves with the identity registry_password_identity names. The reference
# is the value the provider writes to the DOCKER_REGISTRY_SERVER_PASSWORD app
# setting; the password itself never passes through Terraform.
resource "azurerm_linux_web_app" "this" {
  name                                           = var.name
  resource_group_name                            = var.resource_group_name
  location                                       = var.location
  service_plan_id                                = var.service_plan_id
  virtual_network_subnet_id                      = var.virtual_network_subnet_id
  https_only                                     = true
  public_network_access_enabled                  = false
  client_affinity_enabled                        = false
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  key_vault_reference_identity_id                = var.registry_password_identity
  app_settings                                   = merge(var.environment, { WEBSITES_PORT = tostring(var.port) })

  dynamic "identity" {
    for_each = length(var.identity_ids) == 0 ? [] : [var.identity_ids]
    content {
      type         = "UserAssigned"
      identity_ids = identity.value
    }
  }

  site_config {
    always_on                                     = true
    ftps_state                                    = "Disabled"
    vnet_route_all_enabled                        = var.virtual_network_subnet_id != null
    container_registry_use_managed_identity       = var.registry_identity != null
    container_registry_managed_identity_client_id = var.registry_identity == null ? null : data.azurerm_user_assigned_identity.registry[0].client_id

    application_stack {
      docker_image_name        = var.image_name
      docker_registry_url      = var.registry_url
      docker_registry_username = var.registry_username
      docker_registry_password = var.registry_password_secret_id == null ? null : "@Microsoft.KeyVault(SecretUri=${var.registry_password_secret_id})"
    }
  }
}
