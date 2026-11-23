# Every variable is named for the resource argument it sets.
# public_network_access_enabled and tags have defaults; the caller supplies
# every other one on every call.

variable "name" {
  type        = string
  description = "Name of the topic, and the first label of its host name."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group the topic is created in."
}

variable "location" {
  type        = string
  description = "Region the topic is created in, such as westeurope."
}

variable "input_schema" {
  type        = string
  description = "Format a publisher sends events in: EventGridSchema or CloudEventSchemaV1_0."
}

variable "public_network_access_enabled" {
  type        = bool
  default     = true
  description = "Whether the topic takes events over its public endpoint."
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Tags of the topic."
}
