// Metadata

variable "name" {
  description = "Name for the service in the aws console"
}

variable "project_prefix" {
  description = "Name prefix for resources."
}

variable "environment" {
  description = "Environment setting."
  default     = "dev"
}

variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "eu-central-1"
}

// Provisioning

variable "cloud_config" {
  description = "cloud-config file to be applied on instance launch"
  default     = ""
}

// IAM

variable "instance_profile_name" {
  description = "Which IAM instance profile should the instance use"
}

// Networking

variable "vpc_id" {
  description = "In which vpc should the instance be created"
}

variable "subnet_id" {
  description = "In which subnet should the instance be created"
}

variable "security_groups" {
  description = "Security groups"
  type        = "list"
}

variable "key_name" {
  description = "Deploy key"
}

variable "aws_access_key" {
  description = "For S3 access"
}

variable "aws_secret_key" {
  description = "For S3 access"
}

variable "mongo_port" {
  description = "MongoDB port"
}
