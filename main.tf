provider "aws" {
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.0"

  name = "main-vpc"
  cidr = "10.0.0.0/16"

  azs                     = data.aws_availability_zones.available.names
  public_subnets          = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_dns_hostnames    = true
  enable_dns_support      = true
  map_public_ip_on_launch = true
}

resource "aws_key_pair" "asg_lab" {
  key_name   = "${var.naming_prefix}-pub_key"
  public_key = file("${var.ssh_pub_key_path}")
}

resource "aws_launch_configuration" "asg_lab" {
  name_prefix     = "${var.naming_prefix}-"
  image_id        = var.asg_image_id
  instance_type   = var.asg_instance_type
  key_name        = aws_key_pair.asg_lab.key_name
  user_data       = file("${path.module}/user_data/user_data.sh")
  security_groups = [aws_security_group.asg_lab_instance.id]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg_lab" {
  name                 = var.naming_prefix
  min_size             = 1
  max_size             = 3
  desired_capacity     = 2
  launch_configuration = aws_launch_configuration.asg_lab.name
  vpc_zone_identifier  = module.vpc.public_subnets
  health_check_type = "EC2"

  tag {
    key                 = "Name"
    value               = "testing-${var.naming_prefix}"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity, target_group_arns]
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.naming_prefix}_scale_up"
  autoscaling_group_name = aws_autoscaling_group.asg_lab.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 60
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.naming_prefix}_scale_down"
  autoscaling_group_name = aws_autoscaling_group.asg_lab.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 60
}

#resource "aws_cloudwatch_metric_alarm" "scale_up_cpu" {
#  alarm_description   = "Monitors CPU utilization for upscaling in ${var.naming_prefix}"
#  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
#  alarm_name          = "${var.naming_prefix}_scale_up_cpu"
#  comparison_operator = "GreaterThanOrEqualToThreshold"
#  namespace           = "AWS/EC2"
#  metric_name         = "CPUUtilization"
#  threshold           = 70
#  evaluation_periods  = 1
#  period              = 60
#  statistic           = "Average"
#
#  dimensions = {
#    AutoScalingGroupName = aws_autoscaling_group.asg_lab.name
#  }
#}

#resource "aws_cloudwatch_metric_alarm" "scale_down_cpu" {
#  alarm_description   = "Monitors CPU utilization for downscaling in ${var.naming_prefix}"
#  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
#  alarm_name          = "${var.naming_prefix}_scale_down_cpu"
#  comparison_operator = "LessThanOrEqualToThreshold"
#  namespace           = "AWS/EC2"
#  metric_name         = "CPUUtilization"
#  threshold           = 20
#  evaluation_periods  = 2
#  period              = 120
#  statistic           = "Average"
#
#  dimensions = {
#    AutoScalingGroupName = aws_autoscaling_group.asg_lab.name
#  }
#}

resource "aws_cloudwatch_metric_alarm" "scale_up_elb_requests" {
  alarm_name          = "${var.naming_prefix}_scale_up_LBreq"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 200
  alarm_description   = "Trigger scaling while exceed the threshhold of req/target"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    LoadBalancer = aws_lb.asg_lab.arn_suffix
    TargetGroup = aws_lb_target_group.asg_lab.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "scale_down_elb_requests" {
  alarm_name          = "${var.naming_prefix}_scale_down_LBreq"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 20
  alarm_description   = "Trigger scaling while less then req/target threshhold "
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    LoadBalancer = aws_lb.asg_lab.arn_suffix
    TargetGroup = aws_lb_target_group.asg_lab.arn_suffix
  }
}

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

resource "aws_security_group" "asg_lab_instance" {
  name = "${var.naming_prefix}-instance"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.asg_lab_lb.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allow_ssh_from_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group" "asg_lab_lb" {
  name = "${var.naming_prefix}-lb"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = module.vpc.vpc_id
}
