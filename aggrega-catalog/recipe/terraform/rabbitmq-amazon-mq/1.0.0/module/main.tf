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

# One Amazon MQ broker running RabbitMQ, in subnets and security groups that
# already exist, reached from inside the VPC alone. The module declares the
# broker and nothing else: no subnet, security group, configuration, log group
# or DNS record, each of which belongs to the operator.
#
# Amazon MQ serves RabbitMQ's AMQP 0-9-1 over TLS alone, on port 5671, with a
# certificate naming the broker's own endpoint. It creates exactly one user
# when the broker is provisioned, the administrative user declared here; any
# further user is created against the running broker. The provider records
# that user's password in the Terraform state, as it does every argument.
#
# Amazon MQ requires automatic minor version upgrades on for RabbitMQ 3.13 and
# above, which is every version the calling Recipe accepts, so the argument is
# set rather than left to the provider. The broker takes no public address.
resource "aws_mq_broker" "this" {
  broker_name                = var.broker_name
  engine_type                = "RabbitMQ"
  engine_version             = var.engine_version
  host_instance_type         = var.host_instance_type
  deployment_mode            = var.deployment_mode
  auto_minor_version_upgrade = true
  publicly_accessible        = false
  subnet_ids                 = var.subnet_ids
  security_groups            = var.security_groups

  user {
    username = var.username
    password = var.password
  }
}

# The host of the broker's AMQP endpoint. Amazon MQ publishes each endpoint as
# a URL, amqps://<host>:5671 for AMQP, and the provider lists that one first
# for every RabbitMQ version, so the host is the part between the scheme and
# the port. A single-instance broker and a cluster each answer at one such
# host, a load balancer in front of the broker's nodes.
output "amqp_host" {
  value = regex("^amqps://([^:/]+)", aws_mq_broker.this.instances[0].endpoints[0])[0]
}
