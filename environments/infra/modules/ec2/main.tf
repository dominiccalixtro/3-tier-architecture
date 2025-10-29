resource "aws_instance" "this" {
    ami = var.ami_id
    instance_type = var.instance_type
    iam_instance_profile = var.role_name
    associate_public_ip_address = var.associate_public_ip_address
    user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
              EOF
}