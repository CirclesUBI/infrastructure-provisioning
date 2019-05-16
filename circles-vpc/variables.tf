locals {
  common_tags = {
    team              = "${var.team}"
    project           = "${var.project}"
    environment       = "${var.environment}"
    emergency_contact = "${var.emergency_contact}"
  }
}

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


variable "team" {
  description = "Owner of resources."
  default     = "circles"
}

variable "project" {
  description = "Name of project."
  default     = "circles-vpc"
}

variable "environment" {
  description = "Environment setting."
  default     = "dev"
}

variable "emergency_contact" {
  description = "Who to contact in an emergency."
}

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "2"
}
