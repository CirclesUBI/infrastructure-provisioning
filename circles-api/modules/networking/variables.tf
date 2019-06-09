variable "common_tags" {
  description = "Common tags."
  type        = "map"
}

variable "vpc_id" {
  description = "The id of the vpc"
}

variable "igw_id" {
  description = "The id of the internet gateway."
}

variable "public_subnets_cidr" {
  type        = "list"
  description = "The CIDR block for the public subnet"
}

variable "private_subnets_cidr" {
  type        = "list"
  description = "The CIDR block for the private subnet"
}

variable "project" {
  description = "Name prefix for resources."
}

variable "environment" {
  description = "Environment setting."
}

variable "region" {
  description = "The region to launch the bastion host"
}

variable "availability_zones" {
  type        = "list"
  description = "The az that the resources will be launched"
}
