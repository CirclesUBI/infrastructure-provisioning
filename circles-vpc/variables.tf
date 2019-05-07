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

# variable "availability_zones" {
#   description = "The AWS availability zones to create things in."
#   type        = "list"
#   default     = ["eu-central-1a", "eu-central-1b"]
# }

variable "project" {
  description = "Name of project."
  default     = "circles"
}

variable "project_prefix" {
  description = "Name prefix for resources."
  default     = "circles-vpc"
}

variable "environment" {
  description = "Environment setting."
  default     = "dev"
}

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "2"
}
