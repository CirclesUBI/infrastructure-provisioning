output "subnet_id" {
  value = "${aws_subnet.rds.0.id}"
}

output "db_name" {
  value = "${aws_db_instance.default.name}"
}

output "db_port" {
  value = "${aws_db_instance.default.port}"
}

output "db_username" {
  value = "${aws_db_instance.default.username}"
}

output "db_host" {
  value = "${aws_db_instance.default.address}"
}

