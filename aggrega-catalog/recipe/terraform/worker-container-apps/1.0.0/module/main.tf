# required_providers pins hashicorp/azurerm so the engine installs a provider whose
# resource schema this module was written against. It is a range rather than an
# exact version because every Azure module in one root configuration shares one
# installed provider, and two exact pins that differ fail init. 4.18 is the first
# release whose container app takes a volume mount's sub_path, which the files
# below are mounted by. The range spans azurerm 4 and 5, since every argument
# below is one both majors take: in azurerm 4 the module sits in one root
# configuration beside the PostgreSQL flexible server module the catalog sources,
# and in azurerm 5 beside the catalog's Azure Managed Redis, Azure OpenAI and API
# Management bodies.
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.18, < 6"
    }
  }
}

locals {
  # The user-assigned identities the app is given: those named for its own code,
  # and the ones the registry pull and the registry password's Key Vault read are
  # made with, which Container Apps takes only from the app's own identities.
  identity_ids = distinct(compact(concat(
    var.identity_ids,
    [var.registry_identity, var.registry_password_identity],
  )))

  # One secret per file, named file-0, file-1 and so on in the order Terraform
  # iterates a map's keys in, which is the paths' lexical order.
  files = { for i, path in keys(var.files) : path => "file-${i}" }
}

# One container app running the worker's container, in a Container Apps
# environment and a resource group that already exist. The module declares the app
# and nothing else: no environment, network, identity, registry, Key Vault or log
# workspace, each of which belongs to the operator who names it.
#
# The app declares no ingress, so nothing reaches it: it has no address in its
# environment and the container receives no request. It runs a fixed number of
# replicas, its minimum and its maximum being the same count, on the environment's
# Consumption workload profile, in single-revision mode; with no ingress and no
# scale rule, a minimum of one or more is what keeps it running.
resource "azurerm_container_app" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  revision_mode                = "Single"

  dynamic "identity" {
    for_each = length(local.identity_ids) > 0 ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = local.identity_ids
    }
  }

  # The registry password is read from Key Vault by reference, with the identity
  # named for it; its value is never written into the configuration.
  dynamic "secret" {
    for_each = var.registry_password_secret_id == null ? [] : [1]
    content {
      name                = "registry-password"
      key_vault_secret_id = var.registry_password_secret_id
      identity            = var.registry_password_identity
    }
  }

  dynamic "secret" {
    for_each = local.files
    content {
      name  = secret.value
      value = var.files[secret.key]
    }
  }

  dynamic "registry" {
    for_each = var.registry_server == null ? [] : [1]
    content {
      server               = var.registry_server
      identity             = var.registry_identity
      username             = var.registry_username
      password_secret_name = var.registry_username == null ? null : "registry-password"
    }
  }

  template {
    min_replicas = var.replicas
    max_replicas = var.replicas

    # One container, main. Its environment is one entry per key of
    # var.environment, in the key order Terraform iterates a map in, and each
    # file is mounted alone at its path from the secret volume below. No probe is
    # declared: a worker serves no request a probe could send.
    container {
      name   = "main"
      image  = var.image
      cpu    = var.cpu
      memory = var.memory

      dynamic "env" {
        for_each = var.environment
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "volume_mounts" {
        for_each = local.files
        content {
          name     = "inject-files"
          path     = volume_mounts.key
          sub_path = volume_mounts.value
        }
      }
    }

    dynamic "volume" {
      for_each = length(local.files) > 0 ? [1] : []
      content {
        name         = "inject-files"
        storage_type = "Secret"
      }
    }
  }
}
