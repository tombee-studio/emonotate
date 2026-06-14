resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

locals {
  oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
}

data "aws_iam_policy_document" "ci_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ci" {
  name               = "${var.project}-github-actions-ci"
  assume_role_policy = data.aws_iam_policy_document.ci_assume.json

  tags = {
    Project = var.project
  }
}

data "aws_iam_policy_document" "ci_perms" {
  statement {
    sid = "ECRAuth"
    actions = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "ECRPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = var.ecr_repository_arns
  }

  statement {
    sid = "LambdaDeploy"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:GetFunction",
      "lambda:PublishVersion",
    ]
    resources = var.lambda_function_arns
  }

  statement {
    sid = "S3Frontend"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = concat(
      var.frontend_bucket_arns,
      [for arn in var.frontend_bucket_arns : "${arn}/*"]
    )
  }

  statement {
    sid     = "CloudFrontList"
    actions = ["cloudfront:ListDistributions"]
    resources = ["*"]
  }

  statement {
    sid = "CloudFrontInvalidate"
    actions = ["cloudfront:CreateInvalidation"]
    resources = var.cloudfront_distribution_arns
  }
}

resource "aws_iam_role_policy" "ci" {
  name   = "${var.project}-ci-policy"
  role   = aws_iam_role.ci.id
  policy = data.aws_iam_policy_document.ci_perms.json
}
