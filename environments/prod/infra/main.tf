data "aws_availability_zones" "availability_zones" {
  state = "available"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

resource "tls_private_key" "alb" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb" {
  private_key_pem = tls_private_key.alb.private_key_pem

  subject {
    common_name = var.alb_domain_name
  }

  validity_period_hours = 8760

  allowed_uses = ["key_encipherment", "digital_signature", "server_auth"]
}

locals {
  availability_zones  = data.aws_availability_zones.availability_zones.names
  alb_certificate_arn = var.acm_certificate_arn != "" ? var.acm_certificate_arn : aws_acm_certificate.this[0].arn
}

module "network" {
  source = "../../../modules/networking/vpc"

  vpc_cidr              = var.vpc_cidr
  public_subnets_cidr   = var.public_subnets_cidr
  private_subnets_cidr  = var.private_subnets_cidr
  database_subnets_cidr = var.database_subnets_cidr
  availability_zones    = local.availability_zones
  nat_gateway_count     = var.nat_gateway_count
}

module "iam" {
  source = "../../../modules/security/iam"

  role_name = var.role_name
}

module "alb_sg" {
  source      = "../../../modules/security/security_group"
  name        = "${var.project}-${var.environment}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = module.network.vpc_id

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP (redirects to HTTPS)"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS"
    }
  ]
}

module "web_sg" {
  source      = "../../../modules/security/security_group"
  name        = "${var.project}-${var.environment}-web-sg"
  description = "Security group for web servers"
  vpc_id      = module.network.vpc_id

  ingress_rules = [
    {
      from_port         = 80
      to_port           = 80
      protocol          = "tcp"
      security_group_id = module.alb_sg.id
      description       = "Allow HTTP from ALB"
    }
  ]
}

module "db_sg" {
  source      = "../../../modules/security/security_group"
  name        = "${var.project}-${var.environment}-db-sg"
  description = "Security group for database"
  vpc_id      = module.network.vpc_id

  ingress_rules = [
    {
      from_port         = 3306
      to_port           = 3306
      protocol          = "tcp"
      security_group_id = module.web_sg.id
      description       = "Allow MySQL from web tier"
    }
  ]
}

module "alb" {
  source = "../../../modules/compute/alb"

  vpc_id             = module.network.vpc_id
  public_subnets_ids = module.network.public_subnets_ids
  alb_sg_id          = module.alb_sg.id
  certificate_arn    = local.alb_certificate_arn
}

resource "aws_acm_certificate" "this" {
  count = var.acm_certificate_arn == "" ? 1 : 0

  domain_name      = var.alb_domain_name
  certificate_body = tls_self_signed_cert.alb.cert_pem
  private_key      = tls_private_key.alb.private_key_pem
}

module "asg" {
  source = "../../../modules/compute/asg"

  name                      = "${var.project}-${var.environment}-web"
  project                   = var.project
  environment               = var.environment
  ami_id                    = data.aws_ami.amazon_linux_2.id
  instance_type             = var.instance_type
  iam_instance_profile      = module.iam.iam_instance_profile_name
  security_group_ids        = [module.web_sg.id]
  private_subnet_ids        = module.network.private_subnet_ids
  desired_capacity          = var.asg_desired_capacity
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  user_data_path            = "${path.module}/scripts/install_apache.sh"
  health_check_grace_period = 300
  target_group_arn          = module.alb.target_group_arn
}

module "rds" {
  source = "../../../modules/database/rds"

  identifier = "${var.project}-${var.environment}-db"

  engine            = "mysql"
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  port     = 3306

  manage_master_user_password   = true
  master_user_secret_kms_key_id = "alias/aws/rds"

  vpc_security_group_ids = [module.db_sg.id]

  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = var.backup_retention_period

  deletion_protection = var.deletion_protection

  db_subnet_group_name = module.network.db_subnet_group_id

  parameter_group_name = "default.mysql${var.db_engine_version}"
  parameters = [
    {
      name  = "character_set_client"
      value = "utf8mb4"
    },
    {
      name  = "character_set_server"
      value = "utf8mb4"
    }
  ]

  multi_az = var.multi_az

  tags = {
    Project     = var.project
    Environment = var.environment
    Name        = "${var.project}-${var.environment}-db"
  }
}