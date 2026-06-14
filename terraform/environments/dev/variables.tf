variable "db_password" {
  description = "Aurora master password"
  type        = string
  sensitive   = true
}

variable "django_secret_key" {
  description = "Django SECRET_KEY"
  type        = string
  sensitive   = true
}

variable "cloudfront_domain" {
  description = "CloudFront domain for CSRF_TRUSTED_ORIGINS (set after initial deploy)"
  type        = string
  default     = ""
}

