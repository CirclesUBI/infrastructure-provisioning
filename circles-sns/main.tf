terraform {
  backend "s3" {
    bucket         = "circles-sns-terraform"
    region         = "eu-central-1"
    key            = "circles-sns-terraform.tfstate"
    dynamodb_table = "circles-sns-terraform"
    encrypt        = true
  }
}


# The default "aws" configuration is used for AWS resources in the root
# module where no explicit provider instance is selected.
provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.sns_aws_region}"
}

# A non-default, or "aliased" configuration is also defined for a different
# region.
provider "aws" {
  alias  = "service"
  region = "${var.service_region}"
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

resource "aws_sns_sms_preferences" "update_sms_prefs" {
  usage_report_s3_bucket = "${var.sms_log_bucket}"
  monthly_spend_limit  = "1000"
  delivery_status_iam_role_arn = "${var.delivery_status_iam_role_arn}"
  delivery_status_success_sampling_rate = "100"
  default_sender_id = "CirclesUBI"
  default_sms_type = "Transactional"
}

#
locals {
  availability_zones = ["${var.service_region}a"]  
}

variable "sns_public_cidrs" {
  default = ["10.0.4.0/26", "10.0.4.64/26"]
}

variable "sns_private_cidrs" {
  default = ["10.0.4.128/26", "10.0.4.192/26"]
}

module "networking" {  
  source               = "./modules/networking"
  providers            = {aws = "aws.service"}
  project_prefix       = "${var.project_prefix}"
  environment          = "${var.environment}"
  vpc_id               = "${var.circles_backend_vpc_id}"
  igw_id               = "${var.circles_backend_igw_id}" 
  public_subnets_cidr  = "${var.sns_public_cidrs}"
  private_subnets_cidr = "${var.sns_private_cidrs}"
  availability_zones   = "${local.availability_zones}"
  region               = "${var.service_region}"
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
        "${module.networking.instance_arn}",
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