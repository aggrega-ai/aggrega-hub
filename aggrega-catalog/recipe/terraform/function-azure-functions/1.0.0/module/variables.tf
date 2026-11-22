# Every variable is named for the resource argument it sets, except
# storage_account_id, the resource ID of the storage account whose name sets
# storage_account_name; storage_identity, the resource ID of the identity whose
# client ID sets the AzureWebJobsStorage__clientId app setting; port, which
# sets the WEBSITES_PORT app setting; environment, which holds the app settings
# the container reads as its variables; image_name, image_tag and
# registry_url, which set the docker block of the application stack;
# registry_identity, the resource ID of the identity whose client ID sets
# container_registry_managed_identity_client_id; registry_password_secret_id,
# the Key Vault secret the registry password is read from;
# registry_password_identity, which sets key_vault_reference_identity_id; and
# min_replicas and max_replicas, which set elastic_instance_minimum and
# app_scale_limit on an Elastic Premium plan. virtual_network_subnet_id,
# environment and the registry variables have defaults; the caller supplies
# every other one on every call.

variable "name" {
  type        = string
  description = "Name of the function app, unique across Azure, and the first label of its default host name."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group the function app is created in."
}

variable "location" {
  type        = string
  description = "Region the function app is created in, the region of its plan, such as westeurope."
}

variable "service_plan_id" {
  type        = string
  description = "Resource ID of the Linux Elastic Premium or Dedicated plan the function app runs on."
}

variable "virtual_network_subnet_id" {
  type        = string
  default     = null
  description = "Resource ID of the subnet the function app joins by regional virtual network integration, or null for none."
}

variable "storage_account_id" {
  type        = string
  description = "Resource ID of the storage account the Functions host keeps its state in."
}

variable "storage_identity" {
  type        = string
  description = "Resource ID of the user-assigned identity, one of identity_ids, the Functions host reaches its storage account with."
}

variable "port" {
  type        = number
  description = "Port the container listens on, which App Service sends requests to."
}

variable "image_name" {
  type        = string
  description = "Image the function app runs, without the registry's host name and without the tag or digest after its last colon."
}

variable "image_tag" {
  type        = string
  description = "Tag of the image, or the digest after the last colon of a digest reference."
}

variable "registry_url" {
  type        = string
  description = "Address of the registry the image is pulled from, https:// followed by its host name."
}

variable "environment" {
  type        = map(string)
  default     = {}
  description = "App settings, each a variable of the container under its name."
}

variable "identity_ids" {
  type        = list(string)
  description = "Resource IDs of the existing user-assigned managed identities given to the function app."
}

variable "min_replicas" {
  type        = number
  description = "Always ready instance count of the function app on an Elastic Premium plan."
}

variable "max_replicas" {
  type        = number
  description = "Instance count the function app scales out to at most on an Elastic Premium plan."
}

variable "registry_identity" {
  type        = string
  default     = null
  description = "Resource ID of the user-assigned identity the image is pulled with, one of identity_ids, or null."
}

variable "registry_username" {
  type        = string
  default     = null
  description = "User name the image is pulled with, or null."
}

variable "registry_password_secret_id" {
  type        = string
  default     = null
  description = "ID of the Key Vault secret holding the registry password, or null."
}

variable "registry_password_identity" {
  type        = string
  default     = null
  description = "Resource ID of the user-assigned identity App Service reads Key Vault references with, one of identity_ids, or null."
}
