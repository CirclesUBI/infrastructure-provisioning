output "load_balancer" {
  value = "${aws_alb.rocketchat.dns_name}"
}

# output "db_ip" {
#   value = "${module.rocketchat_mongodb.private_ip}"
# }


# output "db_pubip" {
#   value = "${module.rocketchat_mongodb.public_ip}"
# }

