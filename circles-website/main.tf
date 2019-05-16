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

resource "aws_s3_bucket" "circles_website" {
  bucket = "${var.website_domain}"
  acl    = "private"

  # website {
  #   index_document = "${var.bucket_index_document}"
  #   error_document = "${var.bucket_error_document}"
  # }

  tags = "${merge(
    local.common_tags,
    map(
      "name", "${var.website_domain}"
    )
  )}"
}

locals {
  s3_origin_id = "S3-www.${var.website_domain}" // located in the console at: CloudFront Distributions > E12VI3U7WIL23J
}

resource "aws_cloudfront_distribution" "circles_website" {
  enabled         = true
  is_ipv6_enabled = true

  origin {
    domain_name = "${aws_s3_bucket.circles_website.bucket_domain_name}"
    origin_id   = "${local.s3_origin_id}"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "POST"]
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
    acm_certificate_arn = "${data.aws_acm_certificate.circles_website.arn}"
  }
}

# DNS / SSL

resource "aws_acm_certificate" "circles_website" {
  domain_name               = "${var.website_domain}"
  subject_alternative_names = ["${var.website_domain}", "www.${var.website_domain}"]
  validation_method         = "DNS"

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

resource "aws_route53_record" "circles_website" {
  name    = "${aws_acm_certificate.circles_website.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.circles_website.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.terraform_remote_state.circles_vpc.zone_id}"
  records = ["${aws_acm_certificate.circles_website.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "circles_website" {
  certificate_arn         = "${aws_acm_certificate.circles_website.arn}"
  validation_record_fqdns = ["${aws_route53_record.circles_website.fqdn}"]
}

resource "aws_route53_record" "circles_website" {
  zone_id = "${data.terraform_remote_state.circles_vpc.zone_id}"
  name    = "${var.website_domain}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_cloudfront_distribution.circles_website.domain_name}"]
}
