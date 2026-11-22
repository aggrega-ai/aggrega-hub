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

# The caller's plan, read so that the app is configured for the kind of plan it
# runs on: an Elastic Premium plan, whose SKU names begin with EP, or a
# Dedicated (App Service) plan. The plan's resource group and name are the fifth
# and ninth segments of its resource ID; the provider reads it in the
# subscription Terraform runs against. It is read, not created.
data "azurerm_service_plan" "this" {
  resource_group_name = split("/", var.service_plan_id)[4]
  name                = split("/", var.service_plan_id)[8]
}

# The user-assigned identity the Functions host reaches its storage account
# with, read so that its client ID can be written into the host's storage
# connection, which names a user-assigned identity by its client ID. It is
# read, not created, in the subscription Terraform runs against.
data "azurerm_user_assigned_identity" "storage" {
  resource_group_name = split("/", var.storage_identity)[4]
  name                = split("/", var.storage_identity)[8]
}

# The user-assigned identity the image is pulled with, read so that its client
# ID can be given to App Service, which names a pulling identity by its client
# ID rather than by its resource ID. It is read, not created.
data "azurerm_user_assigned_identity" "registry" {
  count = var.registry_identity == null ? 0 : 1

  resource_group_name = split("/", var.registry_identity)[4]
  name                = split("/", var.registry_identity)[8]
}

locals {
  # An Elastic Premium plan scales the app on its own and holds the app's
  # always ready instances; a Dedicated plan runs the app on each instance it
  # has, and keeps it loaded only with Always On.
  elastic = startswith(upper(data.azurerm_service_plan.this.sku_name), "EP")

  # The two Application Insights settings the provider takes from site_config
  # arguments of its own and reads back into them, so they are passed there
  # rather than among the app settings.
  insights = ["APPLICATIONINSIGHTS_CONNECTION_STRING", "APPINSIGHTS_INSTRUMENTATIONKEY"]
}

# One function app running the caller's image, a whole function app image
# holding the Functions host, on the caller's plan. The module declares the app
# and nothing else: no plan, storage account, network, subnet, identity, role
# assignment, registry, Key Vault, private endpoint or resource group, each of
# which belongs to the operator.
#
# Host storage. The Functions host keeps its state in the storage account
# storage_account_id names and reaches it with the user-assigned identity
# storage_identity names: storage_uses_managed_identity makes the provider
# write the account's name as AzureWebJobsStorage__accountName, and the module
# writes AzureWebJobsStorage__credential and AzureWebJobsStorage__clientId
# beside it, so no access key or connection string is written. With the
# identity in use the provider writes no Azure Files content share setting.
# Built-in logging, a setting of the version 1 runtime only, is off, so the
# provider writes no AzureWebJobsDashboard setting.
#
# Who reaches the app. Public network access is off, so the app's default host
# name answers no request from the internet; a private endpoint the operator
# creates for the app is the way in. Plain HTTP is redirected to HTTPS, which
# App Service terminates at its front ends, and the request reaches the
# container on the port WEBSITES_PORT names. The FTP and Web Deploy publishing
# endpoints refuse basic authentication and FTP is disabled, since the app runs
# an image and nothing is published to it. WEBSITES_ENABLE_APP_SERVICE_STORAGE
# is false, so no shared /home directory is mounted into the container.
#
# The plan. On an Elastic Premium plan the app keeps min_replicas always ready
# instances, scales out to at most max_replicas, keeps one prewarmed instance,
# and leaves Always On off; the provider sends a prewarmed count when it creates
# the app whether or not one is set, so the module sets the one Microsoft
# gives as the default. On a Dedicated plan Always On is on, so the host stays
# loaded while no event arrives, and the plan's own instance count sets how
# many instances the app runs on.
#
# Outbound. With virtual_network_subnet_id set, the app joins that subnet by
# regional virtual network integration and routes all its outbound traffic
# through it.
#
# The registry. The image is pulled from registry_url, either with the
# user-assigned identity registry_identity names or with registry_username
# and the password App Service reads from the Key Vault secret
# registry_password_secret_id names, through a Key Vault reference App Service
# resolves with the identity registry_password_identity names. The reference
# is the value the provider writes to the DOCKER_REGISTRY_SERVER_PASSWORD app
# setting; the password itself never passes through Terraform.
resource "azurerm_linux_function_app" "this" {
  name                                           = var.name
  resource_group_name                            = var.resource_group_name
  location                                       = var.location
  service_plan_id                                = var.service_plan_id
  virtual_network_subnet_id                      = var.virtual_network_subnet_id
  storage_account_name                           = split("/", var.storage_account_id)[8]
  storage_uses_managed_identity                  = true
  builtin_logging_enabled                        = false
  https_only                                     = true
  public_network_access_enabled                  = false
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  key_vault_reference_identity_id                = var.registry_password_identity

  app_settings = merge(
    { for k, v in var.environment : k => v if !contains(local.insights, k) },
    {
      WEBSITES_PORT                       = tostring(var.port)
      WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
      AzureWebJobsStorage__credential     = "managedidentity"
      AzureWebJobsStorage__clientId       = data.azurerm_user_assigned_identity.storage.client_id
    },
  )

  identity {
    type         = "UserAssigned"
    identity_ids = var.identity_ids
  }

  site_config {
    always_on                                     = !local.elastic
    elastic_instance_minimum                      = local.elastic ? var.min_replicas : null
    app_scale_limit                               = local.elastic ? var.max_replicas : null
    pre_warmed_instance_count                     = local.elastic ? 1 : null
    ftps_state                                    = "Disabled"
    vnet_route_all_enabled                        = var.virtual_network_subnet_id != null
    application_insights_connection_string        = lookup(var.environment, "APPLICATIONINSIGHTS_CONNECTION_STRING", null)
    application_insights_key                      = lookup(var.environment, "APPINSIGHTS_INSTRUMENTATIONKEY", null)
    container_registry_use_managed_identity       = var.registry_identity != null
    container_registry_managed_identity_client_id = var.registry_identity == null ? null : data.azurerm_user_assigned_identity.registry[0].client_id

    application_stack {
      docker {
        registry_url      = var.registry_url
        image_name        = var.image_name
        image_tag         = var.image_tag
        registry_username = var.registry_username
        registry_password = var.registry_password_secret_id == null ? null : "@Microsoft.KeyVault(SecretUri=${var.registry_password_secret_id})"
      }
    }
  }
}
