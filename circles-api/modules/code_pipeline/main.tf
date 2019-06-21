resource "aws_s3_bucket" "circles_api" {
  bucket        = "${var.project}-artifact-store"
  acl           = "private"
  force_destroy = true
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "codepipeline-role"
  assume_role_policy = "${file("${path.module}/policies/codepipeline_role.json")}"
}

/* policies */
data "template_file" "codepipeline_policy" {
  template = "${file("${path.module}/policies/codepipeline.json")}"

  vars {
    aws_s3_bucket_arn = "${aws_s3_bucket.circles_api.arn}"
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name   = "codepipeline-policy"
  role   = "${aws_iam_role.codepipeline_role.id}"
  policy = "${data.template_file.codepipeline_policy.rendered}"
}

/*
/* CodeBuild
*/
resource "aws_iam_role" "codebuild_role" {
  name               = "codebuild-role"
  assume_role_policy = "${file("${path.module}/policies/codebuild_role.json")}"
}

data "template_file" "codebuild_policy" {
  template = "${file("${path.module}/policies/codebuild_policy.json")}"

  vars {
    aws_s3_bucket_arn = "${aws_s3_bucket.circles_api.arn}"
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name   = "codebuild-policy"
  role   = "${aws_iam_role.codebuild_role.id}"
  policy = "${data.template_file.codebuild_policy.rendered}"
}

data "template_file" "buildspec_test" {
  template = "${file("${path.module}/buildspec_test.yml")}"
}

data "template_file" "buildspec_build" {
  template = "${file("${path.module}/buildspec_build.yml")}"

  vars {
    repository_url = "${var.repository_url}"
    region         = "${var.region}"
  }
}

resource "aws_codebuild_project" "build" {
  name          = "${var.project}-build"
  build_timeout = "15"
  service_role  = "${aws_iam_role.codebuild_role.arn}"

  # badge_enabled  = true // InvalidInputException: Build badges are not supported for CodePipeline source

  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"

    // https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html
    image           = "aws/codebuild/docker:17.09.0" #"aws/codebuild/docker:1.12.1"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "${data.template_file.buildspec_build.rendered}"
  }
}

resource "aws_codebuild_project" "test" {
  name          = "${var.project}-test"
  build_timeout = "15"
  service_role  = "${aws_iam_role.codebuild_role.arn}"

  # badge_enabled  = true // InvalidInputException: Build badges are not supported for CodePipeline source

  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"

    // https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html
    image = "aws/codebuild/nodejs:8.11.0"
    type  = "LINUX_CONTAINER"

    environment_variable {
      name  = "PGUSER"
      value = "${var.database_user}"
    }

    environment_variable {
      name  = "PGHOST"
      value = "${var.database_host}"
    }

    environment_variable {
      name  = "PGPASSWORD"
      value = "${var.database_password}"
    }

    environment_variable {
      name  = "PGDATABASE"
      value = "${var.database_name}"
    }

    environment_variable {
      name  = "PGPORT"
      value = "${var.database_port}"
    }

    environment_variable {
      name  = "API_PRIV_KEY"
      value = "${var.private_key}"
    }

    environment_variable {
      name  = "COGNITO_POOL_ID"
      value = "${var.cognito_pool_id}"
    }

    environment_variable {
      name  = "COGNITO_CLIENT_ID_API"
      value = "${var.cognito_client_id}"
    }

    environment_variable {
      name  = "COGNITO_POOL_JWT_KID"
      value = "${var.cognito_pool_jwt_kid}"
    }

    environment_variable {
      name  = "COGNITO_POOL_JWT_N"
      value = "${var.cognito_pool_jwt_n}"
    }

    environment_variable {
      name  = "ANDROID_GCM_PLATFORM_ARN"
      value = "${var.android_platform_gcm_arn}"
    }

    environment_variable {
      name  = "COGNITO_POOL_REGION"
      value = "${var.region}"
    }

    environment_variable {
      name  = "COGNITO_TEST_USERNAME"
      value = "${var.cognito_test_username}"
    }

    environment_variable {
      name  = "COGNITO_TEST_PASSWORD"
      value = "${var.cognito_test_password}"
    }

    environment_variable {
      name  = "NETWORK_ID"
      value = "${var.blockchain_network_id}"
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "${data.template_file.buildspec_test.rendered}"
  }
}

/* CodePipeline */

resource "aws_codepipeline" "pipeline" {
  name     = "${var.project}-pipeline"
  role_arn = "${aws_iam_role.codepipeline_role.arn}"

  artifact_store {
    location = "${aws_s3_bucket.circles_api.bucket}"
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
      output_artifacts = ["source-1"]

      configuration {
        Owner      = "CirclesUBI"
        Repo       = "circles-api"
        Branch     = "${var.github_branch}"
        OAuthToken = "${var.github_oauth_token}"
      }
    }
  }

  stage {
    name = "Test"

    action {
      name             = "Test"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source-1"]
      output_artifacts = ["source-2"]

      configuration {
        ProjectName = "${var.project}-test"
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
      input_artifacts  = ["source-2"]
      output_artifacts = ["imagedefinitions"]

      configuration {
        ProjectName = "${var.project}-build"
      }
    }
  }

  stage {
    name = "Production"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["imagedefinitions"]
      version         = "1"

      configuration {
        ClusterName = "${var.ecs_cluster_name}"
        ServiceName = "${var.ecs_service_name}"
        FileName    = "imagedefinitions.json"
      }
    }
  }
}
