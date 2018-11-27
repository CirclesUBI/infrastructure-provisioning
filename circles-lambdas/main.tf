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

# Bucket for storing build artifacts
resource "aws_s3_bucket" "lambdas" {
  bucket = "circles-lambdas"
  acl    = "private"
  region = "eu-central-1"

  tags {
    Environment = "${var.environment}"
    Project     = "${var.project}"
    Name        = "${var.project_prefix}-bucket"    
  }
}

resource "aws_codebuild_project" "lambdas" {
  name          = "${var.project_prefix}-project"
  description   = "Codebuild for Circles Lambdas"
  build_timeout = "5"
  service_role  = "${aws_iam_role.codebuild_role.arn}"

  artifacts {
    type      = "S3"
    location  = "${aws_s3_bucket.lambdas.bucket}"
    name      = "${var.project_prefix}.zip"
    packaging = "ZIP"
    path      = "${var.environment}/lambdas/${var.app_version}"
  }

  # cache {
  #   type     = "S3"
  #   location = "${aws_s3_bucket.lambdas.bucket}"
  # }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/nodejs:6.3.1"
    type         = "LINUX_CONTAINER"
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/CirclesUBI/${var.project_prefix}"
    git_clone_depth = 3
  }

  tags {
    Environment = "${var.environment}"
    Project     = "${var.project}"
    Name        = "${var.project_prefix}-lambdas-project"    
  }
}

resource "aws_codebuild_webhook" "lambdas" {
  project_name = "${aws_codebuild_project.lambdas.name}"
}


resource "aws_lambda_function" "example" {
  function_name = "ServerlessExample"

  s3_bucket = "${aws_s3_bucket.lambdas.bucket}"                               
  //s3_key    = "${var.environment}/lambdas/${var.app_version}/${var.project_prefix}.zip"
  s3_key    = "main.zip"

  # "main" is the filename within the zip file (main.js) and "handler"
  # is the name of the property under which the handler function was
  # exported in that file.
  handler = "main.handler"

  runtime = "nodejs6.10"

  role = "${aws_iam_role.lambda_exec.arn}"
}


# ROLES

resource "aws_iam_role" "codebuild_role" {
  name = "circles-codebuild-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com",
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild_policy" {
  role = "${aws_iam_role.codebuild_role.name}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.lambdas.arn}",
        "${aws_s3_bucket.lambdas.arn}/*"
      ]
    }
  ]
}
POLICY
}

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

resource "aws_lambda_permission" "cognito" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.example.arn}"
  principal     = "cognito-idp.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  // source_arn = "${aws_api_gateway_deployment.circles_api.execution_arn}/*/*"
  source_arn = "arn:aws:cognito-idp:eu-central-1:183869895864:userpool/eu-central-1_MxUAJ1OEg"
}
