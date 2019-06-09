terraform {
  backend "s3" {
    bucket         = "cafe-grundeinkommen-website-terraform-state"
    region         = "eu-central-1"
    key            = "cafe-grundeinkommen-website-terraform.tfstate"
    dynamodb_table = "cafe-grundeinkommen-website-terraform"
    encrypt        = true
  }
}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.aws_region}"
}

resource "aws_lightsail_key_pair" "cafe" {
  name   = "cafe-grundeinkommen-website-key"
  public_key = "${file("ssh/cafe-grundeinkommen-website.pub")}"
}

resource "aws_lightsail_static_ip" "cafe" {
  name = "cafe-grundeinkommen-website-ip"
}

resource "aws_lightsail_static_ip_attachment" "cafe" {
  static_ip_name = "${aws_lightsail_static_ip.cafe.name}"
  instance_name  = "${aws_lightsail_instance.cafe.name}"
}

resource "aws_lightsail_instance" "cafe" {
  name              = "cafe-grundeinkommen-wordpress"
  availability_zone = "${var.aws_region}b"
  blueprint_id      = "${var.blueprint_id}"
  bundle_id         = "${var.instance_size}_2_0"
  key_pair_name     = "${aws_lightsail_key_pair.cafe.name}"
}
