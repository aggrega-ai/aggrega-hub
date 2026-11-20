variable "config" {
  type = any
}

module "service" {
  source = "./service"
  config = var.config
}

output "service" {
  value = module.service
}
