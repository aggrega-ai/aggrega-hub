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

# One Memorystore for Valkey instance in Cluster Mode Disabled, one shard, reached
# from the operator's VPC network alone. The module declares the instance and
# nothing else: no network, no service connection policy, no firewall rule and
# no DNS record, each of which belongs to the operator.
#
# Memorystore for Valkey connects to a network only through Private Service
# Connect, deployed for the instance by the service connection policy that must
# already exist for the project, network, region and the gcp-memorystore service
# class. desired_auto_created_endpoints asks for that connection in the network
# the caller names.
#
# Authentication is off: the service mints its own token for token
# authentication, and IAM authentication needs short-lived IAM access tokens, so
# no password a Release supplies could reach the instance. In-transit encryption
# is the caller's choice, with the instance's own certificate authority, the
# service's default.
resource "google_memorystore_instance" "this" {
  project                 = var.project_id
  location                = var.location
  instance_id             = var.instance_id
  mode                    = "CLUSTER_DISABLED"
  shard_count             = 1
  replica_count           = var.replica_count
  node_type               = var.node_type
  engine_version          = var.engine_version
  engine_configs          = var.engine_configs
  authorization_mode      = "AUTH_DISABLED"
  transit_encryption_mode = var.transit_encryption_mode

  desired_auto_created_endpoints {
    network    = var.network
    project_id = var.project_id
  }

  persistence_config {
    mode = var.persistence_mode
    dynamic "aof_config" {
      for_each = var.persistence_mode == "AOF" ? ["aof"] : []
      content {
        append_fsync = "EVERY_SEC"
      }
    }
    dynamic "rdb_config" {
      for_each = var.persistence_mode == "RDB" ? ["rdb"] : []
      content {
        rdb_snapshot_period = "ONE_HOUR"
      }
    }
  }
}

locals {
  # Every connection the service created for the instance, across its
  # endpoints. A Cluster Mode Disabled instance has a primary and a reader
  # connection; the primary takes reads and writes.
  connections = flatten([
    for e in google_memorystore_instance.this.endpoints : [
      for c in e.connections : c.psc_auto_connection
    ]
  ])
}

# The address of the instance's primary endpoint, in the caller's network.
output "primary_address" {
  value = one([for c in local.connections : c.ip_address if c.connection_type == "CONNECTION_TYPE_PRIMARY"])
}

# The certificate authority chain a client checks the instance's certificate
# against while in-transit encryption is on, in PEM, leaf to root; empty while
# it is off. It is the instance's own authority, which the service rotates.
output "server_ca" {
  value = join("\n", flatten([
    for ca in google_memorystore_instance.this.managed_server_ca : [
      for chain in ca.ca_certs : chain.certificates
    ]
  ]))
}
