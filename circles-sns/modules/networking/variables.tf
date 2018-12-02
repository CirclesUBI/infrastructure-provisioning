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
  description = "Project name."
  default     = "circles"
}

variable "project_prefix" {
  description = "Name prefix for resources."
}

variable "environment" {
  description = "Environment setting."
}

variable "availability_zones" {
  type        = "list"
  description = "The az that the resources will be launched"
}

