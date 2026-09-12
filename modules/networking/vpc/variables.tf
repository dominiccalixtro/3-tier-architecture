variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnets_cidr" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnets_cidr" {
  description = "CIDR blocks for private application subnets"
  type        = list(string)
}

variable "database_subnets_cidr" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
}

variable "nat_gateway_count" {
  description = "Number of NAT Gateways to create (1 for dev, number of AZs for prod)"
  type        = number
  default     = 1
}
variable "name_prefix" {
  description = "Prefix for named resources created by this module."
  type        = string
}

variable "flow_log_retention_days" {
  description = "CloudWatch Logs retention, in days, for VPC flow logs."
  type        = number
  default     = 30
}
