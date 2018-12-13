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
  description = "Project name."
  default     = "circles"
}

variable "project_prefix" {
  description = "Name prefix for resources."
  default     = "circles-lambdas"
}

variable "environment" {
  description = "Environment setting."
  default     = "dev"
}

variable "lambda_version" {
  description = "Lambda Version."
  default     = "1.0.0"
}

variable "circles_lambdas_oauth_token" {
  description = "The OAuth token for the github repo to pull code from"
}

variable "lambda_function_name" {
  description = "Name of the lambda function to be deployed"
}

variable "circles_api_db_password" {
  description = "Password for Circles API DB"
}

