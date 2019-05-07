output "load_balancer" {
  value = "${aws_alb.chat.dns_name}"
}