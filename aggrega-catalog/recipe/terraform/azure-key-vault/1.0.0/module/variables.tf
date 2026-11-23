# Every variable is named for the resource argument it sets.
# soft_delete_retention_days, purge_protection_enabled,
# public_network_access_enabled and tags have defaults; the caller supplies
# every other one on every call.

variable "name" {
  type        = string
  description = "Name of the vault, and the first label of its host name."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group the vault is created in."
}

variable "location" {
  type        = string
  description = "Region the vault is created in, such as westeurope."
}

variable "sku_name" {
  type        = string
  description = "Tier of the vault: standard or premium."
}

variable "soft_delete_retention_days" {
  type        = number
  default     = 90
  description = "Days a deleted vault, secret, key or certificate stays recoverable, from 7 to 90."
}

variable "purge_protection_enabled" {
  type        = bool
  default     = true
  description = "Whether a deleted vault or object is kept from purging until its retention period ends."
}

variable "public_network_access_enabled" {
  type        = bool
  default     = true
  description = "Whether the vault takes requests over its public endpoint."
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Tags of the vault."
}
