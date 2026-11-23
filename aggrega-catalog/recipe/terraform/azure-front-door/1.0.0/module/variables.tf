# Every variable is named for the resource argument it sets. waf_policy_id and
# tags have defaults; the caller supplies every other one on every call.

variable "name" {
  type        = string
  description = "Name of the profile, and of its endpoint, origin group, origin, route and security policy."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group the profile is created in."
}

variable "sku_name" {
  type        = string
  description = "Tier of the profile: Standard_AzureFrontDoor or Premium_AzureFrontDoor."
}

variable "origin_host_name" {
  type        = string
  description = "Host name of the origin every request is forwarded to, also sent as the Host header."
}

variable "waf_policy_id" {
  type        = string
  default     = null
  description = "Resource ID of the web application firewall policy associated with the endpoint, or null for none."
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Tags of the profile and the endpoint."
}
