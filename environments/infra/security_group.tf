module "alb_sg" {
    source = "./modules/security_group"
    name        = "alb-sg"
    description = "Security group for ALB"
    vpc_id      = module.network.vpc_id

    ingress_rules = [
        { 
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow HTTP"
        }
    ]
}

module "web_sg" {
  source      = "./modules/security_group"
  name        = "web-sg"
  description = "Security group for web servers"
  vpc_id      = module.network.vpc_id

  ingress_rules = [
    {
      from_port          = 80
      to_port            = 80
      protocol           = "tcp"
      security_group_id  = module.alb_sg.id  
      description        = "Allow HTTP from ALB"
    }
  ]
}

module "db_sg" {
    source = "./modules/security_group"
    name        = "database-sg"
    description = "Allow MySQL access from private subnets"
    vpc_id      = module.network.vpc_id

    ingress_rules = [
        {
        from_port   = 3306
        to_port     = 3306
        protocol    = "tcp"
        security_group_id  = module.web_sg.id 
        description = "Allow MySQL"
        }
    ]
}

