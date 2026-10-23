# Every variable is named for the resource argument it sets, except network,
# which sets the network of the instance's desired_auto_created_endpoints block,
# and persistence_mode, which sets its persistence_config mode. None has a
# default: the caller supplies each on every call.

variable "project_id" {
  type        = string
  description = "ID of the Google Cloud project the instance is created in."
}

variable "location" {
  type        = string
  description = "Region the instance is created in, such as europe-west1."
}

variable "instance_id" {
  type        = string
  description = "ID of the instance, unique in the project and region."
}

variable "network" {
  type        = string
  description = "Resource link of the VPC network the instance is reached from, projects/<project>/global/networks/<name>."
}

variable "replica_count" {
  type        = number
  description = "Number of replica nodes beside the primary."
}

variable "node_type" {
  type        = string
  description = "Node type, such as CUSTOM_PICO or STANDARD_SMALL."
}

variable "engine_version" {
  type        = string
  description = "Valkey version in the service's spelling, such as VALKEY_8_0."
}

variable "engine_configs" {
  type        = map(string)
  description = "Valkey configuration parameters the service lets an instance set, by name."
}

variable "transit_encryption_mode" {
  type        = string
  description = "TRANSIT_ENCRYPTION_DISABLED, or SERVER_AUTHENTICATION for TLS alone."
}

variable "persistence_mode" {
  type        = string
  description = "DISABLED, AOF or RDB."
}
