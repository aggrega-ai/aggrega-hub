# Every variable is named for the resource argument it sets, except
# eventhubs, which names the event hubs and their partition counts.
# public_network_access_enabled, tags and eventhubs have defaults; the caller
# supplies every other one on every call.

variable "name" {
  type        = string
  description = "Name of the namespace, and the first label of its host name."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group the namespace is created in."
}

variable "location" {
  type        = string
  description = "Region the namespace is created in, such as westeurope."
}

variable "sku" {
  type        = string
  description = "Tier of the namespace: Standard or Premium."
}

variable "capacity" {
  type        = number
  description = "Throughput units of a Standard namespace, or processing units of a Premium one."
}

variable "public_network_access_enabled" {
  type        = bool
  default     = true
  description = "Whether the namespace takes requests over its public endpoint."
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Tags of the namespace."
}

variable "eventhubs" {
  type = map(object({
    partition_count = number
  }))
  default     = {}
  description = "Event hubs created in the namespace, by name, each with its partition count."
}
