terraform {
  backend "s3" {
    bucket         = "circles-sns-terraform"
    region         = "eu-central-1"
    key            = "circles-sns-terraform.tfstate"
    dynamodb_table = "circles-sns-terraform"
    encrypt        = true
  }
}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

# Additional provider configuration SMS (not available in Frankfurt)
provider "aws" {
  alias  = "ireland"
  region = "eu-west-1"
}

resource "aws_sns_platform_application" "gcm_application" {
  name                = "${var.project_prefix}-gcm-app"
  platform            = "GCM"
  platform_credential = "${var.gcm_key}"
}

# resource "aws_sns_platform_application" "apns_application" {
#   name                = "apns_application"
#   platform            = "APNS"
#   platform_credential = "${var.apns_key}"
#   platform_principal  = "${var.apns_cert}"
# }

module "sms" {
  source                        = "./modules/sms"
  providers                     = {aws = "aws.ireland"}
  delivery_status_iam_role_arn  = "${var.delivery_status_iam_role_arn}"
  sms_log_bucket                = "${var.sms_log_bucket}"
}

# notifs
resource "aws_sns_topic" "transfer" {
  name = "${var.project_prefix}-transfer-topic"
}

resource "aws_sns_topic_policy" "transfer" {
  arn = "${aws_sns_topic.transfer.arn}"

  policy = "${data.aws_iam_policy_document.sns_transfer.json}"
}

data "aws_iam_policy_document" "sns_transfer" {
  policy_id = "${var.project_prefix}-sns-transfer"
  statement {
    actions = [
      "SNS:Publish",
    ]
    condition {
      test = "ArnLike"
      variable = "aws:SourceArn"

      values = [
        "*",
      ]
    }
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        "*"]
    }
    resources = [
      "${aws_sns_topic.transfer.arn}",
    ]
    sid = "${var.project_prefix}-transfer"
  }
}

# SQS Stuff

# resource "aws_sqs_queue" "transfer" {
#   name = "${var.project_prefix}-q-transfer"

#   tags {
#     Environment = "${var.environment}"
#     Name        = "${var.project_prefix}-logs"
#     Project     = "${var.project}"
#   }
# }

# resource "aws_sqs_queue_policy" "transfer" {
#   queue_url = "${aws_sqs_queue.transfer.id}"
#   policy = "${data.aws_iam_policy_document.sqs_transfer.json}"
# }

# data "aws_iam_policy_document" "sqs_transfer" {
#   policy_id = "${var.project_prefix}-sqs-transfer"
#   statement {
#     actions = [
#       "sqs:SendMessage",
#     ]
#     condition {
#       test = "ArnEquals"
#       variable = "aws:SourceArn"

#       values = [
#         "${aws_sns_topic.transfer.arn}",
#       ]
#     }
#     effect = "Allow"
#     principals {
#       type = "AWS"
#       identifiers = [
#         "*"]
#     }
#     resources = [
#       "${aws_sqs_queue.transfer.arn}",
#     ]
#     sid = "${var.project_prefix}-sqs-transfer"
#   }
# }

# resource "aws_sns_topic_subscription" "sqs_transfer" {
#   topic_arn = "${aws_sns_topic.transfer.arn}"
#   protocol  = "sqs"
#   endpoint  = "${aws_sqs_queue.transfer.arn}"
# }