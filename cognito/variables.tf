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

variable "project_prefix" {
  description = "Name prefix for resources."
}

variable "environment" {
  description = "Environment setting."
  default     = "dev"
}