# Every variable is named for the resource argument it sets.
# sampling_percentage, local_authentication_enabled and tags have defaults;
# the caller supplies every other one on every call.

variable "name" {
  type        = string
  description = "Name of the Application Insights component."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group the component is created in."
}

variable "location" {
  type        = string
  description = "Region the component is created in, such as westeurope."
}

variable "workspace_id" {
  type        = string
  description = "Resource ID of the Log Analytics workspace the component stores its telemetry in."
}

variable "application_type" {
  type        = string
  description = "Application type of the component: web or other."
}

variable "sampling_percentage" {
  type        = number
  default     = 100
  description = "Share of the telemetry the service keeps when it ingests it, from 0 to 100."
}

variable "local_authentication_enabled" {
  type        = bool
  default     = true
  description = "Whether the component ingests telemetry carrying its instrumentation key alone, rather than only telemetry authenticated with Microsoft Entra ID."
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Tags of the component."
}
