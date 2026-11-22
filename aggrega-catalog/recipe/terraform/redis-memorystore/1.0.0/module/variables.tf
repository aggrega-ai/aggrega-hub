# Every variable is named for the resource argument it sets, except project_id,
# which sets project, and persistence_mode, which sets the mode of its
# persistence_config. replica_count and read_replicas_mode default to null,
# leaving each to the service; the caller supplies every other variable on every
# call.

variable "project_id" {
  type        = string
  description = "ID of the Google Cloud project the instance is created in."
}

variable "region" {
  type        = string
  description = "Region the instance is created in, such as europe-west1."
}

variable "name" {
  type        = string
  description = "ID of the instance, unique in the project and region."
}

variable "tier" {
  type        = string
  description = "BASIC, one node, or STANDARD_HA, a primary and a replica it fails over to."
}

variable "memory_size_gb" {
  type        = number
  description = "Capacity of the instance in GiB."
}

variable "redis_version" {
  type        = string
  description = "Redis version in the service's spelling, such as REDIS_7_2."
}

variable "authorized_network" {
  type        = string
  description = "Resource link of the VPC network the instance is reached from, projects/<project>/global/networks/<name>."
}

variable "transit_encryption_mode" {
  type        = string
  description = "DISABLED, or SERVER_AUTHENTICATION for TLS alone."
}

variable "redis_configs" {
  type        = map(string)
  description = "Redis configuration parameters the service lets an instance set, by name."
}

variable "replica_count" {
  type        = number
  default     = null
  description = "Number of replicas of a Standard Tier instance with read replicas on, 1 to 5; null leaves it to the service."
}

variable "read_replicas_mode" {
  type        = string
  default     = null
  description = "READ_REPLICAS_ENABLED to run replica_count replicas; null leaves it to the service."
}

variable "persistence_mode" {
  type        = string
  description = "DISABLED, or RDB for a snapshot every hour."
}
