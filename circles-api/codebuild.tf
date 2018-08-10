resource "aws_s3_bucket" "api" {
  bucket = "circles-api"
  acl    = "private"
  region = "eu-central-1"

  tags {
    Name        = "${var.project_prefix}-api-bucket"
    Environment = "${var.environment}"
  }
}

resource "aws_iam_role" "codebuild_role" {
  name = "circles-codebuild-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
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
        "${aws_s3_bucket.api.arn}",
        "${aws_s3_bucket.api.arn}/*"
      ]
    }
  ]
}
POLICY
}

resource "aws_codebuild_project" "api" {
  name          = "circles-api-project"
  description   = "Codebuild for Circles API"
  build_timeout = "5"
  service_role  = "${aws_iam_role.codebuild_role.arn}"

  artifacts {
    type      = "S3"
    location  = "${aws_s3_bucket.api.bucket}"
    name      = "circles-api.zip"
    packaging = "ZIP"
    path      = "${var.environment}/api/${var.app_version}"
  }

  # cache {
  #   type     = "S3"
  #   location = "${aws_s3_bucket.api.bucket}"
  # }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/nodejs:6.3.1"
    type         = "LINUX_CONTAINER"
  }
  source {
    type            = "GITHUB"
    location        = "https://github.com/CirclesUBI/circles-api/tree/codebuild"
    git_clone_depth = 3
  }
  tags {
    Name        = "${var.project_prefix}-api-project"
    Environment = "${var.environment}"
  }
}

resource "aws_codebuild_webhook" "api" {
  project_name = "${aws_codebuild_project.api.name}"
}
