output "gcm_platform_arn" {
  description = "The ARN of the SNS platform application."
  value = "${aws_sns_platform_application.gcm_application.arn}"
}

output "instance_ip" {
  value = "${aws_instance.sns.public_ip}"
}
