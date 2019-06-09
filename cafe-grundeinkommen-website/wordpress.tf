# terraform {
#   backend "s3" {
#     bucket         = "cafe-grundeinkommen-website-terraform-state"
#     region         = "eu-central-1"
#     key            = "cafe-grundeinkommen-website-terraform.tfstate"
#     dynamodb_table = "cafe-grundeinkommen-website-terraform"
#     encrypt        = true
#   }
# }
# # AWS
# provider "aws" {
#   access_key          = "${var.access_key}"
#   secret_key          = "${var.secret_key}"
#   region              = "${var.aws_region}"
#   allowed_account_ids = ["${var.aws_account_id}"]
# }
# data "terraform_remote_state" "circles_vpc" {
#   backend = "s3"
#   config {
#     bucket         = "circles-vpc-terraform-state"
#     region         = "eu-central-1"
#     key            = "circles-vpc-terraform.tfstate"
#     dynamodb_table = "circles-vpc-terraform"
#     encrypt        = true
#   }
# }
# resource "aws_lightsail_key_pair" "cafe_website" {
#   name       = "${var.project}-key"
#   public_key = "${file("ssh/cafe-grundeinkommen-website.pub")}"
# }
# resource "aws_lightsail_static_ip" "cafe_website" {
#   name = "${var.project}-ip"
# }
# resource "aws_lightsail_static_ip_attachment" "cafe_website" {
#   static_ip_name = "${aws_lightsail_static_ip.cafe.name}"
#   instance_name  = "${aws_lightsail_instance.cafe.name}"
# }
# resource "aws_lightsail_instance" "cafe_website" {
#   name              = "${var.project}-instance"
#   availability_zone = "${var.aws_region}b"
#   blueprint_id      = "${var.blueprint_id}"
#   bundle_id         = "${var.instance_size}_2_0"
#   key_pair_name     = "${aws_lightsail_key_pair.cafe.name}"
# }
# resource "aws_route53_record" "cafe_website" {
#   zone_id = "${data.terraform_remote_state.circles_vpc.zone_id}"
#   name    = "www.${var.website_domain}"
#   type    = "CNAME"
#   ttl     = "300"
#   records = ["${var.website_domain}"]
# }
# resource "aws_route53_record" "cafe_website" {
#   zone_id = "${data.terraform_remote_state.circles_vpc.zone_id}"
#   name    = "${var.website_domain}"
#   type    = "CNAME"
#   ttl     = "300"
#   records = ["${aws_lightsail_static_ip.cafe_website.ip_adress}"]
# }

