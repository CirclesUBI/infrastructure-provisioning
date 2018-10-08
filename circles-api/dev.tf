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

# provider "aws" {
#   region  = "${var.region}"
#   #profile = "duduribeiro"
# }

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
  public_subnets_cidr  = ["10.0.3.0/24", "10.0.4.0/24"]
  private_subnets_cidr = ["10.0.30.0/24", "10.0.40.0/24"]
  region               = "${var.aws_region}"
  availability_zones   = "${local.dev_availability_zones}"
}

# module "rds" {
#   source            = "./modules/rds"
#   environment       = "dev"
#   allocated_storage = "20"
#   database_name     = "${var.dev_database_name}"
#   database_username = "${var.dev_database_username}"
#   database_password = "${var.dev_database_password}"
#   subnet_ids        = ["${module.networking.private_subnets_id}"]
#   vpc_id            = "${module.networking.vpc_id}"
#   instance_class    = "db.t2.micro"
# }

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
