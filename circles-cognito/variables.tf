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

variable "project" {
  description = "Project name."
  default     = "circles"
}

variable "environment" {
  description = "Environment setting."
  default     = "dev"
}

variable "password_policy_minimum_length" {
}

variable "password_policy_require_lowercase" {
}

variable "password_policy_require_symbols" {
}

variable "password_policy_require_uppercase" {
}

variable "password_policy_require_numbers" {
}

variable "sms_configuration_external_id" {
}
