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

variable "project" {
  description = "Project of resources."
  default     = "circles"
}

variable "environment" {
  description = "Environment setting."
  default     = "dev"
}

variable "emergency_contact" {
  description = "Who to contact in an emergency."
}

variable "aws_account_id" {
  description = "The AWS account ID."
}


variable "availability_zones" {
  default = ["eu-central-1a", "eu-central-1b"]
}

variable "circles_api_github_oauth_token" {
  description = "OAuth Token for the circles-api github repo. https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/"
}