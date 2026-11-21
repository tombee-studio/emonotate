locals {
  project = "emonotate"
  env     = "stg"
}

module "ecr" {
  source  = "../../modules/ecr"
  project = local.project
  env     = local.env
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
  lambda_memory_mb   = 512
  lambda_timeout_sec = 180
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

module "cognito" {
  source   = "../../modules/cognito"
  name     = "${local.project}-${local.env}"
  app_base = module.s3_cloudfront.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  value = module.s3_cloudfront.cloudfront_distribution_id
}
