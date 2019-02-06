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

variable "project_prefix" {
  description = "Name prefix for resources."
  default     = "circles-fuel-server"
}

variable "environment" {
  description = "Environment setting."
  default     = "dev"
}

variable "availability_zones" {
  default = ["eu-central-1a", "eu-central-1b"]
}
