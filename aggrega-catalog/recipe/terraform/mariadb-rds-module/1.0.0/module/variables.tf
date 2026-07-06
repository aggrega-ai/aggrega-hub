variable "db_name" {
  type        = string
  description = "Logical database name."
}

variable "engine_version" {
  type    = string
  default = "11.4"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "subnet_id" {
  type        = string
  description = "DB subnet group name; supplied by the caller."
}
