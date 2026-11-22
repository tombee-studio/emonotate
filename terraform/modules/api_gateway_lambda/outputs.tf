output "api_endpoint" {
  value = aws_apigatewayv2_api.main.api_endpoint
}

output "api_id" {
  value = aws_apigatewayv2_api.main.id
}

output "lambda_function_name" {
  value = aws_lambda_function.backend.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.backend.arn
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}
