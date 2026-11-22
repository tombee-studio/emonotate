variable "project" {
  description = "Project name used for resource naming"
  type        = string
}

variable "env" {
  description = "Deployment environment used in the role names"
  type        = string
}

variable "github_org" {
  description = "GitHub organization or user name"
  type        = string
}

variable "github_repo" {
  description = "Repository whose workflows run Terraform (the parent repository)"
  type        = string
}

variable "github_branch" {
  description = "Branch whose pushes apply Terraform to this environment"
  type        = string
}
