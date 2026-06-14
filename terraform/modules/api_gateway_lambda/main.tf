locals {
  name_prefix = "${var.project}-${var.env}"
}

# --- IAM role for Lambda ---

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = {
    Project = var.project
    Env     = var.env
  }
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "lambda_perms" {
  statement {
    sid     = "S3Media"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${var.media_bucket_name}",
      "arn:aws:s3:::${var.media_bucket_name}/*"
    ]
  }
}

resource "aws_iam_role_policy" "lambda_perms" {
  name   = "${local.name_prefix}-lambda-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_perms.json
}

# --- Lambda function ---

resource "aws_lambda_function" "backend" {
  function_name = "${local.name_prefix}-backend"
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = var.ecr_image_uri

  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_sec

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      DJANGO_SETTINGS_MODULE  = "backend.settings.aws"
      DJANGO_SECRET_KEY       = var.django_secret_key
      DB_HOST                 = var.db_host
      DB_NAME                 = var.db_name
      DB_USER                 = var.db_user
      DB_PASSWORD             = var.db_password
      DB_PORT                 = "5432"
      AWS_STORAGE_BUCKET_NAME = var.media_bucket_name
      AWS_REGION              = var.aws_region
      APP_BASE                = var.app_base
    }
  }

  tags = {
    Name    = "${local.name_prefix}-backend"
    Project = var.project
    Env     = var.env
  }
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/aws/lambda/${aws_lambda_function.backend.function_name}"
  retention_in_days = var.env == "prd" ? 90 : 14
}

# --- API Gateway HTTP API ---

resource "aws_apigatewayv2_api" "main" {
  name          = "${local.name_prefix}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = var.app_base != "" ? ["https://${var.app_base}"] : ["*"]
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization", "X-API-Key"]
    max_age       = 300
  }

  tags = {
    Name    = "${local.name_prefix}-api"
    Project = var.project
    Env     = var.env
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.backend.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "proxy" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      sourceIp       = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      protocol       = "$context.protocol"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }
}

resource "aws_cloudwatch_log_group" "apigw" {
  name              = "/aws/apigateway/${local.name_prefix}"
  retention_in_days = var.env == "prd" ? 90 : 14
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
