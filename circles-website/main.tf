# -----------------------------------------------------------
# State and Providers
# -----------------------------------------------------------

terraform {
  backend "s3" {
    bucket         = "circles-website-terraform-state"
    region         = "eu-central-1"
    key            = "circles-website-terraform.tfstate"
    dynamodb_table = "circles-website-terraform"
    encrypt        = true
  }
}

provider "aws" {
  access_key          = "${var.access_key}"
  secret_key          = "${var.secret_key}"
  region              = "${var.aws_region}"
  allowed_account_ids = ["${var.aws_account_id}"]
}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "us-east-1"
  alias      = "us-east-1"
}

data "terraform_remote_state" "circles_vpc" {
  backend = "s3"

  config {
    bucket         = "circles-vpc-terraform-state"
    region         = "eu-central-1"
    key            = "circles-vpc-terraform.tfstate"
    dynamodb_table = "circles-vpc-terraform"
    encrypt        = true
  }
}

# -----------------------------------------------------------
# S3 Bucket
# -----------------------------------------------------------

resource "aws_s3_bucket" "circles_website" {
  bucket = "${var.website_domain}-content"
  acl    = "public-read"

  tags = "${merge(
    local.common_tags,
    map(
      "name", "${var.website_domain}-content"
    )
  )}"
}

locals {
  s3_origin_id = "S3-www.${var.website_domain}" // located in the console at: CloudFront Distributions > E12VI3U7WIL23J
}

# -----------------------------------------------------------
# Cloudfront
# -----------------------------------------------------------

resource "aws_cloudfront_distribution" "circles_website" {
  enabled         = true
  is_ipv6_enabled = true

  origin {
    domain_name = "${aws_s3_bucket.circles_website.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"
  }

  default_root_object = "index.html"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  default_cache_behavior {
    allowed_methods  = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 7200
    max_ttl                = 86400
  }

  viewer_certificate {
    acm_certificate_arn = "${aws_acm_certificate.circles_website.arn}"
    ssl_support_method  = "sni-only"
  }
}

# -----------------------------------------------------------
# SSL Certificates
# -----------------------------------------------------------

resource "aws_acm_certificate" "circles_website" {
  domain_name               = "${var.website_domain}"
  subject_alternative_names = ["www.${var.website_domain}"]
  validation_method         = "DNS"

  provider = "aws.us-east-1"

  lifecycle {
    create_before_destroy = true
  }

  tags = "${merge(
    local.common_tags,
    map(
      "name", "${var.website_domain}-acm-cert"
    )
  )}"
}

resource "aws_route53_record" "validation" {
  count = "${length(aws_acm_certificate.circles_website.subject_alternative_names) + 1}"

  name    = "${lookup(aws_acm_certificate.circles_website.domain_validation_options[count.index], "resource_record_name")}"
  type    = "${lookup(aws_acm_certificate.circles_website.domain_validation_options[count.index], "resource_record_type")}"
  zone_id = "${data.terraform_remote_state.circles_vpc.zone_id}"
  records = ["${lookup(aws_acm_certificate.circles_website.domain_validation_options[count.index], "resource_record_value")}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "circles_website" {
  provider                = "aws.us-east-1"
  certificate_arn         = "${aws_acm_certificate.circles_website.arn}"
  validation_record_fqdns = ["${aws_route53_record.validation.*.fqdn}"]
}

# -----------------------------------------------------------
# DNS Aliases
# -----------------------------------------------------------

resource "aws_route53_record" "apex-ipv4" {
  zone_id = "${data.terraform_remote_state.circles_vpc.zone_id}"
  name    = "${var.website_domain}"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.circles_website.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.circles_website.hosted_zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "apex-ipv6" {
  zone_id = "${data.terraform_remote_state.circles_vpc.zone_id}"
  name    = "${var.website_domain}"
  type    = "AAAA"

  alias {
    name                   = "${aws_cloudfront_distribution.circles_website.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.circles_website.hosted_zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www-ipv4" {
  zone_id = "${data.terraform_remote_state.circles_vpc.zone_id}"
  name    = "www.${var.website_domain}"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.circles_website.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.circles_website.hosted_zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www-ipv6" {
  zone_id = "${data.terraform_remote_state.circles_vpc.zone_id}"
  name    = "www.${var.website_domain}"
  type    = "AAAA"

  alias {
    name                   = "${aws_cloudfront_distribution.circles_website.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.circles_website.hosted_zone_id}"
    evaluate_target_health = true
  }
}
