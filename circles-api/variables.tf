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

variable "circles-backend-vpc-id" {
  description = "Default circles backend VPC Id"
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

variable "vpc_cidr" {  
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  default = ["eu-central-1a", "eu-central-1b"]
}

variable "public_subnets_cidr" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets_cidr" {
  default = ["10.0.10.0/24", "10.0.20.0/24"]
}
