output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnets_ids" {
  value = aws_subnet.public_subnet[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private_subnet[*].id
}

output "database_subnet_ids" {
  value = aws_subnet.database_subnet[*].id
}

output "db_subnet_group_id" {
  value = aws_db_subnet_group.this.id
}