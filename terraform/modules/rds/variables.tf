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
  description = "Minimum Aurora capacity units (ACUs)"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum Aurora capacity units (ACUs)"
  type        = number
  default     = 4
}

variable "auto_pause" {
  description = "Enable auto-pause when idle (saves cost in dev)"
  type        = bool
  default     = true
}

variable "seconds_until_auto_pause" {
  description = "Seconds of inactivity before auto-pause"
  type        = number
  default     = 300
}
