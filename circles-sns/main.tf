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


// todo: wont work in this region. but maybe move this to a module? would be nice to have it explicitly set
# resource "aws_sns_sms_preferences" "update_sms_prefs" {
#   usage_report_s3_bucket = "${var.sms_log_bucket}"
#   monthly_spend_limit  = "1000"
#   delivery_status_iam_role_arn = "${var.delivery_status_iam_role_arn}"
#   delivery_status_success_sampling_rate = "100"
#   default_sender_id = "CirclesUBI"
#   default_sms_type = "Transactional"
# }


locals {
  availability_zones = ["${var.region}a"]  
}

variable "sns_public_cidrs" {
  default = ["10.0.4.0/26", "10.0.4.64/26"]
}

variable "sns_private_cidrs" {
  default = ["10.0.4.128/26", "10.0.4.192/26"]
}

module "networking" {  
  source               = "./modules/networking"
  project_prefix       = "${var.project_prefix}"
  environment          = "${var.environment}"
  vpc_id               = "${var.circles_backend_vpc_id}"
  igw_id               = "${var.circles_backend_igw_id}" 
  public_subnets_cidr  = "${var.sns_public_cidrs}"
  private_subnets_cidr = "${var.sns_private_cidrs}"
  availability_zones   = "${local.availability_zones}"
}

data "aws_ami" "amazon-linux-2" {
 most_recent = true

 filter {
   name   = "owner-alias"
   values = ["amazon"]
 }

 filter {
   name   = "name"
   values = ["amzn2-ami-hvm*"]
 }
}

resource "aws_instance" "sns" {
  ami           = "${data.aws_ami.amazon-linux-2.id}"
  instance_type   = "t2.micro"
  user_data       = "${data.template_file.sns_cloud_config.rendered}"
  security_groups = ["${aws_security_group.circles_sns_sg.id}"]
  iam_instance_profile          = "${aws_iam_instance_profile.circles_sns.id}"
  associate_public_ip_address = true
  key_name = "${aws_key_pair.circles_sns.key_name}"
  subnet_id = "${module.networking.public_subnets_id[0]}"

  tags {
    Environment = "${var.environment}"
    Name        = "${var.project_prefix}-service"
    Project     = "${var.project}"
  }
}

data "template_file" "sns_cloud_config" {
  template = "${file("sns_cloud-config.yml")}"
  vars {
    sns_android_platform_arn       = "${aws_sns_platform_application.gcm_application.arn}"
    access_key   = "${var.access_key}"
    secret_key   = "${var.secret_key}"
  }
}

resource "aws_key_pair" "circles_sns" {
  key_name   = "sns-key"
  public_key = "${file("ssh/insecure-deployer.pub")}"
}

resource "aws_security_group" "circles_sns_sg" {
  name    = "${var.project_prefix}-sg"
  vpc_id  = "${var.circles_backend_vpc_id}"
  
  ingress {
    from_port = 80
    to_port = 3000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "sns" {
  name              = "${var.project_prefix}-logs"
  retention_in_days = "60"

  tags {
    Name        = "${var.project_prefix}-logs"
    Environment = "${var.environment}"
  }
}

## IAM

resource "aws_iam_instance_profile" "circles_sns" {
  name = "${var.project_prefix}-instance-profile"
  role = "${aws_iam_role.instance.name}"
}

resource "aws_iam_role" "instance" {
  name = "${var.project_prefix}-instance-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

data "template_file" "instance_profile" {
  template = "${file("${path.module}/instance-profile-policy.json")}"

  vars {
    app_log_group_arn = "${aws_cloudwatch_log_group.sns.arn}"
    region            = "${var.region}"    
  }
}

resource "aws_iam_role_policy" "instance" {
  name   = "${var.project_prefix}-instance-policy"
  role   = "${aws_iam_role.instance.name}"
  policy = "${data.template_file.instance_profile.rendered}"
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
        "${aws_instance.sns.arn}",
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