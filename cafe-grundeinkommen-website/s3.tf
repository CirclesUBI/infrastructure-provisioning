terraform {
  backend "s3" {
    bucket         = "cafe-grundeinkommen-website-terraform-state"
    region         = "eu-central-1"
    key            = "cafe-grundeinkommen-website-terraform.tfstate"
    dynamodb_table = "cafe-grundeinkommen-website-terraform"
    encrypt        = true
  }
}

# AWS
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

# Additional provider configuration
provider "aws" {
  alias  = "us"
  region = "us-east-1"
}

module "acm" {
  source = "./modules/acm"

  providers = {
    aws = "aws.us"
  }

  common_tags    = "${local.common_tags}"
  website_domain = "${var.website_domain}"
  hosted_zone_id = "${aws_route53_zone.cafe_website.zone_id}"
}

locals {
  s3_origin_id = "S3-www.${var.website_domain}"
}

resource "aws_s3_bucket" "cafe_website" {
  bucket = "${var.website_domain}-content"
  acl    = "public-read"

  website {
    index_document = "index.html"
  }

  tags = "${merge(
    local.common_tags,
    map(
      "name", "${var.website_domain}-content"
    )
  )}"
}

resource "aws_s3_bucket_policy" "cafe_website" {
  bucket = "${aws_s3_bucket.cafe_website.id}"

  policy = <<POLICY
{
  "Version": "2008-10-17",
  "Statement": [{
    "Sid": "AllowPublicRead",
    "Effect": "Allow",
    "Principal": {
      "AWS": "*"
    },
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::${var.website_domain}-content/*"
  }]
}
POLICY
}

### Domains

resource "aws_route53_zone" "cafe_website" {
  name = "${var.website_domain}."

  // name_servers = ["ns-1021.awsdns-63.net", "ns-1494.awsdns-58.org", "ns-2003.awsdns-58.co.uk", "ns-41.awsdns-05.com"]
  // zone_id = "${data.terraform_remote_state.circles_vpc.zone_id}"

  tags = "${merge(
    local.common_tags,
    map(
      "name", "${var.website_domain}"
    )
  )}"
}

resource "aws_cloudfront_distribution" "my-website" {
  enabled         = true
  is_ipv6_enabled = true

  origin {
    domain_name = "${aws_s3_bucket.cafe_website.bucket_domain_name}"
    origin_id   = "${local.s3_origin_id}"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  default_cache_behavior {
    target_origin_id = "${local.s3_origin_id}"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

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
    cloudfront_default_certificate = true
  }

  tags = "${merge(
    local.common_tags,
    map(
      "name", "${var.project}-cloudfront-dist"
    )
  )}"
}

# resource "aws_cloudfront_distribution" "cafe_website" {
#   enabled         = true
#   is_ipv6_enabled = true

#   origin {
#     domain_name = "${aws_s3_bucket.cafe_website.bucket_domain_name}"
#     origin_id   = "${local.s3_origin_id}"
#   }

#   aliases             = ["www.${var.website_domain}"]
#   default_root_object = "index.html"

#   restrictions {
#     geo_restriction {
#       restriction_type = "none"
#     }
#   }

#   default_cache_behavior {
#     allowed_methods  = ["GET", "HEAD"]
#     cached_methods   = ["GET", "HEAD"]
#     target_origin_id = "${local.s3_origin_id}"

#     forwarded_values {
#       query_string = false

#       cookies {
#         forward = "none"
#       }
#     }

#     compress         = true
#     smooth_streaming = false

#     viewer_protocol_policy = "redirect-to-https"
#     min_ttl                = 31536000
#     default_ttl            = 31536000
#     max_ttl                = 31536000
#   }

#   viewer_certificate {
#     // cloudfront_default_certificate = true

#     acm_certificate_arn      = "${module.acm.cert_arn}"
#     minimum_protocol_version = "TLSv1.1_2016"
#     ssl_support_method       = "sni-only"
#   }

#   tags = "${merge(
#     local.common_tags,
#     map(
#       "name", "${var.project}-cloudfront-dist"
#     )
#   )}"
# }

resource "aws_route53_record" "cafe_website" {
  zone_id = "${aws_route53_zone.cafe_website.zone_id}"
  name    = "www.${var.website_domain}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_cloudfront_distribution.my-website.domain_name}"]
}
