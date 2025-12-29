resource "aws_launch_template" "example" {
  name_prefix   = "${var.cluster_name}-"
  image_id      = var.ami
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    # db_address  = data.terraform_remote_state.db.outputs.address
    # db_port     = data.terraform_remote_state.db.outputs.port
    db_address  = "1.2.3.4" # mock
    db_port     = 3306      # mock
    server_port = var.server_port
    server_text = var.server_text
  }))

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  name = var.cluster_name
  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }

  vpc_zone_identifier = data.aws_subnets.default.ids
  max_size            = var.max_size
  min_size            = var.min_size

  target_group_arns = [
    aws_lb_target_group.asg.arn
  ]
  health_check_type = "ELB"

  tag {
    key                 = "Name"
    value               = var.cluster_name
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = {
      for key, value in var.custom_tags :
      key => upper(value)
      if key != "Name"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
}



resource "aws_security_group" "instance" {
  name = "${var.cluster_name}-instance"

  ingress {
    from_port        = var.server_port
    protocol         = "tcp"
    to_port          = var.server_port
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "Allow HTTP traffic on port 8080"
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }
}

resource "aws_lb" "example" {
  name               = "terraform-asg-example"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = local.http_port
  protocol          = "HTTP"

  # 404
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404:page not found"
      status_code  = 404
    }
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
  condition {
    path_pattern {
      values = ["*"]
    }
  }

}

resource "aws_lb_target_group" "asg" {
  name     = "terraform-asg-example"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_security_group" "alb" {
  name = "${var.cluster_name}-alb"
}

resource "aws_security_group_rule" "allow_http_from_internet_to_alb" {
  type              = "ingress"
  from_port         = local.http_port
  to_port           = local.http_port
  protocol          = local.tcp_protocol
  cidr_blocks       = local.all_ips
  security_group_id = aws_security_group.alb.id
  description       = "Allow inbound HTTP traffic on port 80 from the internet to the ALB"
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  from_port         = local.any_port
  to_port           = local.any_port
  protocol          = local.any_protocol
  cidr_blocks       = local.all_ips
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic from the ALB"
}

data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "us-east-2"
  }
}

locals {
  http_port    = 80
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}

resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
  count = var.enable_autoscaling ? 1 : 0

  scheduled_action_name  = "scale_out_during_business_hours"
  autoscaling_group_name = aws_autoscaling_group.example.name
  min_size               = 2
  max_size               = 2
  desired_capacity       = 2
  recurrence             = "0 9 * * 1-5" # At 09:00 on every day-of-week from Monday through Friday
}

resource "aws_autoscaling_schedule" "scale_in_after_business_hours" {
  count = var.enable_autoscaling ? 1 : 0

  scheduled_action_name  = "scale_in_after_business_hours"
  autoscaling_group_name = aws_autoscaling_group.example.name
  min_size               = 0
  max_size               = 0
  desired_capacity       = 0
  recurrence             = "0 17 * * 1-5" # At 17:00 on every day-of-week from Monday through Friday
}
