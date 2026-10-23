# Every variable is named for the resource argument it sets; cpu_count and
# memory_size_mb set the instance's node_config, and params its
# memcache_parameters. None has a default: the caller supplies each on every
# call, params as an empty map where it sets no parameter.

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
  description = "Name of the instance, unique in the project and region."
}

variable "authorized_network" {
  type        = string
  description = "Resource link of the VPC network the instance is reached from, projects/<project>/global/networks/<name>."
}

variable "memcache_version" {
  type        = string
  description = "MEMCACHE_1_5 or MEMCACHE_1_6_15."
}

variable "node_count" {
  type        = number
  description = "Number of nodes."
}

variable "cpu_count" {
  type        = number
  description = "vCPUs per node, which the service makes the node's worker thread count."
}

variable "memory_size_mb" {
  type        = number
  description = "Memory per node in MB, which the service makes the node's memcached memory limit."
}

variable "params" {
  type        = map(string)
  description = "Memcached parameters the service lets an instance set, by name."
}
