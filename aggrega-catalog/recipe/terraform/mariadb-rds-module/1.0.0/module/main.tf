resource "aws_db_instance" "this" {
  identifier           = var.db_name
  engine               = "mariadb"
  engine_version       = var.engine_version
  allocated_storage    = var.allocated_storage
  multi_az             = var.multi_az
  db_subnet_group_name = var.subnet_id

  db_name  = var.db_name
  username = "admin"

  # RDS manages the master password via AWS Secrets Manager.
  manage_master_user_password = true

  # A module-internal Terraform interpolation, vendored byte-for-byte.
  tags = {
    Name = "${var.db_name}-mariadb"
  }
}

output "endpoint" {
  value = aws_db_instance.this.endpoint
}
