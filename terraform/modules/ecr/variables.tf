variable "project" {
  description = "Project name used for resource naming"
  type        = string
}

variable "env" {
  description = "Environment name (dev or prd)"
  type        = string
}

variable "image_retention_count" {
  description = "Number of images to retain in ECR"
  type        = number
  default     = 10
}
