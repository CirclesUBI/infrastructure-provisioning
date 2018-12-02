provider "aws" {} //initialise alias provider

resource "aws_sns_sms_preferences" "update_sms_prefs" {
  usage_report_s3_bucket = "${var.sms_log_bucket}"
  monthly_spend_limit  = "1000"
  delivery_status_iam_role_arn = "${var.delivery_status_iam_role_arn}"
  delivery_status_success_sampling_rate = "100"
  default_sender_id = "CirclesUBI"
  default_sms_type = "Transactional"
}