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

variable "blueprint_id" {
  description = "Blueprint for lightsail instance."  
}

variable "instance_size" {
  description = "Size of lightsail instance"  
}