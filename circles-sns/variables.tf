variable "access_key" {
  description = "AWS access key"
}

variable "secret_key" {
  description = "AWS secret access key"
}

variable "sns_aws_region" {
  description = "The AWS region to create SNS resources in."  
}

variable "service_region" {
  description = "The AWS region to create the service instances in."  
}

variable "project" {
  description = "Project name."
  default     = "circles"
}

variable "project_prefix" {
  description = "Name prefix for resources."
  default     = "circles-sns"
}

variable "environment" {
  description = "Environment setting."
  default     = "dev"
}

variable "gcm_key" {
  description = "Google Cloud Mesaging key."
}

# variable "apns_key" {
#   description = "Apple Push Notification Service key."
# }

# variable "apns_cert" {
#   description = "Apple Push Notification Service certificate."
# }

variable "delivery_status_iam_role_arn" {
  description = "IAM role ARN for access to the log bucket."
}

variable "sms_log_bucket" {
  default = "s3 bucket for sms usage logs."
}

variable "circles_backend_vpc_id" {
  description = "The Circles backend VPC to create resources in."  
}

variable "circles_backend_igw_id" {
  description = "The Circles backend Internet Gateway shared by public subnets."  
}
