output "load_balancer_DNS" {
  value = aws_lb.udagram-lb.dns_name
}