variable "project" {
  description = "Project name used for resource naming"
  type        = string
}

variable "env" {
  description = "Environment name (dev or prd)"
  type        = string
}

variable "frontend_domain" {
  description = "Custom domain for the frontend CloudFront distribution"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for custom domain (us-east-1)"
  type        = string
  default     = ""
}

variable "api_gateway_url" {
  description = "API Gateway HTTP API endpoint URL (without trailing slash)"
  type        = string
  default     = ""
}
