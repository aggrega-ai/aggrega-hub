# Every variable is named for the resource argument it sets, except username
# and password, which set the broker user's own two arguments, and subnet_ids
# and security_groups, which set the broker's arguments of those names. Those
# with no default are supplied by the caller on every call; security_groups
# defaults to null, which leaves its argument unset.

variable "broker_name" {
  type        = string
  description = "Name of the broker, unique in the AWS account."
}

variable "engine_version" {
  type        = string
  description = "RabbitMQ version, as its major and minor number, such as 4.3."
}

variable "host_instance_type" {
  type        = string
  description = "Broker instance type, such as mq.m7g.medium."
}

variable "deployment_mode" {
  type        = string
  description = "SINGLE_INSTANCE, one broker, or CLUSTER_MULTI_AZ, three nodes across Availability Zones."
}

variable "subnet_ids" {
  type        = list(string)
  description = "IDs of the existing subnets the broker is placed in."
}

variable "security_groups" {
  type        = list(string)
  default     = null
  description = "IDs of the existing security groups the broker joins; none while null."
}

variable "username" {
  type        = string
  description = "Name of the broker's one administrative user."
}

variable "password" {
  type        = string
  sensitive   = true
  description = "Password of the broker's administrative user."
}
