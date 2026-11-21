output "ci_role_arn" {
  value = aws_iam_role.deploy.arn
}

output "ci_role_name" {
  value = aws_iam_role.deploy.name
}
