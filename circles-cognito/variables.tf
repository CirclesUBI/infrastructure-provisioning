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
  description = "The AWS region to create the resources in."
}

variable "aws_account_id" {
  description = "The AWS account ID."
}

variable "team" {
  description = "Owner of resources."
  default     = "circles"
}

variable "project" {
  description = "Project name."
  default     = "circles-cognito"
}

variable "emergency_contact" {
  description = "Who to call if there is an emergency."
}

variable "environment" {
  description = "Environment setting."
  default     = "dev"
}

variable "password_policy_minimum_length" {}

variable "password_policy_require_lowercase" {}

variable "password_policy_require_symbols" {}

variable "password_policy_require_uppercase" {}

variable "password_policy_require_numbers" {}

variable "sms_configuration_external_id" {}
