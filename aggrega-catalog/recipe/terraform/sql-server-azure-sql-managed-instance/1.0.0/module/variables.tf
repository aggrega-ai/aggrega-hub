# Every variable is named for the resource argument it sets, except
# database_name, which names the database. zone_redundant_enabled also chooses
# the storage the instance's backups are kept on. subnet_id takes the subnet
# the caller names as its delegated subnet. collation, zone_redundant_enabled,
# tags and short_term_retention_days have defaults; the caller supplies every
# other one on every call.

variable "name" {
  type        = string
  description = "Name of the managed instance, and the first label of its host name."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group the managed instance is created in."
}

variable "location" {
  type        = string
  description = "Region the managed instance is created in, the region of its subnet's virtual network, such as westeurope."
}

variable "sku_name" {
  type        = string
  description = "Tier and hardware in the provider's spelling, such as GP_Gen5 or BC_Gen8IM."
}

variable "vcores" {
  type        = number
  description = "Number of vCores, one the hardware and tier take."
}

variable "license_type" {
  type        = string
  description = "LicenseIncluded, a price including the SQL Server licence, or BasePrice, for a licence the operator brings."
}

variable "storage_size_in_gb" {
  type        = number
  description = "Storage of the managed instance, from 32 to 32768 in steps of 32."
}

variable "subnet_id" {
  type        = string
  description = "Resource ID of the subnet, delegated to Microsoft.Sql/managedInstances, the managed instance takes its address in."
}

variable "administrator_login" {
  type        = string
  description = "Login of the managed instance's administrator."
}

variable "administrator_login_password" {
  type        = string
  sensitive   = true
  description = "Password of the managed instance's administrator."
}

variable "collation" {
  type        = string
  default     = null
  description = "Collation of the managed instance, or null for the provider's default, SQL_Latin1_General_CP1_CI_AS."
}

variable "database_format" {
  type        = string
  description = "Update policy the instance's databases are aligned with: SQLServer2022 or SQLServer2025."
}

variable "zone_redundant_enabled" {
  type        = bool
  default     = false
  description = "Whether the managed instance is zone redundant."
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Tags of the managed instance."
}

variable "database_name" {
  type        = string
  description = "Name of the database created on the managed instance."
}

variable "short_term_retention_days" {
  type        = number
  default     = 7
  description = "Days the service keeps the database's backups for point-in-time restore, 1 to 35."
}
