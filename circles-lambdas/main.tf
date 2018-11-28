terraform {
  backend "s3" {
    bucket         = "circles-lambdas-terraform"
    region         = "eu-central-1"
    key            = "circles-lambdas-terraform.tfstate"
    dynamodb_table = "circles-lambdas-terraform"
    encrypt        = true
  }
}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.aws_region}"
}

module "code_pipeline" {
  source                      = "./modules/lambda_code_pipeline"
  region                      = "${var.aws_region}"
  project                     = "${var.project}"  
  project_prefix              = "${var.project_prefix}"  
  environment                 = "${var.environment}"  
  github_oauth_token          = "${var.circles_lambdas_oauth_token}"
  lambda_version              = "${var.lambda_version}"
  lambda_function_name        = "${var.lambda_function_name}"
  access_key                  = "${var.access_key}"
  secret_key                  = "${var.secret_key}"
}

resource "aws_lambda_function" "this" {
  function_name   = "${var.lambda_function_name}"
  filename        = "index.zip"
  handler         = "index.handler"
  runtime         = "nodejs8.10"
  role            = "${aws_iam_role.lambda_exec.arn}"
}

resource "aws_lambda_permission" "cognito" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.this.arn}"
  principal     = "cognito-idp.amazonaws.com"
  source_arn = "arn:aws:cognito-idp:eu-central-1:183869895864:userpool/*"
}

# ROLES

# IAM role which dictates what other AWS services can invoke the lambda
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_prefix}-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
    
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_policies" {
  name        = "${var.project_prefix}-policy"
  description = "Lambda policies for cognito access"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "allowAddingUserToGroup",
      "Action": [
        "cognito-idp:AdminAddUserToGroup" 
      ],
      "Effect": "Allow",
      "Resource": "${var.aws_cognito_pool_arn}"
    },
    {
        "Sid": "allowCreateLogGroup",
        "Effect": "Allow",
        "Action": "logs:CreateLogGroup",
        "Resource": "arn:aws:logs:eu-central-1:183869895864"
    },
    {
      "Sid": "allowLoggingToCloudWatch",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:eu-central-1:183869895864:log-group:/aws/lambda/*",
        "arn:aws:logs:eu-central-1:183869895864:log-group:*:*:*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = "${aws_iam_role.lambda_exec.name}"
  policy_arn = "${aws_iam_policy.lambda_policies.arn}"
}
