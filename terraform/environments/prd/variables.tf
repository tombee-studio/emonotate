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

variable "ecr_image_uri" {
  description = "Full ECR image URI for the backend Lambda"
  type        = string
  default     = "public.ecr.aws/lambda/python:3.9"
}
