# Every variable is named for the resource argument it sets, except
# mysql_version, which sets the server's version, a name Terraform reserves for
# an argument of a module block; storage_size_gb, which sets size_gb in its
# storage block; high_availability_mode, which sets mode in its
# high_availability block, left out while the variable is null; and
# database_name, which names the database. zone, high_availability_mode, tags
# and server_configuration have defaults; the caller supplies every other one on
# every call.

variable "name" {
  type        = string
  description = "Name of the server, unique across Azure, and the first label of its host name."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group the server, its database and its parameters are created in."
}

variable "location" {
  type        = string
  description = "Region the server is created in, such as westeurope."
}

variable "mysql_version" {
  type        = string
  description = "MySQL version in the provider's spelling: 5.7, 8.0.21 or 8.4."
}

variable "sku_name" {
  type        = string
  description = "Tier and compute size, such as GP_Standard_D2ds_v4."
}

variable "zone" {
  type        = string
  default     = null
  description = "Availability zone the server is placed in, 1, 2 or 3, or null for the service's choice."
}

variable "administrator_login" {
  type        = string
  description = "Login of the server's administrator."
}

variable "administrator_password" {
  type        = string
  sensitive   = true
  description = "Password of the server's administrator."
}

variable "delegated_subnet_id" {
  type        = string
  description = "Resource ID of the subnet, delegated to Microsoft.DBforMySQL/flexibleServers, the server takes its address in."
}

variable "private_dns_zone_id" {
  type        = string
  description = "Resource ID of the private DNS zone, ending in .mysql.database.azure.com, the server's name resolves through."
}

variable "backup_retention_days" {
  type        = number
  description = "Days the service keeps each automated backup, 1 to 35."
}

variable "storage_size_gb" {
  type        = number
  description = "Storage provisioned for the server, in GiB, 20 to 16384."
}

variable "high_availability_mode" {
  type        = string
  default     = null
  description = "ZoneRedundant or SameZone to run a standby server, or null for none."
}

variable "database_name" {
  type        = string
  description = "Name of the database created on the server."
}

variable "charset" {
  type        = string
  description = "Default character set of the database, such as utf8mb4."
}

variable "collation" {
  type        = string
  description = "Default collation of the database, such as utf8mb4_general_ci."
}

variable "server_configuration" {
  type = map(object({
    name   = string
    config = string
  }))
  default     = {}
  description = "Server parameters to set, each keyed by the caller, with the parameter's name and its value."
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Tags set on the server."
}
