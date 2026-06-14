variable "project" {
  description = "Project name used for resource naming"
  type        = string
}

variable "env" {
  description = "Environment name (dev or prd)"
  type        = string
}

variable "ecr_image_uri" {
  description = "Full ECR image URI including tag"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda VPC config"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda"
  type        = string
}

variable "django_secret_name" {
  description = "AWS Secrets Manager secret name for Django"
  type        = string
}

variable "media_bucket_name" {
  description = "S3 bucket name for media files"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "api_base" {
  description = "API base domain (without protocol)"
  type        = string
  default     = ""
}

variable "app_base" {
  description = "Frontend base domain (without protocol)"
  type        = string
  default     = ""
}

variable "lambda_memory_mb" {
  description = "Lambda memory in MB"
  type        = number
  default     = 512
}

variable "lambda_timeout_sec" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}
