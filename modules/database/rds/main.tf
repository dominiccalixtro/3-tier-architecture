module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = var.identifier

  engine            = var.engine
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type
  storage_encrypted = var.storage_encrypted

  db_name  = var.db_name
  username = var.username
  port     = var.port

  manage_master_user_password   = var.manage_master_user_password
  master_user_secret_kms_key_id = var.master_user_secret_kms_key_id

  vpc_security_group_ids = var.vpc_security_group_ids

  maintenance_window      = var.maintenance_window
  backup_window           = var.backup_window
  backup_retention_period = var.backup_retention_period

  deletion_protection = var.deletion_protection

  db_subnet_group_name = var.db_subnet_group_name

  parameter_group_name = var.parameter_group_name
  parameters           = var.parameters

  multi_az = var.multi_az

  tags = var.tags
}