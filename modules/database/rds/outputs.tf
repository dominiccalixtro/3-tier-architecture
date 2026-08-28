output "id" {
  description = "RDS instance identifier"
  value       = module.rds.db_instance_identifier
}

output "arn" {
  description = "RDS instance ARN"
  value       = module.rds.db_instance_arn
}

output "endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_instance_endpoint
}

output "port" {
  description = "RDS instance port"
  value       = module.rds.db_instance_port
}

output "master_user_secret_arn" {
  description = "ARN of the master user secret in Secrets Manager"
  value       = module.rds.db_instance_master_user_secret_arn
}

output "db_subnet_group_id" {
  description = "DB subnet group ID"
  value       = module.rds.db_subnet_group_id
}