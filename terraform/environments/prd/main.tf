locals {
  project = "emonotate"
  env     = "prd"
}

removed {
  from = module.network
  lifecycle {
    destroy = false
  }
}

module "ecr" {
  source  = "../../modules/ecr"
  project = local.project
  env     = local.env
}

removed {
  from = module.rds
  lifecycle {
    destroy = false
  }
}

module "s3_cloudfront" {
  source          = "../../modules/s3_cloudfront"
  project         = local.project
  env             = local.env
  api_gateway_url = module.api_gateway_lambda.api_endpoint
}

module "api_gateway_lambda" {
  source             = "../../modules/api_gateway_lambda"
  project            = local.project
  env                = local.env
  ecr_image_uri      = var.ecr_image_uri
  app_base           = module.s3_cloudfront.cloudfront_domain_name
  cognito_pool_id    = module.cognito.pool_id
  cognito_domain     = module.cognito.domain
  cognito_client_id  = module.cognito.client_id
  media_bucket_name  = module.s3_cloudfront.media_bucket_name
  lambda_memory_mb   = 1024
  lambda_timeout_sec = 180
}

module "iam_oidc" {
  source     = "../../modules/iam_oidc"
  env        = local.env
  project    = local.project
  github_org = "tombee-studio"
  github_refs = {
    emonotate-backend = "master"
    emonotate-app     = "master"
  }
  ecr_repository_arns          = [module.ecr.repository_arn]
  frontend_bucket_arns         = [module.s3_cloudfront.frontend_bucket_arn]
  lambda_function_arns         = [module.api_gateway_lambda.lambda_function_arn]
  cloudfront_distribution_arns = ["*"]
}

output "api_endpoint" {
  value = module.api_gateway_lambda.api_endpoint
}

output "cloudfront_domain" {
  value = module.s3_cloudfront.cloudfront_domain_name
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ci_role_arn" {
  value = module.iam_oidc.ci_role_arn
}

module "cognito" {
  source   = "../../modules/cognito"
  name     = "${local.project}-${local.env}"
  app_base = module.s3_cloudfront.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  value = module.s3_cloudfront.cloudfront_distribution_id
}

module "terraform_ci" {
  source        = "../../modules/terraform_ci"
  project       = local.project
  env           = local.env
  github_org    = "tombee-studio"
  github_repo   = "emonotate"
  github_branch = "main"
}

output "terraform_plan_role_arn" {
  value = module.terraform_ci.plan_role_arn
}

output "terraform_apply_role_arn" {
  value = module.terraform_ci.apply_role_arn
}
