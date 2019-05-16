terraform {
  backend "s3" {
    bucket         = "circles-sns-terraform-state"
    region         = "eu-central-1"
    key            = "circles-sns-terraform.tfstate"
    dynamodb_table = "circles-sns-terraform"
    encrypt        = true
  }
}

provider "aws" {
  access_key          = "${var.access_key}"
  secret_key          = "${var.secret_key}"
  region              = "${var.aws_region}"
  allowed_account_ids = ["${var.aws_account_id}"]
}

# Additional provider configuration SMS (not available in Frankfurt)
provider "aws" {
  alias  = "ireland"
  region = "eu-west-1"
}

resource "aws_sns_platform_application" "gcm_application" {
  name                = "${var.project}-gcm-app"
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
  source = "./modules/sms"

  providers = {
    aws = "aws.ireland"
  }

  delivery_status_iam_role_arn = "${aws_iam_role.sns_sms_feedback.arn}"
  sms_log_bucket               = "circles-sns-sms-daily-usage"
}

# notifs
resource "aws_sns_topic" "transfer" {
  name = "${var.project}-transfer-topic"
}

resource "aws_sns_topic_policy" "transfer" {
  arn = "${aws_sns_topic.transfer.arn}"

  policy = "${data.aws_iam_policy_document.sns_transfer.json}"
}

data "aws_iam_policy_document" "sns_transfer" {
  policy_id = "${var.project}-sns-transfer"

  statement {
    actions = [
      "SNS:Publish",
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"

      values = [
        "*",
      ]
    }

    effect = "Allow"

    principals {
      type = "AWS"

      identifiers = [
        "*",
      ]
    }

    resources = [
      "${aws_sns_topic.transfer.arn}",
    ]

    sid = "${var.project}-transfer"
  }
}

# SQS Stuff

# resource "aws_sqs_queue" "transfer" {
#   name = "${var.project}-q-transfer"

#   tags {
#     Environment = "${var.environment}"
#     Name        = "${var.project}-logs"
#     Project     = "${var.project}"
#   }
# }

# resource "aws_sqs_queue_policy" "transfer" {
#   queue_url = "${aws_sqs_queue.transfer.id}"
#   policy = "${data.aws_iam_policy_document.sqs_transfer.json}"
# }

# data "aws_iam_policy_document" "sqs_transfer" {
#   policy_id = "${var.project}-sqs-transfer"
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
#     sid = "${var.project}-sqs-transfer"
#   }
# }

# resource "aws_sns_topic_subscription" "sqs_transfer" {
#   topic_arn = "${aws_sns_topic.transfer.arn}"
#   protocol  = "sqs"
#   endpoint  = "${aws_sqs_queue.transfer.arn}"
# }

resource "aws_iam_role" "sns_sms_feedback" {
  name = "${var.project}-sms-feedback"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action":"sts:AssumeRole"
    }
  ]  
}
POLICY
}

resource "aws_iam_role_policy" "sns_sms_feedback" {
  name = "${var.project}-sms-policy"
  role = "${aws_iam_role.sns_sms_feedback.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:PutMetricFilter",
        "logs:PutRetentionPolicy"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}
