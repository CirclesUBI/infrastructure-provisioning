variable "access_key" {
  description = "AWS access key"
}

variable "secret_key" {
  description = "AWS secret access key"
}

variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "eu-central-1"
}

variable "circles_backend_vpc_id" {
  description = "The Circles backend VPC to create resources in."  
}

variable "circles_backend_igw_id" {
  description = "The Circles backend Internet Gateway shared by public subnets."  
}

variable "project_prefix" {
  description = "Name prefix for resources."
  default     = "circles-api"
}

variable "environment" {
  description = "Environment setting."
  default     = "dev"
}

variable "app_version" {
  description = "App Version."
  default     = "1.0.0"
}

variable "availability_zones" {
  default = ["eu-central-1a", "eu-central-1b"]
}

variable "public_subnets_cidr" {
  default = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "private_subnets_cidr" {
  default = ["10.1.10.1/24", "10.1.20.0/24"]
}

variable "cognito_pool_id" {
  description = "Cognito pool for circles users."
}

variable "circles_api_github_oauth_token" {
  description = "OAuth Token for the circles-api github repo. https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/"
}

variable "rds_instance_identifier" {
  description = "The identifier for the rds instance"
} 

variable "database_name" {
  description = "The name of the database"
}

variable "database_password" {
  description = "The password of the admin user of the database"
}

variable "database_user" {
  description = "The admin username of the database"
}

variable "database_host" {
  description = "Database host for the api"
}

variable "database_port" {
  description = "Database port for the api"
}

