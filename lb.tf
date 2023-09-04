resource "aws_lb" "asg_lab" {
  name               = var.naming_prefix
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.asg_lab_lb.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_listener" "asg_lab" {
  load_balancer_arn = aws_lb.asg_lab.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg_lab.arn
  }
}

resource "aws_lb_target_group" "asg_lab" {
  name     = var.naming_prefix
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

resource "aws_autoscaling_attachment" "asg_lab" {
  autoscaling_group_name = aws_autoscaling_group.asg_lab.id
  lb_target_group_arn    = aws_lb_target_group.asg_lab.arn
}