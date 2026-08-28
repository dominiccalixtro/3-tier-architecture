output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

output "alb_arn" {
  value = aws_lb.app_alb.arn
}

output "alb_dns_name" {
  value = aws_lb.app_alb.dns_name
}