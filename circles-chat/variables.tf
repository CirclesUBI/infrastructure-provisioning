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
  description = "Name of project."
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

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "2"
}

variable "asg_min" {
  description = "Min numbers of servers in ASG"
  default     = "2"
}

variable "asg_max" {
  description = "Max numbers of servers in ASG"
  default     = "3"
}

variable "asg_desired" {
  description = "Desired numbers of servers in ASG"
  default     = "2"
}

variable "mongo_password" {
  description = "MongoDB password"
}

variable "mongo_oplog_password" {
  description = "MongoDB oplog user password"
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