# required_providers pins hashicorp/aws so the engine installs a provider whose
# resource schema this module was written against. It is a range rather than an
# exact version because every AWS module in one root configuration shares one
# installed provider, and two exact pins that differ fail init. The constraint
# string is the one the Aggrega catalog conventions' "One AWS provider
# constraint for every AWS body" section states; this file repeats it
# deliberately, because a vendored module is copied byte for byte and imports
# nothing.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.69"
    }
  }
}

# One Amazon ECS task definition for Fargate and one EventBridge Scheduler
# schedule that runs it, in a cluster, subnets and security groups that already
# exist, under an execution role and a scheduler role that already exist. The
# module declares the task definition and the schedule and nothing else: no
# cluster, role, security group, log group or load balancer, each of which
# belongs to the operator who names it, and no service, since a run ends. The
# container maps no port: nothing connects to a run.
#
# While the caller passes no schedule expression, no schedule is declared and
# the task definition stands alone, for a run someone starts with the Amazon
# ECS RunTask operation; the cluster and network inputs then set nothing here,
# and are the values that run is started with.
#
# The worker's module beside recipe/terraform/worker-ecs declares the same task
# definition under a service. Each Recipe vendors the module kept beside it, so
# the two are separate files by construction.

# The Region the provider configuration deploys into, read when the plan is
# made. The awslogs log driver takes the Region of the log group it writes to,
# and the log group is the operator's, in the Region the task runs in. A data
# source reads; it creates nothing.
data "aws_region" "current" {
  count = var.awslogs_group == null ? 0 : 1
}

locals {
  # The container's log configuration, present only while the caller names a
  # log group. The stream prefix is the task definition's family, so each run's
  # stream is named <family>/main/<task id>.
  log_configuration = {
    for k, v in {
      logConfiguration = var.awslogs_group == null ? null : {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.awslogs_group
          "awslogs-region"        = data.aws_region.current[0].region
          "awslogs-stream-prefix" = var.name
        }
      }
    } : k => v if v != null
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  # One essential container, main. Its environment is one entry per key of
  # var.environment, in the key order Terraform iterates a map in. No health
  # check is declared: ECS runs a container health check as a command inside
  # the image, and an image the module does not name may carry no tool to run.
  container_definitions = jsonencode([
    merge(
      {
        name        = "main"
        image       = var.image
        essential   = true
        environment = [for k, v in var.environment : { name = k, value = v }]
      },
      local.log_configuration
    )
  ])
}

# The schedule calls the Amazon ECS RunTask operation on the cluster at each
# time its expression names, evaluated in its time zone, starting one task of
# the definition above on Fargate. The flexible time window is off, so a run
# starts within the minute the expression names rather than within a window
# after it. Its retry policy is the scheduler's own default.
resource "aws_scheduler_schedule" "this" {
  count = var.schedule_expression == null ? 0 : 1

  name                         = var.name
  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = var.schedule_expression_timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = var.cluster
    role_arn = var.scheduler_role_arn

    ecs_parameters {
      task_definition_arn = aws_ecs_task_definition.this.arn
      launch_type         = "FARGATE"
      task_count          = 1

      network_configuration {
        subnets          = var.subnet_ids
        security_groups  = var.security_groups
        assign_public_ip = var.assign_public_ip
      }
    }
  }
}
