resource "aws_codestarconnections_connection" "github" {
  name          = "opsflow-github"
  provider_type = "GitHub"
}
resource "aws_codebuild_project" "build" {
  for_each               = toset(["ci", "cd"])
  name                   = "${local.name}-${each.key}"
  service_role           = aws_iam_role.build[each.key].arn
  build_timeout          = each.key == "ci" ? 45 : 40
  queued_timeout         = 30
  concurrent_build_limit = 1
  artifacts {
    type = "CODEPIPELINE"
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "ci/buildspec-${each.key}.yml"

  }
  environment {
    type            = "LINUX_CONTAINER"
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    privileged_mode = each.key == "ci"
    dynamic "environment_variable" {
      for_each = {
        EXPECTED_ACCOUNT    = var.aws_account_id
        AWS_REGION          = var.aws_region
        EKS_CLUSTER         = local.infra.cluster_name
        BACKEND_REPOSITORY  = local.repositories.backend
        FRONTEND_REPOSITORY = local.repositories.frontend
        HELM_VERSION        = var.helm_version
        KUBECTL_VERSION     = var.kubectl_version

      }
      content {
        name  = environment_variable.key
        value = environment_variable.value
      }

    }

  }
  dynamic "vpc_config" {
    for_each = each.key == "cd" ? [1] : []
    content {
      vpc_id             = local.infra.vpc_id
      subnets            = [aws_subnet.deploy.id]
      security_group_ids = [aws_security_group.deploy.id]
    }

  }
  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.build[each.key].name
      stream_name = "build"
    }

  }
  depends_on = [aws_iam_role_policy.common, aws_iam_role_policy.ci, aws_iam_role_policy.cd, aws_route.egress, aws_route_table_association.deploy]
}
resource "aws_codepipeline" "app" {
  name           = "${local.name}-application"
  role_arn       = aws_iam_role.pipeline.arn
  pipeline_type  = "V2"
  execution_mode = "QUEUED"
  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }
  stage {
    name = "Source"
    action {
      name             = "GitHub"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      namespace        = "SourceVars"
      output_artifacts = ["Source"]
      configuration = {
        ConnectionArn = aws_codestarconnections_connection.github.arn, FullRepositoryId = var.github_repository, BranchName = var.branch, OutputArtifactFormat = "CODE_ZIP", DetectChanges = tostring(var.detect_changes)
      }

    }

  }
  stage {
    name = "BuildAndScan"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["Source"]
      output_artifacts = ["Release"]
      configuration = {
        ProjectName = aws_codebuild_project.build["ci"].name, EnvironmentVariables = jsonencode([{ name = "GIT_COMMIT", value = "#{SourceVars.CommitId}", type = "PLAINTEXT" }])
      }

    }

  }
  stage {
    name = "Approve"
    action {
      name     = "ReviewRelease"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
      configuration = {
        CustomData = "Review source SHA, release.json, scan counts, test coverage and Helm changes. Approve only this execution."
      }

    }

  }
  stage {
    name = "Deploy"
    action {
      name             = "Helm"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["Release"]
      output_artifacts = ["DeploymentEvidence"]
      configuration = {
        ProjectName = aws_codebuild_project.build["cd"].name
      }

    }

  }
  depends_on = [aws_iam_role_policy.pipeline, aws_s3_bucket_public_access_block.artifacts, aws_s3_bucket_server_side_encryption_configuration.artifacts, aws_s3_bucket_policy.tls]
}
