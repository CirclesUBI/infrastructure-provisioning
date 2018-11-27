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

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  // source_arn = "${aws_api_gateway_deployment.circles_api.execution_arn}/*/*"
  source_arn = "arn:aws:cognito-idp:eu-central-1:183869895864:userpool/*"
}

# ROLES

# IAM role which dictates what other AWS services can invoke the lambda
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_example_lambda"

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

