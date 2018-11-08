output "load_balancer" {
  value = "${aws_alb.rocketchat.dns_name}"
}