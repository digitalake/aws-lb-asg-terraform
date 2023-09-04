output "asg_name" {
  value = aws_autoscaling_group.asg_lab.name
}

output "lb_endpoint" {
  value = "http://${aws_lb.asg_lab.dns_name}"
}

output "application_info_endpoint" {
  value = "http://${aws_lb.asg_lab.dns_name}/info"
}