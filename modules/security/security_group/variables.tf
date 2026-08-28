variable "name" {
  description = "Name of the security group"
  type        = string
}

variable "description" {
  description = "Description of the security group"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the security group will be created"
  type        = string
}

variable "ingress_rules" {
  description = "List of ingress rule objects"
  type = list(object({
    from_port         = number
    to_port           = number
    protocol          = string
    cidr_blocks       = optional(list(string))
    ipv6_cidr_blocks  = optional(list(string))
    security_group_id = optional(string)
    description       = optional(string)
  }))
  default = []
}

variable "egress_rules" {
  description = "List of egress rule objects"
  type = list(object({
    from_port         = number
    to_port           = number
    protocol          = string
    cidr_blocks       = optional(list(string))
    ipv6_cidr_blocks  = optional(list(string))
    security_group_id = optional(string)
    description       = optional(string)
  }))
  default = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]
}
