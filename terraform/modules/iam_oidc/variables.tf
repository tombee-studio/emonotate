variable "project" {
  description = "Project name used for resource naming"
  type        = string
}

variable "github_org" {
  description = "GitHub organization or user name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs that CI can push to"
  type        = list(string)
}

variable "frontend_bucket_arns" {
  description = "S3 bucket ARNs for frontend deployment"
  type        = list(string)
}

variable "lambda_function_arns" {
  description = "Lambda function ARNs that CI can update"
  type        = list(string)
}

variable "cloudfront_distribution_arns" {
  description = "CloudFront distribution ARNs for cache invalidation"
  type        = list(string)
  default     = ["*"]
}
