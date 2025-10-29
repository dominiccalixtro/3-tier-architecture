module "network" {
    source = "./modules/network"

    vpc_cidr = var.vpc_cidr
    public_subnets_cidr = var.public_subnets_cidr
    private_subnets_cidr = var.private_subnets_cidr
    database_subnets_cidr = var.database_subnets_cidr
    availability_zones  =   local.availability_zones
}