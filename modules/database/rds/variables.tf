variable "identifier" {
  description = "RDS instance identifier"
  type        = string
}

variable "engine" {
  description = "Database engine"
  type        = string
  default     = "mysql"
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.small"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "storage_type" {
  description = "Storage type"
  type        = string
  default     = "gp3"
}

variable "storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "db_name" {
  description = "Default database name"
  type        = string
  default     = "appdb"
}

variable "username" {
  description = "Database username"
  type        = string
  default     = "appuser"
}

variable "port" {
  description = "Database port"
  type        = number
  default     = 3306
}

variable "manage_master_user_password" {
  description = "Manage master user password with Secrets Manager"
  type        = bool
  default     = true
}

variable "master_user_secret_kms_key_id" {
  description = "KMS key for Secrets Manager"
  type        = string
  default     = "alias/aws/rds"
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "maintenance_window" {
  description = "Maintenance window"
  type        = string
  default     = "Mon:00:00-Mon:03:00"
}

variable "backup_window" {
  description = "Backup window"
  type        = string
  default     = "03:00-06:00"
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "db_subnet_group_name" {
  description = "DB subnet group name"
  type        = string
}

variable "parameter_group_name" {
  description = "DB parameter group name"
  type        = string
  default     = "default.mysql8.0"
}

variable "parameters" {
  description = "DB parameters"
  type        = list(object({ name = string, value = string }))
  default     = []
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}