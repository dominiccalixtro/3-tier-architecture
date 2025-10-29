module "alb" {
    source = "./modules/alb"

    vpc_id = module.network.vpc_id
    public_subnets_ids = module.network.public_subnets_ids
    alb_sg_id = module.alb_sg.id
}