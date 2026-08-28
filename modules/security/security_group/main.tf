resource "aws_security_group" "this" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id
}

# Ingress rules
resource "aws_security_group_rule" "ingress" {
  count = length(var.ingress_rules)

  type              = "ingress"
  from_port         = var.ingress_rules[count.index].from_port
  to_port           = var.ingress_rules[count.index].to_port
  protocol          = var.ingress_rules[count.index].protocol
  security_group_id = aws_security_group.this.id
  description       = lookup(var.ingress_rules[count.index], "description", null)

  cidr_blocks              = try(var.ingress_rules[count.index].cidr_blocks, null)
  source_security_group_id = try(var.ingress_rules[count.index].security_group_id, null)
}

# Egress rules
resource "aws_security_group_rule" "egress" {
  count = length(var.egress_rules)

  type              = "egress"
  from_port         = var.egress_rules[count.index].from_port
  to_port           = var.egress_rules[count.index].to_port
  protocol          = var.egress_rules[count.index].protocol
  cidr_blocks       = try(var.egress_rules[count.index].cidr_blocks, ["0.0.0.0/0"])
  security_group_id = aws_security_group.this.id
  description       = lookup(var.egress_rules[count.index], "description", null)
}
