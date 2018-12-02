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
  name = "circles-mobile-test"
  email_verification_subject = "Your verification code"
  email_verification_message = "Your verification code is {####}. "
  sms_authentication_message = "Your authentication code is {####}. "  
  sms_verification_message = "Your verification code is {####}. "
  username_attributes = ["phone_number"]
  auto_verified_attributes = ["email"]
  mfa_configuration = "OPTIONAL"


  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  lambda_config {    
    post_confirmation = "arn:aws:lambda:eu-central-1:183869895864:function:confirmUser"    
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
    sns_caller_arn = "arn:aws:iam::183869895864:role/service-role/circlesmobiletest-SMS-Role"
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
      max_length = 2048
      min_length = 0
    }
  }

  schema {
    attribute_data_type = "String"
    developer_only_attribute = false
    mutable = true
    name = "name"
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
    name = "email"
    required = true
    string_attribute_constraints {
      max_length = 2048
      min_length = 0
    }
  }

  tags {
    
  }
}
