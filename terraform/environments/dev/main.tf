locals {
  project = "emonotate"
  env     = "dev"
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

resource "null_resource" "push_bootstrap_image" {
  triggers = {
    ecr_url = module.ecr.repository_url
  }

  provisioner "local-exec" {
    command = <<-EOF
      aws ecr get-login-password --region ap-northeast-1 \
        | docker login --username AWS --password-stdin ${module.ecr.repository_url}
      mkdir -p /tmp/bootstrap-lambda
      printf 'FROM public.ecr.aws/lambda/python:3.12\nCMD ["lambda_handler.handler"]\n' \
        > /tmp/bootstrap-lambda/Dockerfile
      docker buildx build --platform linux/amd64 --provenance=false \
        -t ${module.ecr.repository_url}:bootstrap \
        --push /tmp/bootstrap-lambda/
    EOF
  }

  depends_on = [module.ecr]
}

module "api_gateway_lambda" {
  source             = "../../modules/api_gateway_lambda"
  project            = local.project
  env                = local.env
  ecr_image_uri      = "${module.ecr.repository_url}:bootstrap"
  app_base           = module.s3_cloudfront.cloudfront_domain_name
  cognito_pool_id    = module.cognito.pool_id
  cognito_domain     = module.cognito.domain
  cognito_client_id  = module.cognito.client_id
  media_bucket_name  = module.s3_cloudfront.media_bucket_name
  lambda_memory_mb   = 512
  lambda_timeout_sec = 180

  depends_on = [null_resource.push_bootstrap_image]
}

module "iam_oidc" {
  source                       = "../../modules/iam_oidc"
  env                          = local.env
  github_branch                = "develop"
  project                      = local.project
  github_org                   = "tombee-studio"
  github_repo                  = "emonotate"
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
