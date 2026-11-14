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

# One Amazon ECS service running the server's container on Fargate, in a
# cluster, subnets and security groups that already exist, under an execution
# role that already exists. The module declares the task definition and the
# service and nothing else: no cluster, role, security group, log group or load
# balancer, each of which belongs to the operator who names it.
#
# The worker's module beside recipe/terraform/worker-ecs declares the same two
# resources without the port and the load balancer. Each Recipe vendors the
# module kept beside it, so the two are separate files by construction.

# The Region the provider configuration deploys into, read when the plan is
# made. The awslogs log driver takes the Region of the log group it writes to,
# and the log group is the operator's, in the Region the service runs in. A data
# source reads; it creates nothing.
data "aws_region" "current" {
  count = var.awslogs_group == null ? 0 : 1
}

locals {
  # The container's log configuration, present only while the caller names a
  # log group. The stream prefix is the service's name, so each task's stream
  # is named <service>/main/<task id>.
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
        name      = "main"
        image     = var.image
        essential = true
        portMappings = [
          {
            containerPort = var.port
            protocol      = "tcp"
          }
        ]
        environment = [for k, v in var.environment : { name = k, value = v }]
      },
      local.log_configuration
    )
  ])
}

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster
  task_definition = aws_ecs_task_definition.this.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_groups
    assign_public_ip = var.assign_public_ip
  }

  # Registers each task's container port with the operator's target group,
  # while one is named. The load balancer, its listener and the target group's
  # own health check are the operator's.
  dynamic "load_balancer" {
    for_each = var.target_group_arn == null ? [] : [var.target_group_arn]
    content {
      target_group_arn = load_balancer.value
      container_name   = "main"
      container_port   = var.port
    }
  }
}
