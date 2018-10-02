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
  production_availability_zones = ["eu-central-1a", "eu-central-1b"]
}

# provider "aws" {
#   region  = "${var.region}"
#   #profile = "duduribeiro"
# }

resource "aws_key_pair" "key" {
  key_name   = "production_key"
  public_key = "${file("production_key.pub")}"
}

module "networking" {
  source               = "./modules/networking"
  environment          = "production"
  vpc_cidr             = "10.0.0.0/16"
  public_subnets_cidr  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets_cidr = ["10.0.10.0/24", "10.0.20.0/24"]
  region               = "${var.region}"
  availability_zones   = "${local.production_availability_zones}"
  key_name             = "production_key"
}

# module "rds" {
#   source            = "./modules/rds"
#   environment       = "production"
#   allocated_storage = "20"
#   database_name     = "${var.production_database_name}"
#   database_username = "${var.production_database_username}"
#   database_password = "${var.production_database_password}"
#   subnet_ids        = ["${module.networking.private_subnets_id}"]
#   vpc_id            = "${module.networking.vpc_id}"
#   instance_class    = "db.t2.micro"
# }

# module "ecs" {
#   source              = "./modules/ecs"
#   environment         = "production"
#   vpc_id              = "${module.networking.vpc_id}"
#   availability_zones  = "${local.production_availability_zones}"
#   repository_name     = "openjobs/production"
#   subnets_ids         = ["${module.networking.private_subnets_id}"]
#   public_subnet_ids   = ["${module.networking.public_subnets_id}"]
#   security_groups_ids = [
#     "${module.networking.security_groups_ids}",
#     "${module.rds.db_access_sg_id}"
#   ]
#   database_endpoint   = "${module.rds.rds_address}"
#   database_name       = "${var.production_database_name}"
#   database_username   = "${var.production_database_username}"
#   database_password   = "${var.production_database_password}"
#   secret_key_base     = "${var.production_secret_key_base}"
# }
