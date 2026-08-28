variable "name" {}

variable "project" {}

variable "environment" {}

variable "instance_type" {}

variable "security_group_ids" {}

variable "ami_id" {}

variable "iam_instance_profile" {}

variable "max_size" {}

variable "min_size" {}

variable "health_check_grace_period" {}

variable "private_subnet_ids" {
  type = list(string)
}

variable "desired_capacity" {}

variable "user_data_path" {}

variable "target_group_arn" {}