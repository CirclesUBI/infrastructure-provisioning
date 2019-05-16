locals {
  common_tags = {
    team              = "circles"
    project           = "circles-chat"
    environment       = "dev"
    emergency_contact = "Ed: +4917643698891"
  }
}

variable "access_key" {
  description = "AWS access key"
}

variable "secret_key" {
  description = "AWS secret access key"
}

variable "region" {
  description = "The AWS region to create the resources in."
  default     = "eu-central-1"
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
  default     = "circles"
}

variable "emergency_contact" {
  description = "Who to call if there is an emergency."
  default     = "circles-api"
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
