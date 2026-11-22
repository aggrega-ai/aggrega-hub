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

# One Memorystore for Redis instance, reached from the operator's VPC network
# alone. The module declares the instance and nothing else: no network, no
# peering, no firewall rule and no DNS record, each of which belongs to the
# operator.
#
# The instance connects to the caller's network by direct peering, the
# service's default connection mode, which the service sets up itself when the
# instance is created, in an address range of its own choosing.
#
# Authentication is off: Redis AUTH on this service runs on an AUTH string the
# service generates for itself, so no password a Release supplies could reach
# the instance. In-transit encryption is the caller's choice; with it on, the
# instance serves TLS alone, on port 6378, with a certificate from the
# instance's own certificate authority.
#
# replica_count and read_replicas_mode are left to the service while the
# caller passes null: no replica on a Basic Tier instance, one replica a
# Standard Tier instance fails over to.
resource "google_redis_instance" "this" {
  project                 = var.project_id
  region                  = var.region
  name                    = var.name
  tier                    = var.tier
  memory_size_gb          = var.memory_size_gb
  redis_version           = var.redis_version
  authorized_network      = var.authorized_network
  connect_mode            = "DIRECT_PEERING"
  auth_enabled            = false
  transit_encryption_mode = var.transit_encryption_mode
  redis_configs           = var.redis_configs
  replica_count           = var.replica_count
  read_replicas_mode      = var.read_replicas_mode

  persistence_config {
    persistence_mode    = var.persistence_mode
    rdb_snapshot_period = var.persistence_mode == "RDB" ? "ONE_HOUR" : null
  }
}

# The address of the instance's primary endpoint, which takes reads and
# writes, in the caller's network.
output "host" {
  value = google_redis_instance.this.host
}

# The certificate authorities a client checks the instance's certificate
# against while in-transit encryption is on, in PEM, one after another; empty
# while it is off. They are the instance's own, which the service rotates.
output "server_ca" {
  value = join("\n", [for ca in google_redis_instance.this.server_ca_certs : ca.cert])
}
