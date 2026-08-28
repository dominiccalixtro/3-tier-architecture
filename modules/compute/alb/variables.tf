variable "vpc_id" {}

variable "public_subnets_ids" {
  type = list(string)
}

variable "alb_sg_id" {}

variable "certificate_arn" {}