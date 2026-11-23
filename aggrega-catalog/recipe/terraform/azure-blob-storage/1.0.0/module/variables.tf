# Every variable is named for the resource argument it sets, save containers,
# the names of the account's containers. containers and tags have defaults;
# the caller supplies every other one on every call.

variable "name" {
  type        = string
  description = "Name of the account, and the first label of its host names."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group the account is created in."
}

variable "location" {
  type        = string
  description = "Region the account is created in, such as westeurope."
}

variable "account_tier" {
  type        = string
  description = "Performance tier of the account: Standard."
}

variable "account_replication_type" {
  type        = string
  description = "Redundancy of the account: LRS, ZRS, GRS, GZRS, RAGRS or RAGZRS."
}

variable "access_tier" {
  type        = string
  description = "Default access tier of a new blob: Hot, Cool or Cold."
}

variable "public_network_access" {
  type        = string
  description = "Public network access to the account: Enabled, Disabled or SecuredByPerimeter."
}

variable "is_hns_enabled" {
  type        = bool
  description = "Whether the account has the hierarchical namespace of Data Lake Storage."
}

variable "containers" {
  type        = set(string)
  default     = []
  description = "Names of the account's containers, each created private."
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Tags of the account."
}
