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

# resource "aws_key_pair" "key" {
#   key_name   = "dev_key"
#   public_key = "${file("dev_key.pub")}"
# }

module "networking" {
  source               = "./modules/networking"
  project_prefix       = "${var.project_prefix}"
  environment          = "${var.environment}"
  vpc_id               = "${var.circles_backend_vpc_id}"
  igw_id               = "${var.circles_backend_igw_id}"
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
  ecs_security_group      = "${module.ecs.security_group_id}"
  vpc_id                  = "${var.circles_backend_vpc_id}"
  instance_class          = "db.t2.micro"
  rds_instance_identifier = "${var.rds_instance_identifier}"
  availability_zones      = "${local.dev_availability_zones}"
}

module "ecs" {
  source              = "./modules/ecs"
  project_prefix      = "${var.project_prefix}"
  environment         = "${var.environment}"
  vpc_id              = "${var.circles_backend_vpc_id}"
  availability_zones  = "${local.dev_availability_zones}"
  # repository_name     = "${var.project_prefix}/${var.environment}"
  repository_name     = "${var.project_prefix}-ecr"  
  subnets_ids         = ["${module.networking.private_subnets_id}"]
  public_subnet_ids   = ["${module.networking.public_subnets_id}"]
  region              = "${var.aws_region}"
  security_groups_ids = [
    "${module.networking.security_groups_ids}"
  ]
  cognito_pool_id     = "${var.cognito_pool_id}"
}
