module "ec2" {
    source = "./modules/ec2"
    
    ami_id = data.aws_ami.amazon_linux_2.id
    instance_type = var.instance_type
    role_name = module.iam.iam_instance_profile_name
    associate_public_ip_address = false 
}