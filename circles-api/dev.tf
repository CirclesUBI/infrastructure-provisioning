terraform {
  backend "s3" {
    bucket         = "circles-api-terraform-state"
    region         = "eu-central-1"
    key            = "circles-api-terraform.tfstate"
    dynamodb_table = "circles-api-terraform"
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

data "terraform_remote_state" "circles_cognito" {
  backend = "s3"

  config {
    bucket         = "circles-cognito-terraform-state"
    region         = "eu-central-1"
    key            = "circles-cognito-terraform.tfstate"
    dynamodb_table = "circles-cognito-terraform"
    encrypt        = true
  }
}

data "terraform_remote_state" "circles_sns" {
  backend = "s3"

  config {
    bucket         = "circles-sns-terraform-state"
    region         = "eu-central-1"
    key            = "circles-sns-terraform.tfstate"
    dynamodb_table = "circles-sns-terraform"
    encrypt        = true
  }
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "api.joincircles.net."
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation_dns_record" {
  name    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.terraform_remote_state.circles_vpc.zone_id}"
  records = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation_dns_record.fqdn}"]
}

resource "aws_route53_record" "ipv4" {
  zone_id = "${data.terraform_remote_state.circles_vpc.zone_id}"
  name    = "${var.domain_name}"
  type    = "A"

  alias {
    name                   = "${module.ecs.alb_dns_name}"
    zone_id                = "${module.ecs.alb_zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "ipv6" {
  zone_id = "${data.terraform_remote_state.circles_vpc.zone_id}"
  name    = "${var.domain_name}"
  type    = "AAAA"

  alias {
    name                   = "${module.ecs.alb_dns_name}"
    zone_id                = "${module.ecs.alb_zone_id}"
    evaluate_target_health = true
  }
}

/*====
Variables used across all modules
======*/
locals {
  dev_availability_zones = ["${var.aws_region}a", "${var.aws_region}b"]
}

variable "api_public_cidrs" {
  default = ["10.0.2.0/26", "10.0.2.64/26"]
}

variable "api_private_cidrs" {
  default = ["10.0.2.128/26", "10.0.2.192/26"]
}

variable "rds_public_cidrs" {
  default = ["10.0.3.0/26", "10.0.3.64/26"]
}

variable "rds_private_cidrs" {
  default = ["10.0.3.128/26", "10.0.3.192/26"]
}

module "networking" {
  source               = "./modules/networking"
  project              = "${var.project}"
  environment          = "${var.environment}"
  vpc_id               = "${data.terraform_remote_state.circles_vpc.vpc_id}"
  igw_id               = "${data.terraform_remote_state.circles_vpc.igw_id}"
  public_subnets_cidr  = "${var.api_public_cidrs}"
  private_subnets_cidr = "${var.api_private_cidrs}"
  region               = "${var.aws_region}"
  availability_zones   = "${local.dev_availability_zones}"
  common_tags          = "${local.common_tags}"
}

module "rds" {
  source                  = "./modules/rds"
  environment             = "dev"
  allocated_storage       = "20"
  database_name           = "${var.database_name}"
  database_user           = "${var.database_user}"
  database_password       = "${var.database_password}"
  security_group_ids      = ["${module.ecs.security_group_id}"]
  igw_id                  = "${data.terraform_remote_state.circles_vpc.igw_id}"
  vpc_id                  = "${data.terraform_remote_state.circles_vpc.vpc_id}"
  instance_class          = "db.t2.micro"
  rds_instance_identifier = "${var.rds_instance_identifier}"
  availability_zones      = "${local.dev_availability_zones}"
  cidr_blocks             = "${var.rds_public_cidrs}"
  project                 = "circles"
  project                 = "${var.project}"
  common_tags             = "${local.common_tags}"
}

module "ecs" {
  source                   = "./modules/ecs"
  project                  = "${var.project}"
  environment              = "${var.environment}"
  vpc_id                   = "${data.terraform_remote_state.circles_vpc.vpc_id}"
  availability_zones       = "${local.dev_availability_zones}"
  repository_name          = "${var.project}-ecr"
  subnets_ids              = ["${module.networking.private_subnets_id}"]
  public_subnet_ids        = ["${module.networking.public_subnets_id}"]
  region                   = "${var.aws_region}"
  security_groups_ids      = ["${module.networking.security_groups_ids}"]
  cognito_pool_id          = "${data.terraform_remote_state.circles_cognito.cognito_userpool_id}"
  database_name            = "${module.rds.db_name}"
  database_user            = "${module.rds.db_username}"
  database_host            = "${module.rds.db_host}"
  database_port            = "${module.rds.db_port}"
  database_password        = "${var.database_password}"
  android_platform_gcm_arn = "${data.terraform_remote_state.circles_sns.gcm_platform_arn}"
  cognito_pool_jwt_kid     = "${var.cognito_pool_jwt_kid}"
  cognito_pool_jwt_n       = "${var.cognito_pool_jwt_n}"
  private_key              = "${var.private_key}"
  ssl_certificate_arn      = "${aws_acm_certificate.cert.arn}"
  blockchain_network_id    = "${var.blockchain_network_id}"
  common_tags              = "${local.common_tags}"
}
