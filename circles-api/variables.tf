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
  description = "The Circles backend Internet Gatway shared by public subnets."  
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