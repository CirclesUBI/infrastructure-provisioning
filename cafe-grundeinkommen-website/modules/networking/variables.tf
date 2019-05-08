variable "vpc_id" {
  description = "The id of the vpc"
}

variable "igw_id" {
  description = "The id of the internet gateway."
}

variable "public_subnet_cidr" {
  description = "The CIDR block for the public subnet"
}

variable "project_prefix" {
  description = "Name prefix for resources."
}

variable "environment" {
  description = "Environment setting."
}

variable "region" {
  description = "The region to launch the bastion host"
}

variable "availability_zone" {
  description = "The az that the resources will be launched"
}
