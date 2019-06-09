provider "aws" {} //initialise alias provider

locals {
  domains = ["${var.website_domain}", "www.${var.website_domain}"]
}

resource "aws_acm_certificate" "circles_website" {
  provider                  = "aws.us"
  domain_name               = "${var.website_domain}"
  subject_alternative_names = "${local.domains}"
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = "${merge(
    var.common_tags,
    map(
      "name", "${var.website_domain}-acm-cert"
    )
  )}"
}

resource "aws_route53_record" "cert_validation" {
  provider = "aws.us"
  count    = "${length(local.domains)}"
  name     = "${lookup(aws_acm_certificate.circles_website.domain_validation_options[count.index], "resource_record_name")}"
  type     = "${lookup(aws_acm_certificate.circles_website.domain_validation_options[count.index], "resource_record_type")}"
  zone_id  = "${var.hosted_zone_id}"
  records  = ["${lookup(aws_acm_certificate.circles_website.domain_validation_options[count.index], "resource_record_value")}"]
  ttl      = 60
}

resource "aws_acm_certificate_validation" "circles_website" {
  provider                = "aws.us"
  certificate_arn         = "${aws_acm_certificate.circles_website.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation.*.fqdn}"]
}
