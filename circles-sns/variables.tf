### AWS
variable "access_key" {
  description = "AWS access key"
}

variable "secret_key" {
  description = "AWS secret access key"
}

variable "aws_account_id" {
  description = "AWS Account ID."
}

variable "aws_region" {
  description = "The AWS region to create the resources in."
}

### GCM

variable "gcm_key" {
  description = "Google Cloud Mesaging key."
}

### Common Tags

locals {
  common_tags = {
    team              = "${var.team}"
    project           = "${var.project}"
    environment       = "${var.environment}"
    emergency_contact = "${var.emergency_contact}"
  }
}

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
