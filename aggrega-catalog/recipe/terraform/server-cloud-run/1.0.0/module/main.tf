# required_providers pins hashicorp/google so the engine installs a provider whose
# resource schema this module was written against. It is a range rather than an
# exact version because every Google module in one root configuration shares one
# installed provider, and two exact pins that differ fail init. The constraint
# string is the one the Aggrega catalog conventions' "One Google provider
# constraint for every Google body" section states; this file repeats it
# deliberately, because a vendored module is copied byte for byte and imports
# nothing.
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.8"
    }
  }
}

# One Cloud Run service running the server's container, in a project, region and
# VPC network that already exist, under a service account that already exists.
# The module declares the service and nothing else: no service account, IAM
# binding, network, subnet, firewall rule, load balancer or domain mapping, each
# of which belongs to the operator who names it.
#
# Ingress is internal only, written here rather than taken from the caller: the
# service accepts requests from VPC networks in its project, from the Shared VPC
# network it sends traffic to and from an internal Application Load Balancer, and
# none from the internet. No invoker binding is declared and the invoker check is
# left on, its default, so a caller reaches the service only with an identity the
# operator has granted the Cloud Run Invoker role.
#
# The service runs a fixed number of instances: scaling is manual at the service
# level, and manual_instance_count is how many run. Its egress to the operator's
# VPC network is Direct VPC egress, carrying traffic to private addresses alone, so
# a Cloud SQL or Memorystore address in that network is reachable and every other
# destination is reached as it would be with no network named. The revision runs
# in the second-generation execution environment, and its request concurrency is
# Cloud Run's default.
resource "google_cloud_run_v2_service" "this" {
  project             = var.project_id
  location            = var.location
  name                = var.name
  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = var.deletion_protection

  scaling {
    scaling_mode          = "MANUAL"
    manual_instance_count = var.manual_instance_count
  }

  template {
    service_account       = var.service_account
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network    = var.network
        subnetwork = var.subnetwork
        tags       = var.tags
      }
    }

    # One container, main, receiving requests on var.port. Its environment is
    # one entry per key of var.environment, in the key order Terraform iterates
    # a map in. No probe is declared: a probe names a path or a port inside an
    # image this module does not know.
    containers {
      name  = "main"
      image = var.image

      ports {
        container_port = var.port
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      dynamic "env" {
        for_each = var.environment
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }
}
