terraform {
  backend "s3" {
    bucket         = "circles-api-terraform"
    region         = "eu-central-1"
    key            = "circles-api-terraform.tfstate"
    dynamodb_table = "circles-api-terraform"
    encrypt        = true
  }
}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.aws_region}"
}

data "terraform_remote_state" "circles_backend" {
  backend = "s3"
  config {
    bucket         = "circles-rocketchat-terraform"
    region         = "eu-central-1"
    key            = "circles-rocketchat-terraform.tfstate"
    dynamodb_table = "circles-rocketchat-terraform"
    encrypt        = true
  }
}

data "terraform_remote_state" "cognito" {
  backend = "s3"
  config {
    bucket         = "circles-resources-terraform"
    region         = "eu-central-1"
    key            = "circles-cognito-terraform.tfstate"
    dynamodb_table = "circles-cognito-terraform"
    encrypt        = true
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
  project_prefix       = "${var.project_prefix}"
  environment          = "${var.environment}"
  vpc_id               = "${data.terraform_remote_state.circles_backend.vpc_id}"
  igw_id               = "${data.terraform_remote_state.circles_backend.igw_id}"
  public_subnets_cidr  = "${var.api_public_cidrs}"
  private_subnets_cidr = "${var.api_private_cidrs}"
  region               = "${var.aws_region}"
  availability_zones   = "${local.dev_availability_zones}"
}

module "rds" {
  source                  = "./modules/rds"
  environment             = "dev"
  allocated_storage       = "20"
  database_name           = "${var.database_name}"
  database_user           = "${var.database_user}"
  database_password       = "${var.database_password}"
  security_group_ids      = ["${module.ecs.security_group_id}"]
  vpc_id                  = "${data.terraform_remote_state.circles_backend.vpc_id}"
  instance_class          = "db.t2.micro"
  rds_instance_identifier = "${var.rds_instance_identifier}"
  availability_zones      = "${local.dev_availability_zones}"
  cidr_blocks             = "${var.rds_private_cidrs}"
}

module "ecs" {
  source              = "./modules/ecs"
  project_prefix      = "${var.project_prefix}"
  environment         = "${var.environment}"
  vpc_id              = "${data.terraform_remote_state.circles_backend.vpc_id}"
  availability_zones  = "${local.dev_availability_zones}"
  repository_name     = "${var.project_prefix}-ecr"  
  subnets_ids         = ["${module.networking.private_subnets_id}"]
  public_subnet_ids   = ["${module.networking.public_subnets_id}"]
  region              = "${var.aws_region}"
  security_groups_ids = ["${module.networking.security_groups_ids}"]
  cognito_pool_id     = "${data.terraform_remote_state.cognito.cognito_userpool_id}"
  database_name       = "${var.database_name}"
  database_user       = "${var.database_user}"
  database_host       = "${var.database_host}"
  database_password   = "${var.database_password}"
  database_port       = "${var.database_port}"
}
