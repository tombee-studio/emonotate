variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "ecr_image_uri" {
  description = "Full ECR image URI for the backend Lambda"
  type        = string
  default     = "placeholder"
}
