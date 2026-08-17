variable "bucket" {
  type        = string
  description = "Name of the externally-operated bucket this deployment reads and writes."
}

variable "access_key_id" {
  type        = string
  description = "Identifier of the access-key pair presented to the storage service."
}

# This variable carries no `sensitive` attribute of its own, and that absence is
# deliberate rather than an omission: the caller's declaration supplies it, and an
# appended override file adds the attribute to this declaration at render time. A
# module that marked its own input would still be correct, but it would no longer
# show that the marking travels from the caller — so do not add one here.
variable "secret_access_key" {
  type        = string
  description = "Secret half of the access-key pair presented to the storage service."
}
