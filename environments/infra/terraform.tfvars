region = "ap-southeast-1"
s3_backend = ""

project = "3_Tier_Architecture"
environment = "Development"

vpc_cidr = "10.0.0.0/16"
public_subnets_cidr = ["10.0.0.0/24","10.0.1.0/24"]
private_subnets_cidr = ["10.0.2.0/24","10.0.3.0/24"]
database_subnets_cidr = ["10.0.4.0/24","10.0.5.0/24"]

role_name = "ssm-acess-role"
instance_type = "t3.micro"