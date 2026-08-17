# The bucket is operated outside this deployment, so nothing here provisions it
# and the module reaches no provider. What it does is record the reference: the
# public coordinates are held as replacement triggers, so a change to the bucket
# or the key identifier propagates to whatever depends on this module, and the
# credential is held as the resource's own input.
#
# Keeping the credential in a separate attribute from the public coordinates is
# what makes the sensitivity marking legible in plan output: the credential
# attribute is redacted while the coordinates beside it are not.
resource "terraform_data" "reference" {
  triggers_replace = [var.bucket, var.access_key_id]
  input            = var.secret_access_key
}

output "bucket" {
  value = var.bucket
}
