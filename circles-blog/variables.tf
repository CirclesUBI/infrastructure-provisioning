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

variable "circles_backend_vpc_id" {
  description = "The Circles backend VPC to create resources in."  
}

variable "circles_backend_igw_id" {
  description = "The Circles backend Internet Gatway shared by public subnets."  
}

variable "blog_s3_backup_bucket" {
  description = "s3 bucket name to backup to."  
}
