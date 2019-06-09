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

resource "aws_s3_bucket" "sms_logs" {
  bucket = "circles-sns-sms-logs"
  acl    = "private"

  tags = "${merge(
    local.common_tags,
    map(
      "name", "sns-sms-delivery-logs"
    )
  )}"
}

module "sms" {
  source = "./modules/sms"

  providers = {
    aws = "aws.ireland"
  }

  delivery_status_iam_role_arn = "${aws_iam_role.sns_sms_feedback.arn}"
  sms_log_bucket               = "${aws_s3_bucket.sms_logs.id}"
}

# notifications
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

### IAM

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
