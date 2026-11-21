# The provider is shared across projects and environments in this AWS account.
removed {
  from = aws_iam_openid_connect_provider.github
  lifecycle {
    destroy = false
  }
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  lifecycle {
    postcondition {
      condition     = contains(self.client_id_list, "sts.amazonaws.com")
      error_message = "The shared GitHub OIDC provider must include the sts.amazonaws.com audience."
    }
  }
}

# Keep the former shared role usable while GitHub secrets switch to the new roles.
removed {
  from = aws_iam_role.ci
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_iam_role_policy.ci
  lifecycle {
    destroy = false
  }
}

data "aws_iam_policy_document" "ci_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        for repo, branch in var.github_refs :
        "repo:${var.github_org}/${repo}:ref:refs/heads/${branch}"
      ]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "${var.project}-${var.env}-github-actions-ci"
  assume_role_policy = data.aws_iam_policy_document.ci_assume.json

  tags = {
    Project = var.project
  }
}

data "aws_iam_policy_document" "ci_perms" {
  statement {
    sid       = "ECRAuth"
    actions   = ["ecr:GetAuthorizationToken"]
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
      "lambda:GetFunctionConfiguration",
      "lambda:InvokeFunction",
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
    sid       = "CloudFrontList"
    actions   = ["cloudfront:ListDistributions"]
    resources = ["*"]
  }

  statement {
    sid       = "CloudFrontInvalidate"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = var.cloudfront_distribution_arns
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "${var.project}-ci-policy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.ci_perms.json
}
