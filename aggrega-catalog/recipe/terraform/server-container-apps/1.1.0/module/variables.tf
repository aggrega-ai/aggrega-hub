# Every variable is named for the resource argument it sets, except port, which
# sets the ingress's target port; replicas, which sets both the minimum and the
# maximum replica count; environment, which sets the main container's variables;
# files, which sets the files mounted into it; and the registry and identity
# variables, each named for the block and the argument it sets joined with an
# underscore. Those with no default are supplied by the caller on every call;
# those defaulting to null or empty leave their argument or block out, so nothing
# is emitted for them.

variable "name" {
  type        = string
  description = "Name of the container app, unique in its resource group."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the existing resource group the container app is created in."
}

variable "container_app_environment_id" {
  type        = string
  description = "Resource ID of the existing Container Apps environment the app runs in."
}

variable "image" {
  type        = string
  description = "Container image the main container runs."
}

variable "port" {
  type        = number
  description = "Port the main container receives requests on, the ingress's target port."
}

variable "cpu" {
  type        = number
  description = "vCPU of the main container, one of the Consumption profile's sizes, 0.25 to 4.0 in steps of 0.25."
}

variable "memory" {
  type        = string
  description = "Memory of the main container, twice its vCPU in Gi, such as 0.5Gi for 0.25 vCPU."
}

variable "replicas" {
  type        = number
  description = "Number of replicas the app runs, its minimum and its maximum."
}

variable "environment" {
  type        = map(string)
  description = "Environment variables of the main container, name to value."
}

variable "files" {
  type        = map(string)
  default     = {}
  description = "Files mounted into the main container from secrets, absolute path to content."
}

variable "identity_ids" {
  type        = list(string)
  default     = []
  description = "Resource IDs of existing user-assigned managed identities the app's code may use."
}

variable "registry_server" {
  type        = string
  default     = null
  description = "Host name of the private container registry the image is pulled from; none while null."
}

variable "registry_identity" {
  type        = string
  default     = null
  description = "Resource ID of the existing user-assigned identity the image is pulled with."
}

variable "registry_username" {
  type        = string
  default     = null
  description = "User name the image is pulled with, beside the password read from Key Vault."
}

variable "registry_password_secret_id" {
  type        = string
  default     = null
  description = "ID of the existing Key Vault secret holding the registry password."
}

variable "registry_password_identity" {
  type        = string
  default     = null
  description = "Resource ID of the existing user-assigned identity the registry password is read from Key Vault with."
}
