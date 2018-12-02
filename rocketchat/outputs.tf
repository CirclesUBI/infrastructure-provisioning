output "load_balancer" {
  value = "${aws_alb.rocketchat.dns_name}"
}

output "vpc_id" {
  value = "${aws_vpc.default.id}"
}

output "igw_id" {
  value = "${aws_internet_gateway.default.id}"
}