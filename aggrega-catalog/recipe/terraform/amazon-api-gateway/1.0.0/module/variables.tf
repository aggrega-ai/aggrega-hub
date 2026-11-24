# Every variable is named for the resource argument it sets. connection_id,
# domain_name, certificate_arn and tags have defaults; the caller supplies
# every other one on every call.

variable "name" {
  type        = string
  description = "Name of the HTTP API."
}

variable "integration_uri" {
  type        = string
  description = "URL every request is forwarded to, https://<host>[:<port>], or, with connection_id, the ARN of the listener or AWS Cloud Map service behind the VPC link."
}

variable "connection_id" {
  type        = string
  default     = null
  description = "ID of the VPC link the integration forwards through, or null to forward over the internet."
}

variable "domain_name" {
  type        = string
  default     = null
  description = "Name of the API's custom domain, or null for none."
}

variable "certificate_arn" {
  type        = string
  default     = null
  description = "ARN of the AWS Certificate Manager certificate the custom domain presents; read only with domain_name."
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Tags of the API, its stage and its custom domain."
}
