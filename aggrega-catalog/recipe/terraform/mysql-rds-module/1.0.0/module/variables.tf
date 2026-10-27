variable "db_name" {
  type        = string
  description = "Logical database name."
}

variable "engine_version" {
  type    = string
  default = "8.4"
}

variable "instance_class" {
  type        = string
  description = "RDS instance class; supplied by the caller."
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "storage_type" {
  type        = string
  description = "RDS storage type, such as gp3; supplied by the caller."
}

variable "backup_retention_period" {
  type        = number
  description = "Days of automated backups to keep, zero for none; supplied by the caller."
}

variable "backup_window" {
  type        = string
  default     = null
  description = "Daily window automated backups start in, hh24:mi-hh24:mi in UTC, such as 02:30-03:00; null leaves RDS to choose it."
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Whether deleting the instance skips its final snapshot; supplied by the caller."
}

variable "port" {
  type        = number
  description = "Port the database listens on; supplied by the caller."
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "subnet_id" {
  type        = string
  description = "DB subnet group name; supplied by the caller."
}
