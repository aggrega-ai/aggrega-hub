# Every variable is named for the resource argument it sets, except subnet_ids,
# which sets the schedule's subnets under the name the caller's key carries, and
# cluster and scheduler_role_arn, which set the schedule target's arn and
# role_arn. Those with no default are supplied by the caller on every call;
# those defaulting to null leave their argument unset, so nothing is emitted for
# them, except schedule_expression: while it is null no schedule is declared,
# and the caller passes neither scheduler_role_arn nor
# schedule_expression_timezone.

variable "name" {
  type        = string
  description = "Name of the schedule and family of its task definition."
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

variable "environment" {
  type        = map(string)
  description = "Environment variables of the main container, name to value."
}

variable "schedule_expression" {
  type        = string
  default     = null
  description = "EventBridge Scheduler cron expression naming when a run starts; no schedule while null."
}

variable "schedule_expression_timezone" {
  type        = string
  default     = null
  description = "Time zone the schedule expression is evaluated in, an IANA name such as UTC."
}

variable "cluster" {
  type        = string
  description = "ARN of the existing ECS cluster each run starts in."
}

variable "scheduler_role_arn" {
  type        = string
  default     = null
  description = "ARN of the existing role EventBridge Scheduler assumes to start each run."
}

variable "subnet_ids" {
  type        = list(string)
  description = "IDs of the existing subnets each run is placed in."
}

variable "security_groups" {
  type        = list(string)
  description = "IDs of the existing security groups each run joins."
}

variable "assign_public_ip" {
  type        = bool
  description = "Whether each run's network interface receives a public IP address."
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
