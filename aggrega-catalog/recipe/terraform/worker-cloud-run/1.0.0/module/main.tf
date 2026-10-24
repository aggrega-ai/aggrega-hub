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

# One Cloud Run worker pool running the worker's container, in a project, region
# and VPC network that already exist, under a service account that already
# exists. The module declares the worker pool and nothing else: no service
# account, IAM binding, network, subnet, firewall rule or log sink, each of which
# belongs to the operator who names it. A worker pool has no endpoint and no URL,
# and the container declares no port.
#
# The worker pool runs a fixed number of instances: scaling is manual, and
# manual_instance_count is how many run. Its egress to the operator's VPC network
# is Direct VPC egress, carrying traffic to private addresses alone, so a Cloud
# SQL or Memorystore address in that network is reachable and every other
# destination is reached as it would be with no network named.
resource "google_cloud_run_v2_worker_pool" "this" {
  project             = var.project_id
  location            = var.location
  name                = var.name
  deletion_protection = var.deletion_protection

  scaling {
    scaling_mode          = "MANUAL"
    manual_instance_count = var.manual_instance_count
  }

  template {
    service_account = var.service_account

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network    = var.network
        subnetwork = var.subnetwork
        tags       = var.tags
      }
    }

    # One container, main. Its environment is one entry per key of
    # var.environment, in the key order Terraform iterates a map in. No probe is
    # declared: a worker serves no request a probe could send.
    containers {
      name  = "main"
      image = var.image

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
