output "alb_dns_name" {
  value       = aws_lb.example.dns_name
  description = "The domain name of load balancer"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
