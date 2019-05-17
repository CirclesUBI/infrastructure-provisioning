locals {
  common_tags = {
    team              = "${var.team}"
    project           = "${var.project}"
    environment       = "${var.environment}"
    emergency_contact = "${var.emergency_contact}"
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
}

variable "aws_account_id" {
  description = "The AWS Account to use."
}

variable "team" {
  description = "Owner of resources."
  default     = "circles"
}

variable "project" {
  description = "Name of project."
  default     = "cafe-website"
}

variable "environment" {
  description = "Environment setting."
  default     = "dev"
}

variable "emergency_contact" {
  description = "Who to contact in an emergency."
}

variable "blueprint_id" {
  description = "Blueprint for lightsail instance."
}

variable "instance_size" {
  description = "Size of lightsail instance"
}

variable "website_domain" {
  description = "Domain of the website."
}
