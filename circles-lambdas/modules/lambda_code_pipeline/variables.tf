variable "access_key" {
  description = "AWS access key"
}

variable "secret_key" {
  description = "AWS secret access key"
}

variable "region" {
  description = "The region to launch the bastion host"
}

variable "github_oauth_token" {
  description = "The OAuth token for the github repo to pull code from"
}

variable "project" {
  description = "Project name."
}

variable "project_prefix" {
  description = "Name prefix for resources."
}

variable "lambda_version" {
  description = "Lambda Version."
}

variable "environment" {
  description = "Environment setting."
}

variable "lambda_function_name" {
  description = "Name of the lambda function to be deployed"
}
