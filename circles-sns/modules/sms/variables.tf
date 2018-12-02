variable "delivery_status_iam_role_arn" {
  description = "IAM role ARN for access to the log bucket."
}

variable "sms_log_bucket" {
  default = "s3 bucket for sms usage logs."
}
