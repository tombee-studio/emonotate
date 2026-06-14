locals {
  project = "emonotate"
  env     = "dev"
}

module "network" {
  source  = "../../modules/network"
  project = local.project
  env     = local.env
}

module "ecr" {
  source  = "../../modules/ecr"
  project = local.project
  env     = local.env
}

module "rds" {
  source                   = "../../modules/rds"
  project                  = local.project
  env                      = local.env
  vpc_id                   = module.network.vpc_id
  private_subnet_ids       = module.network.private_subnet_ids
  rds_security_group_id    = module.network.rds_security_group_id
  db_password  = var.db_password
  min_capacity = 0
  max_capacity = 1
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
      printf 'FROM public.ecr.aws/lambda/python:3.9\nCMD ["lambda_handler.handler"]\n' \
        > /tmp/bootstrap-lambda/Dockerfile
      docker buildx build --platform linux/amd64 --provenance=false \
        -t ${module.ecr.repository_url}:bootstrap \
        --push /tmp/bootstrap-lambda/
    EOF
  }

  depends_on = [module.ecr]
}

module "api_gateway_lambda" {
  source                   = "../../modules/api_gateway_lambda"
  project                  = local.project
  env                      = local.env
  ecr_image_uri            = "${module.ecr.repository_url}:bootstrap"
  vpc_id                   = module.network.vpc_id
  private_subnet_ids       = module.network.private_subnet_ids
  lambda_security_group_id = module.network.lambda_security_group_id
  db_host                  = module.rds.db_host
  db_name                  = module.rds.db_name
  db_user                  = module.rds.db_username
  db_password              = var.db_password
  django_secret_key        = var.django_secret_key
  media_bucket_name        = module.s3_cloudfront.media_bucket_name
  lambda_memory_mb         = 512
  lambda_timeout_sec       = 30

  depends_on = [null_resource.push_bootstrap_image]
}

module "iam_oidc" {
  source                       = "../../modules/iam_oidc"
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
