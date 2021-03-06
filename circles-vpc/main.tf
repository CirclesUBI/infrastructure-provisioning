### Authenticate

provider "aws" {
  access_key          = "${var.access_key}"
  secret_key          = "${var.secret_key}"
  region              = "${var.aws_region}"
  allowed_account_ids = ["${var.aws_account_id}"]
}

### State

terraform {
  backend "s3" {
    bucket         = "circles-vpc-terraform-state"
    region         = "eu-central-1"
    key            = "circles-vpc-terraform.tfstate"
    dynamodb_table = "circles-vpc-terraform"
    encrypt        = true
  }
}

### Domains

resource "aws_route53_zone" "joincircles" {
  name = "joincircles.net"

  lifecycle = {
    prevent_destroy = true
  }

  tags = "${merge(
    local.common_tags,
    map(
      "name", "joincircles.net"
    )
  )}"
}

resource "aws_route53_record" "gsuite-mx" {
  zone_id = "${aws_route53_zone.joincircles.zone_id}"
  name    = "${aws_route53_zone.joincircles.name}"
  type    = "MX"
  ttl     = 3600

  records = [
    "1 ASPMX.L.GOOGLE.COM",
    "5 ALT1.ASPMX.L.GOOGLE.COM",
    "5 ALT2.ASPMX.L.GOOGLE.COM",
    "10 ASPMX2.GOOGLEMAIL.COM",
    "10 ASPMX3.GOOGLEMAIL.COM",
  ]
}

resource "aws_route53_record" "gsuite-spf" {
  zone_id = "${aws_route53_zone.joincircles.zone_id}"
  name    = "${aws_route53_zone.joincircles.name}"
  type    = "TXT"
  ttl     = 3600

  records = [
    "v=spf1 include:_spf.google.com ~all",
    "v=DMARC1; p=none; rua=mailto:admin@joincircles.net",
  ]
}

### VPC

data "aws_availability_zones" "default" {}

resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"

  # IPv4 CIDR IP/CIDR	  Δ to last IP addr	  Mask	            Hosts(*)	Class
  # a.b.0.0/16	        +0.0.255.255	      255.255.000.000	  65,536	  256 C = 1 B

  enable_dns_hostnames = true
  tags = "${merge(
    local.common_tags,
    map(
      "name", "${var.project}"
    )
  )}"
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"

  tags = "${merge(
    local.common_tags,
    map(
      "name", "${var.project}-internet-gateway"
    )
  )}"
}

# Logging

resource "aws_flow_log" "circles_vpc_flow_log" {
  iam_role_arn    = "${aws_iam_role.circles_vpc_role.arn}"
  log_destination = "${aws_cloudwatch_log_group.circles_vpc.arn}"
  traffic_type    = "ALL"
  vpc_id          = "${aws_vpc.default.id}"
}

resource "aws_cloudwatch_log_group" "circles_vpc" {
  name              = "${var.project}"
  retention_in_days = "30"

  tags = "${merge(
    local.common_tags,
    map(
      "name", "${var.project}-logs"
    )
  )}"
}

resource "aws_iam_role" "circles_vpc_role" {
  name = "${var.project}-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "circles_vpc_logging_policy" {
  name = "${var.project}-policy"
  role = "${aws_iam_role.circles_vpc_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}
