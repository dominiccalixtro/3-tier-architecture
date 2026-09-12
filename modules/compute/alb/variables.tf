variable "vpc_id" {
  description = "VPC the target group is created in."
  type        = string
}

variable "public_subnets_ids" {
  description = "Public subnets the load balancer is placed in."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group attached to the load balancer."
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate for the HTTPS listener."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for named resources created by this module."
  type        = string
}

variable "enable_deletion_protection" {
  description = "Block accidental deletion of the load balancer. Should be true anywhere the endpoint matters."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Days to keep load balancer access logs in S3."
  type        = number
  default     = 90
}
