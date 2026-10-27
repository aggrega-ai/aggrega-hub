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

resource "aws_db_instance" "this" {
  identifier           = var.db_name
  engine               = "mysql"
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  storage_type         = var.storage_type
  port                 = var.port
  multi_az             = var.multi_az
  db_subnet_group_name = var.subnet_id

  # A retention of zero turns automated backups off, and the caller then skips
  # the final snapshot as well. A null window leaves RDS to choose one.
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  skip_final_snapshot     = var.skip_final_snapshot

  db_name  = var.db_name
  username = "admin"

  # RDS manages the master password via AWS Secrets Manager.
  manage_master_user_password = true

  # A module-internal Terraform interpolation, vendored byte-for-byte.
  tags = {
    Name = "${var.db_name}-mysql"
  }
}

output "address" {
  value = aws_db_instance.this.address
}

output "endpoint" {
  value = aws_db_instance.this.endpoint
}
