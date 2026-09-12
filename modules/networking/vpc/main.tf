resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# AWS creates a default security group per VPC with an allow-all egress rule and
# it cannot be deleted. Adopting it with no rules leaves it deny-all, so any
# resource launched without an explicit group gets no connectivity rather than
# unrestricted outbound.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "default-deny-all"
  }
}

# ------------------------------------------------------------- flow logs ----

resource "aws_cloudwatch_log_group" "flow_logs" {
  # checkov:skip=CKV_AWS_158:Flow log records carry connection metadata, not payload, and are encrypted at rest with an AWS-owned key. A customer-managed key adds cost and key-policy surface without changing what is exposed.
  # checkov:skip=CKV_AWS_338:Retention is a cost decision exposed as a variable rather than a compliance target. Raise flow_log_retention_days where a retention obligation applies.
  name              = "/aws/vpc/${var.name_prefix}/flow-logs"
  retention_in_days = var.flow_log_retention_days
}

data "aws_iam_policy_document" "flow_logs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "flow_logs_write" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow_logs.arn}:*"]
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "${var.name_prefix}-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role.json
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "${var.name_prefix}-flow-logs-write"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs_write.json
}

resource "aws_flow_log" "this" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
}

resource "aws_subnet" "public_subnet" {
  count = length(var.public_subnets_cidr)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnets_cidr[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]

  # Only the NAT gateways and the ALB live in these subnets, and both get their
  # addressing from their own resources. A subnet that hands out public IPs by
  # default means anything launched here later is internet-facing by accident.
  map_public_ip_on_launch = false
}

resource "aws_subnet" "private_subnet" {
  count = length(var.private_subnets_cidr)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnets_cidr[count.index]
  availability_zone       = var.availability_zones[count.index % length(var.availability_zones)]
  map_public_ip_on_launch = false
}

resource "aws_subnet" "database_subnet" {
  count = length(var.database_subnets_cidr)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.database_subnets_cidr[count.index]
  availability_zone       = var.availability_zones[count.index % length(var.availability_zones)]
  map_public_ip_on_launch = false
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_eip" "nat" {
  count = var.nat_gateway_count

  domain = "vpc"

  tags = {
    Name = "${var.vpc_cidr}-nat-eip-${count.index}"
  }
}

resource "aws_nat_gateway" "this" {
  count = var.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public_subnet[count.index % length(aws_subnet.public_subnet)].id

  tags = {
    Name = "${var.vpc_cidr}-nat-gw-${count.index}"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}

resource "aws_route_table" "private_rt" {
  count = var.nat_gateway_count

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }
}

resource "aws_route_table" "database_rt" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route_table_association" "public_rt_association" {
  count = length(aws_subnet.public_subnet)

  route_table_id = aws_route_table.public_rt.id
  subnet_id      = aws_subnet.public_subnet[count.index].id
}

resource "aws_route_table_association" "private_rt_association" {
  count = length(aws_subnet.private_subnet)

  route_table_id = aws_route_table.private_rt[count.index % var.nat_gateway_count].id
  subnet_id      = aws_subnet.private_subnet[count.index].id
}

resource "aws_route_table_association" "database_rt_association" {
  count = length(aws_subnet.database_subnet)

  route_table_id = aws_route_table.database_rt.id
  subnet_id      = aws_subnet.database_subnet[count.index].id
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.vpc_cidr}-db-subnet-group"
  subnet_ids = aws_subnet.database_subnet[*].id

  tags = {
    Name = "${var.vpc_cidr}-db-subnet-group"
  }
}