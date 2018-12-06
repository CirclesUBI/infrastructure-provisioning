variable "vpc_id" {
  description = "The VPC id"
}

variable "project_prefix" {
  description = "Name prefix for resources."
}

variable "environment" {
  description = "Environment setting."
}

variable "region" {
  description = "The region to launch the bastion host"
}

variable "availability_zones" {
  type        = "list"
  description = "The azs to use"
}

variable "security_groups_ids" {
  type        = "list"
  description = "The SGs to use"
}

variable "subnets_ids" {
  type        = "list"
  description = "The private subnets to use"
}

variable "public_subnet_ids" {
  type        = "list"
  description = "The private subnets to use"
}

variable "repository_name" {
  description = "The name of the repisitory"
}

variable "cognito_pool_id" {
  description = "Cognito pool for circles users."
}

variable "database_name" {
  description = "Database name for the api"
}

variable "database_password" {
  description = "Database password for the api"
}

variable "database_user" {
  description = "Database user for the api"
}

variable "database_host" {
  description = "Database host for the api"
}

variable "database_port" {
  description = "Database port for the api"
}
