resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_subnet" {
  count = length(var.public_subnets_cidr)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets_cidr[count.index]
  availability_zone       = var.availability_zones[count.index % length(var.availability_zones)]
  map_public_ip_on_launch = true
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