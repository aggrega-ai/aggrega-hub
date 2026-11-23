# Every variable is named for the resource argument it sets, save type, which
# chooses the resource, and mx_records, srv_records and caa_records, which set
# the record blocks of the MX, SRV and CAA resources. The record variables and
# tags have defaults; the caller supplies every other one on every call.

variable "name" {
  type        = string
  description = "Name of the record set relative to the zone, @ for the zone's apex."
}

variable "zone_name" {
  type        = string
  description = "Name of the operator's Azure DNS zone the record set is written into."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group holding the zone."
}

variable "type" {
  type        = string
  description = "Record type: A, AAAA, CAA, CNAME, MX, NS, PTR, SRV or TXT."
}

variable "ttl" {
  type        = number
  description = "Seconds a resolver may cache the record set's answers."
}

variable "records" {
  type        = list(string)
  default     = []
  description = "The records of an A, AAAA, CNAME, NS, PTR or TXT record set: addresses, domain names or texts."
}

variable "mx_records" {
  type = list(object({
    preference = number
    exchange   = string
  }))
  default     = []
  description = "The records of an MX record set."
}

variable "srv_records" {
  type = list(object({
    priority = number
    weight   = number
    port     = number
    target   = string
  }))
  default     = []
  description = "The records of an SRV record set."
}

variable "caa_records" {
  type = list(object({
    flags = number
    tag   = string
    value = string
  }))
  default     = []
  description = "The records of a CAA record set."
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Metadata of the record set."
}
