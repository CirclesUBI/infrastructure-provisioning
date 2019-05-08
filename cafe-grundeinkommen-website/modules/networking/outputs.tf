output "public_subnet_id" {
  value = "${aws_subnet.public_subnet.id}"
}

output "default_sg_id" {
  value = "${aws_security_group.default.id}"
}

output "security_groups_ids" {
  value = ["${aws_security_group.default.id}"]
}