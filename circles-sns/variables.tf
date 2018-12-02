variable "access_key" {
  description = "AWS access key"
}

variable "secret_key" {
  description = "AWS secret access key"
}

variable "region" {
  description = "The AWS region to create the resources in."  
  default     = "eu-central-1"
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