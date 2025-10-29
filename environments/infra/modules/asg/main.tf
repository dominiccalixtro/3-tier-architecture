resource "aws_launch_template" "this" {
    name_prefix   = "${var.name}-lt"
    image_id      = var.ami_id
    instance_type = var.instance_type
    
    iam_instance_profile {
        name = var.iam_instance_profile
    }
    
    network_interfaces {
        security_groups = var.security_group_ids
    }
    user_data = var.user_data_path
}

resource "aws_autoscaling_group" "this" {
    name                      = "fterraform-test"
    max_size                  = var.max_size
    min_size                  = var.min_size
    health_check_grace_period = var.health_check_grace_period
    health_check_type         = "ELB"
    desired_capacity          = var.desired_capacity
    force_delete              = true
    target_group_arns          = [var.target_group_arn]
    launch_template {
        id      = aws_launch_template.this.id
        version = "$Latest"
    }
    vpc_zone_identifier       = [var.private_subnet_ids[0], var.private_subnet_ids[1]]

    tag {
        key                 = "foo"
        value               = "bar"
        propagate_at_launch = true
    }
}