variable "access_key" {
  description = "AWS access key"
}

variable "secret_key" {
  description = "AWS secret access key"
}

variable "aws_region" {
  description = "The AWS region to create the resources in."
}

variable "aws_account_id" {
  description = "AWS Account ID."
  default     = "circles"
}

variable "project" {
  description = "Project name."
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

