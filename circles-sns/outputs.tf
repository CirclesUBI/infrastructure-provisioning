output "gcm_platform_arn" {
  description = "The ARN of the SNS platform application."
  value = "${aws_sns_platform_application.gcm_application.arn}"
}
