variable "common_tags" {
  description = "Common tags."
  type        = "map"
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

variable "vpc_id" {
  description = "The VPC id"
}

variable "igw_id" {
  description = "The Internet Gateway id"
}

variable "environment" {
  description = "Environment setting"
}

variable "allocated_storage" {
  description = "The amount of storage in GB"
}

variable "instance_class" {
  description = "The type of instance to use"
}

variable "security_group_ids" {
  type        = "list"
  description = "The security groups to allow RDS access"
}

variable "availability_zones" {
  type        = "list"
  description = "The az that the resources will be launched"
}

variable "cidr_blocks" {
  type        = "list"
  description = "The CIDRs for the rds subnet"
}

variable "project" {
  description = "Name of the project."
  default     = "circles"
}
