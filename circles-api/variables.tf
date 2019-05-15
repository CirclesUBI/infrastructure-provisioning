locals {
  common_tags = {
    team              = "circles"
    project           = "circles-api"
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

variable "aws_region" {
  description = "The AWS region to create things in."
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
  description = "Name prefix for resources."
  default     = "circles-api"
}

variable "environment" {
  description = "Environment setting."
  default     = "dev"
}

variable "emergency_contact" {
  description = "Who to call if there is an emergency."
  default     = "circles-api"
}

variable "app_version" {
  description = "App Version."
  default     = "1.0.0"
}

variable "availability_zones" {
  default = ["eu-central-1a", "eu-central-1b"]
}

variable "circles_api_github_oauth_token" {
  description = "OAuth Token for the circles-api github repo. https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/"
}

variable "rds_instance_identifier" {
  description = "The identifier for the rds instance"
} 

variable "database_name" {
  description = "The name of the database"
}

variable "database_password" {
  description = "The password of the admin user of the database"
}

variable "database_user" {
  description = "The admin username of the database"
}

variable "private_key" {
  description = "The user's private key"
}

variable "cognito_pool_jwt_kid" {
  description = "Cognito pool jwt KID"
}

variable "cognito_pool_jwt_n" {
  description = "Cognito pool jwt N"
}

variable "cognito_test_username" {
  description = "Admin cognito username for API Tests"
}

variable "cognito_test_password" {
  description = "Admin cognito user password for API Tests"
}

variable "blockchain_network_id" {
  description = "Port number of blockchain network interface"
}