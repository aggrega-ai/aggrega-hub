# Every variable is named for the resource argument it sets, except port, which
# sets the WEBSITES_PORT app setting; environment, which holds the app settings
# the container reads as its variables; image_name and registry_url, which set
# docker_image_name and docker_registry_url in the application stack;
# registry_identity, the resource ID of the identity whose client ID sets
# container_registry_managed_identity_client_id; registry_password_secret_id,
# the Key Vault secret the registry password is read from; and
# registry_password_identity, which sets key_vault_reference_identity_id.
# virtual_network_subnet_id, identity_ids and the registry variables have
# defaults; the caller supplies every other one on every call.

variable "name" {
  type        = string
  description = "Name of the app, unique across Azure, and the first label of its default host name."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group the app is created in."
}

variable "location" {
  type        = string
  description = "Region the app is created in, the region of its App Service plan, such as westeurope."
}

variable "service_plan_id" {
  type        = string
  description = "Resource ID of the Linux App Service plan the app runs on."
}

variable "virtual_network_subnet_id" {
  type        = string
  default     = null
  description = "Resource ID of the subnet the app joins by regional virtual network integration, or null for none."
}

variable "port" {
  type        = number
  description = "Port the container listens on, which App Service sends requests to."
}

variable "image_name" {
  type        = string
  description = "Image the app runs, with its tag or digest, without the registry's host name."
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
  default     = []
  description = "Resource IDs of the existing user-assigned managed identities given to the app."
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
