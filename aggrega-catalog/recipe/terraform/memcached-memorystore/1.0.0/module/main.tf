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

# One Memorystore for Memcached instance of one node, in the operator's VPC
# network. The module declares the instance and nothing else: no network, no
# private services access connection, no firewall rule and no DNS record, each
# of which belongs to the operator.
#
# The service sets the node's memcached memory limit to the node's memory and its
# worker threads to the node's CPU count, so those two are the node's size. It
# serves port 11211 alone, offers no encryption in transit and no instance
# authentication.
resource "google_memcache_instance" "this" {
  project            = var.project_id
  region             = var.region
  name               = var.name
  authorized_network = var.authorized_network
  memcache_version   = var.memcache_version
  node_count         = var.node_count

  node_config {
    cpu_count      = var.cpu_count
    memory_size_mb = var.memory_size_mb
  }

  dynamic "memcache_parameters" {
    for_each = length(var.params) > 0 ? ["params"] : []
    content {
      params = var.params
    }
  }
}

# The address of the instance's first node. A client sends its data commands to
# the nodes themselves: the instance's discovery endpoint answers only the Auto
# Discovery service's queries.
output "node_address" {
  value = google_memcache_instance.this.memcache_nodes[0].host
}
