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

  password_policy {
    minimum_length = "${var.password_policy_minimum_length}"
    require_lowercase = "${var.password_policy_require_lowercase}"
    require_numbers = "${var.password_policy_require_numbers}"
    require_symbols = "${var.password_policy_require_symbols}"
    require_uppercase = "${var.password_policy_require_uppercase}"
  }

  sms_configuration {
    external_id = "${var.sms_configuration_external_id}" 
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
    name = "device_id"
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
    name = "agreedToDisclaimer"
    required = false
    string_attribute_constraints {
      max_length = 5
      min_length = 4
    }
  }

    schema {
    attribute_data_type = "String"
    developer_only_attribute = false
    mutable = true
    name = "agreed_to_disclaimer"
    required = false
    string_attribute_constraints {
      max_length = 5
      min_length = 4
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

resource "aws_cognito_user_pool_client" "circles-mobile" {
  name                                 = "circles-mobile"
  refresh_token_validity  = 30
  user_pool_id = "${aws_cognito_user_pool.users.id}"

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
    "email",
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

resource "aws_cognito_user_pool_client" "circles-api" {
  name                    = "circles-api"
  explicit_auth_flows     = ["ADMIN_NO_SRP_AUTH"]
  refresh_token_validity  = 30
  user_pool_id = "${aws_cognito_user_pool.users.id}"

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
    "custom:agreedToDisclaimer",
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
    "custom:agreedToDisclaimer",
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

resource "aws_cognito_user_group" "user" {
  name         = "user"
  description  = "A default user of circles"
  precedence   = 0
  # role_arn     =
  user_pool_id = "${aws_cognito_user_pool.users.id}"
}

resource "aws_cognito_user_group" "test" {
  name         = "test"
  description  = "test user for integration and development"  
  precedence   = 1
  # role_arn     =
  user_pool_id = "${aws_cognito_user_pool.users.id}"
}