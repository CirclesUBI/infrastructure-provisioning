resource "aws_s3_bucket" "this" {
  bucket        = "${var.project_prefix}"
  acl           = "private"
  force_destroy = true

  tags {
    Environment = "${var.environment}"
    Project     = "${var.project}"
    Name        = "${var.project_prefix}-bucket"    
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "${var.project_prefix}-codepipeline-role"
  assume_role_policy = "${file("${path.module}/policies/codepipeline_role.json")}"
}

/* policies */
data "template_file" "codepipeline_policy" {
  template = "${file("${path.module}/policies/codepipeline.json")}"

  vars {
    aws_s3_bucket_arn = "${aws_s3_bucket.this.arn}"
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name   = "${var.project_prefix}-codepipeline-policy"
  role   = "${aws_iam_role.codepipeline_role.id}"
  policy = "${data.template_file.codepipeline_policy.rendered}"
}

/*
/* CodeBuild
*/
resource "aws_iam_role" "codebuild_role" {
  name               = "${var.project_prefix}-codebuild-role"
  assume_role_policy = "${file("${path.module}/policies/codebuild_role.json")}"
}

data "template_file" "codebuild_policy" {
  template = "${file("${path.module}/policies/codebuild_policy.json")}"

  vars {
    aws_s3_bucket_arn = "${aws_s3_bucket.this.arn}"
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name        = "${var.project_prefix}-codebuild-policy"
  role        = "${aws_iam_role.codebuild_role.id}"
  policy      = "${data.template_file.codebuild_policy.rendered}"
}

data "template_file" "buildspec_build" {
  template = "${file("${path.module}/buildspec_build.yml")}"

  vars {
    lambda_function_name        = "${var.lambda_function_name}"
  }
}

data "template_file" "buildspec_deploy" {
  template = "${file("${path.module}/buildspec_deploy.yml")}"

  vars {
    lambda_function_name        = "${var.lambda_function_name}"

    # lambda_version                 = "${var.lambda_version}"
    # https://docs.aws.amazon.com/lambda/latest/dg/versioning-aliases.html
  }
}

resource "aws_codebuild_project" "build" {
  name          = "${var.project_prefix}-build"
  build_timeout = "5"
  service_role  = "${aws_iam_role.codebuild_role.arn}"
  # badge_enabled  = true // InvalidInputException: Build badges are not supported for CodePipeline source

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    // https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html
    image           = "aws/codebuild/nodejs:10.1.0"
    type            = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${data.template_file.buildspec_build.rendered}"
  }
}

resource "aws_codebuild_project" "deploy" {
  name          = "${var.project_prefix}-deploy"
  build_timeout = "5"
  service_role  = "${aws_iam_role.codebuild_role.arn}"
  # badge_enabled  = true // InvalidInputException: Build badges are not supported for CodePipeline source

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    // https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html
    image           = "aws/codebuild/python:3.6.5"
    type            = "LINUX_CONTAINER"

    environment_variable {
      name  = "AWS_ACCESS_KEY_ID"
      value = "${var.access_key}"
    }

    environment_variable {
      name  = " AWS_SECRET_ACCESS_KEY"
      value = "${var.secret_key}"
    }

    environment_variable {
      name  = " AWS_REGION"
      value = "${var.region}"
    }    
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${data.template_file.buildspec_deploy.rendered}"
  }
}

/* CodePipeline */

resource "aws_codepipeline" "this" {
  name     = "${var.project_prefix}-pipeline"
  role_arn = "${aws_iam_role.codepipeline_role.arn}"

  artifact_store {
    location = "${aws_s3_bucket.this.bucket}"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["lambda-source"]

      configuration {
        Owner      = "CirclesUBI"
        Repo       = "${var.project_prefix}"
        Branch     = "master"
        OAuthToken = "${var.github_oauth_token}"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["lambda-source"]
      output_artifacts = ["lambda-zip"]

      configuration {
        ProjectName = "${var.project_prefix}-build"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      category = "Build"
      name     = "Deploy"
      owner    = "AWS"
      provider = "CodeBuild"
      version  = "1"

      input_artifacts  = ["lambda-zip"]

      configuration {
        ProjectName = "${var.project_prefix}-deploy"
      }
    }
  }
}