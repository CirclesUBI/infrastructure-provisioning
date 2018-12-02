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
  default     = "circles-blog"
}

variable "environment" {
  description = "Environment setting."
  default     = "dev"
}

variable "smtp_host" {
  description = "SMTP host"
}

variable "smtp_username" {
  description = "SMTP username"
}

variable "smtp_password" {
  description = "SMTP password"
}

variable "cloud_config" {
  description = "cloud-config file to be applied on instance launch"
  default     = ""
}