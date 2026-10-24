# Every variable is named for the resource argument it sets, except network,
# subnetwork and tags, which set the service's one network interface, port, which
# sets the main container's port, and environment, which sets the main
# container's variables. Those with no default are supplied by the caller on
# every call; those defaulting to null leave their argument unset, so nothing is
# emitted for them.

variable "project_id" {
  type        = string
  description = "ID of the Google Cloud project the service is created in."
}

variable "location" {
  type        = string
  description = "Region the service is created in, such as europe-west1."
}

variable "name" {
  type        = string
  description = "Name of the service, unique in the project and region among services and worker pools."
}

variable "image" {
  type        = string
  description = "Container image the main container runs."
}

variable "port" {
  type        = number
  description = "Port the main container receives requests on."
}

variable "cpu" {
  type        = string
  description = "CPU limit of the main container in vCPU, one of 1, 2, 4, 6 and 8."
}

variable "memory" {
  type        = string
  description = "Memory limit of the main container, such as 512Mi, within the range cpu takes."
}

variable "manual_instance_count" {
  type        = number
  description = "Number of instances the service runs."
}

variable "environment" {
  type        = map(string)
  description = "Environment variables of the main container, name to value."
}

variable "service_account" {
  type        = string
  description = "Email of the existing service account the service runs as."
}

variable "network" {
  type        = string
  description = "Resource link of the existing VPC network the service sends traffic to private addresses through, projects/<project>/global/networks/<name>."
}

variable "subnetwork" {
  type        = string
  default     = null
  description = "Name or resource link of the existing subnet the instances take addresses from; the subnet named as the network while null."
}

variable "tags" {
  type        = list(string)
  default     = null
  description = "Network tags on the service's instances, which egress firewall rules can match; none while null."
}

variable "deletion_protection" {
  type        = bool
  default     = null
  description = "Whether Terraform refuses to destroy the service; the provider's default, true, while null."
}
