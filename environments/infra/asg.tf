module "web_asg" {
    source = "./modules/asg"

    name                  = "web-tier"
    ami_id                = data.aws_ami.amazon_linux_2.id
    instance_type         = var.instance_type
    iam_instance_profile  = module.iam.iam_instance_profile_name
    security_group_ids    = [module.web_sg.id]
    private_subnet_ids    = module.network.private_subnet_ids
    desired_capacity      = 2
    min_size              = 1
    max_size                  = 3
    user_data_path            = "${path.module}/scripts/install_apache.sh"
    health_check_grace_period = 300
    target_group_arn          = module.alb.target_group_arn
}
