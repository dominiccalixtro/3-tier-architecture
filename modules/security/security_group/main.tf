resource "aws_security_group" "this" {
  # checkov:skip=CKV2_AWS_5:Every group this module creates is attached by the caller - alb_sg to the load balancer, web_sg to the launch template, db_sg to the RDS instance. Checkov cannot follow the attachment across a module boundary and reports it as orphaned.
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

# Egress rules.
#
# There is deliberately no fallback to 0.0.0.0/0 here. A default that opens all
# outbound traffic means every caller that forgets to pass egress_rules silently
# gets an unrestricted egress path, which is the route a compromised host uses
# to reach a command-and-control endpoint or to move data out. Callers state
# their egress explicitly or the group has none.
resource "aws_security_group_rule" "egress" {
  count = length(var.egress_rules)

  type              = "egress"
  from_port         = var.egress_rules[count.index].from_port
  to_port           = var.egress_rules[count.index].to_port
  protocol          = var.egress_rules[count.index].protocol
  security_group_id = aws_security_group.this.id
  description       = lookup(var.egress_rules[count.index], "description", null)

  cidr_blocks              = try(var.egress_rules[count.index].cidr_blocks, null)
  source_security_group_id = try(var.egress_rules[count.index].security_group_id, null)
}
