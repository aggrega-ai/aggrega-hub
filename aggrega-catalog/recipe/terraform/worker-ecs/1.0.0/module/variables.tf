# Every variable is named for the resource argument it sets, except subnet_ids,
# which sets the service's subnets under the name the caller's key carries. Those
# with no default are supplied by the caller on every call; those defaulting to
# null leave their argument unset, so nothing is emitted for them.

variable "name" {
  type        = string
  description = "Name of the service and family of its task definition."
}

variable "image" {
  type        = string
  description = "Container image the main container runs."
}

variable "cpu" {
  type        = string
  description = "Task CPU in CPU units, one of the Fargate sizes."
}

variable "memory" {
  type        = string
  description = "Task memory in MiB, valid with cpu as a Fargate size."
}

variable "desired_count" {
  type        = number
  description = "Number of tasks the service keeps running."
}

variable "environment" {
  type        = map(string)
  description = "Environment variables of the main container, name to value."
}

variable "cluster" {
  type        = string
  description = "Name or ARN of the existing ECS cluster the service runs in."
}

variable "subnet_ids" {
  type        = list(string)
  description = "IDs of the existing subnets the tasks are placed in."
}

variable "security_groups" {
  type        = list(string)
  description = "IDs of the existing security groups the tasks join."
}

variable "assign_public_ip" {
  type        = bool
  description = "Whether each task's network interface receives a public IP address."
}

variable "execution_role_arn" {
  type        = string
  description = "ARN of the existing role ECS pulls the image and writes logs with."
}

variable "task_role_arn" {
  type        = string
  default     = null
  description = "ARN of an existing role the container calls AWS APIs with; none while null."
}

variable "awslogs_group" {
  type        = string
  default     = null
  description = "Name of an existing CloudWatch Logs log group the container logs to; none while null."
}
