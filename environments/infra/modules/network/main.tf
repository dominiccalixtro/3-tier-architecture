resource "aws_vpc" "this" {
    cidr_block = var.vpc_cidr
    enable_dns_support   = true      
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

resource "aws_eip" "this" {
    
}

resource "aws_nat_gateway" "this" {
    allocation_id = aws_eip.this.id
    subnet_id     = aws_subnet.public_subnet[0].id
}

resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.this.id
    route {
        gateway_id = aws_internet_gateway.this.id
        cidr_block = "0.0.0.0/0"
    }
}

resource "aws_route_table" "private_rt" {
    vpc_id = aws_vpc.this.id
    route {
        gateway_id = aws_nat_gateway.this.id
        cidr_block = "0.0.0.0/0"
    }
}

resource "aws_route_table_association" "public_rt_association" {
    count = length(aws_subnet.public_subnet) > 0 ? length(aws_subnet.public_subnet) : 0

    route_table_id = aws_route_table.public_rt.id
    subnet_id      = aws_subnet.public_subnet[count.index].id
}

resource "aws_route_table_association" "private_rt_association" {
    count = length(aws_subnet.private_subnet) > 0 ? length(aws_subnet.private_subnet) : 0

    route_table_id = aws_route_table.private_rt.id
    subnet_id      = aws_subnet.private_subnet[count.index].id
}

resource "aws_route_table_association" "database_rt_association" {
    count = length(aws_subnet.database_subnet) > 0 ? length(aws_subnet.database_subnet) : 0

    route_table_id = aws_route_table.private_rt.id
    subnet_id      = aws_subnet.database_subnet[count.index].id
}
