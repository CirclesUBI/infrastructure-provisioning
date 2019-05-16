output "vpc_id" {
  value = "${aws_vpc.default.id}"
}

output "igw_id" {
  value = "${aws_internet_gateway.default.id}"
}

output "zone_id" {
  value = "${aws_route53_zone.joincircles.zone_id}"
}
