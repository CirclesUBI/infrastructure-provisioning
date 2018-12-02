terraform {
  backend "s3" {
    bucket         = "circles-resources-terraform"
    region         = "eu-central-1"
    key            = "circles-cognito-terraform.tfstate"
    dynamodb_table = "circles-cognito-terraform"
    encrypt        = true
  }
}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

data "terraform_remote_state" "circles_lambdas" {
  backend = "s3"
  config {
    bucket         = "circles-lambdas-terraform"
    region         = "eu-central-1"
    key            = "circles-lambdas-terraform.tfstate"
    dynamodb_table = "circles-lambdas-terraform"
    encrypt        = true
  }
}


resource "aws_cognito_user_pool" "users" {
  name = "circles-mobile-userpool"
  email_verification_subject = "Your Circles verification code"
  email_verification_message = "Your Circles verification code is {####}. "
  sms_authentication_message = "Your Circles authentication code is {####}. "  
  sms_verification_message = "Your Circles verification code is {####}. "
  username_attributes = ["phone_number"]
  auto_verified_attributes = ["email"]
  mfa_configuration = "OPTIONAL"

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  lambda_config {    
    post_confirmation = "${data.terraform_remote_state.circles_lambdas.confirm_user_arn}"    
  } 

  password_policy {
    minimum_length = 8
    require_lowercase = false
    require_numbers = false
    require_symbols = false
    require_uppercase = false
  }

  sms_configuration {
    external_id = "887b8191-7280-481a-9b8b-e836cc619c87"
    sns_caller_arn = "${aws_iam_role.cidp_sms.arn}"
  }
  
  device_configuration {
    challenge_required_on_new_device = false
    device_only_remembered_on_user_prompt = false
  }

  schema {
    attribute_data_type = "String"
    developer_only_attribute = false
    mutable = true
    name = "picture"
    required = true
    string_attribute_constraints {
      max_length = 2048
      min_length = 0
    }
  }
  
  schema {
    attribute_data_type = "String"
    developer_only_attribute = false
    mutable = true
    name = "deviceId"
    required = false
    string_attribute_constraints {
      max_length = 256
      min_length = 1
    }
  }

  schema {
    attribute_data_type = "String"
    developer_only_attribute = false
    mutable = true
    name = "phone_number"
    required = true
    string_attribute_constraints {
      max_length = 64
      min_length = 8
    }
  }

  schema {
    attribute_data_type = "String"
    developer_only_attribute = false
    mutable = true
    name = "name"
    required = true
    string_attribute_constraints {
      max_length = 64
      min_length = 2
    }
  }

  schema {
    attribute_data_type = "String"
    developer_only_attribute = false
    mutable = true
    name = "email"
    required = true
    string_attribute_constraints {
      max_length = 256
      min_length = 6
    }
  }

  tags {    
    Environment = "${var.environment}"
    Name        = "circles-mobile-userpool"
    Project     = "${var.project}"    
  }
}

resource "aws_iam_role" "cidp_sms" {
  name = "circles-cognito-sms-role"
  path = "/service-role/"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "cognito-idp.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "cidp_sms" {
  name = "circles-cognito-sms-policy"
  role = "${aws_iam_role.cidp_sms.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sns:publish"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

resource "aws_cognito_user_pool_client" "circles_mobile" {  
  name = "circles-mobile"
  user_pool_id = "${aws_cognito_user_pool.users.id}"
  refresh_token_validity = 30

  read_attributes = [
    "given_name",                  
    "email_verified",
    "zoneinfo",
    "website",
    "preferred_username",
    "name",
    "locale",
    "phone_number",
    "family_name",
    "custom:deviceId",
    "birthdate",
    "middle_name",
    "phone_number_verified",
    "profile",
    "picture",
    "address",
    "gender",
    "updated_at",
    "nickname",
    "email"
  ]

  write_attributes = [
    "given_name",
    "zoneinfo",
    "website",
    "preferred_username",
    "name",
    "locale",
    "phone_number",
    "family_name",
    "custom:deviceId",
    "birthdate",
    "middle_name",
    "profile",
    "picture",
    "address",
    "gender",
    "updated_at",
    "nickname",
    "email"
  ]
}

resource "aws_cognito_user_group" "basic_users" {
  name         = "circles-basic-user-group"
  user_pool_id = "${aws_cognito_user_pool.users.id}"
  description  = "Regular user group"
  // precedence   = 10
  // role_arn     = "${aws_iam_role.group_role.arn}"
}