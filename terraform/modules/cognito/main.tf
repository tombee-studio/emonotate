variable "name" {
  type = string
}

variable "app_base" {
  type = string
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_cognito_user_pool" "main" {
  name                     = var.name
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.name}-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.main.id
}

resource "aws_cognito_user_pool_client" "web" {
  name                                 = "${var.name}-web"
  user_pool_id                         = aws_cognito_user_pool.main.id
  generate_secret                      = false
  supported_identity_providers         = ["COGNITO"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email"]
  callback_urls                        = ["https://${var.app_base}/api/cognito/callback/"]
  logout_urls                          = ["https://${var.app_base}/"]
  prevent_user_existence_errors        = "ENABLED"
}

output "domain" {
  value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
}

output "client_id" {
  value = aws_cognito_user_pool_client.web.id
}

output "pool_id" {
  value = aws_cognito_user_pool.main.id
}
