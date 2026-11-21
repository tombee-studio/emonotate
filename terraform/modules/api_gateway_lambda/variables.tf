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

variable "cognito_domain" {
  type = string
}

variable "cognito_client_id" {
  type = string
}

variable "media_bucket_name" {
  description = "S3 bucket name for media files"
  type        = string
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

variable "cognito_pool_id" {
  type = string
}
