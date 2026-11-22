variable "project" {
  description = "Project name used for resource naming"
  type        = string
}

variable "env" {
  description = "Environment name (dev or prd)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to deploy Aurora into"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DB subnet group (minimum 2)"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "Security group ID to attach to the Aurora cluster"
  type        = string
}

variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "emonotate"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "emonotate"
}

variable "db_password" {
  description = "Master password for the database"
  type        = string
  sensitive   = true
}

variable "min_capacity" {
  description = "Minimum Aurora Serverless v2 ACUs (0 = scale to zero)"
  type        = number
  default     = 0
}

variable "max_capacity" {
  description = "Maximum Aurora Serverless v2 ACUs"
  type        = number
  default     = 1
}
