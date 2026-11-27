# One call per product, each its own pool. This file only exists so CI can
# run `tofu validate` against real-looking callers; nobody applies it.
# Products use source = "git::https://github.com/aksuyek/aws-modules.git//cognito?ref=v1.0.0".

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.83"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

provider "aws" {
  alias  = "zurich"
  region = "eu-central-2"
}

locals {
  account = "123456789012"
}

# Futbolmetre, eu-central-1: password, email code, passkey, Apple; custom auth domain.
module "futbolmetre" {
  source = "../../cognito"

  project_name       = "futbolmetre-prod"
  domain_name        = "futbolmetre.com"
  first_auth_factors = ["PASSWORD", "EMAIL_OTP", "WEB_AUTHN"]

  email_source_arn       = "arn:aws:ses:eu-central-1:${local.account}:identity/futbolmetre.com"
  from_email_address     = "Futbolmetre <no-reply@futbolmetre.com>"
  reply_to_email_address = "support@futbolmetre.com"

  pre_sign_up_lambda_arn    = "arn:aws:lambda:eu-central-1:${local.account}:function:futbolmetre-prod-cognito-link"
  custom_message_lambda_arn = "arn:aws:lambda:eu-central-1:${local.account}:function:futbolmetre-prod-cognito-message"
  social_identity_providers = ["SignInWithApple"]

  callback_urls = ["https://futbolmetre.com/auth/callback", "futbolmetre://auth/callback"]
  logout_urls   = ["https://futbolmetre.com/", "futbolmetre://"]

  groups = {
    admins = { description = "Futbolmetre production administrators", precedence = 1 }
  }

  custom_domain                 = "auth.futbolmetre.com"
  custom_domain_certificate_arn = "arn:aws:acm:us-east-1:${local.account}:certificate/00000000-0000-0000-0000-000000000000"

  # Existing pool: keep its live settings.
  password_policy = {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
  }
  token_validity_units        = null
  lambda_permission_condition = "source_account"

  tags = { Project = "futbolmetre", Environment = "prod", ManagedBy = "terraform" }
}

# Ziffli, eu-central-2 (Zurich): password and email code, invite gate, own mail sender.
module "ziffli" {
  source    = "../../cognito"
  providers = { aws = aws.zurich }

  project_name       = "ziffli-prod"
  pool_name          = "ziffli-prod-parents"
  domain_name        = "ziffli.ch"
  first_auth_factors = ["PASSWORD", "EMAIL_OTP"]

  pre_sign_up_lambda_arn          = "arn:aws:lambda:eu-central-2:${local.account}:function:ziffli-prod-pre-signup"
  post_confirmation_lambda_arn    = "arn:aws:lambda:eu-central-2:${local.account}:function:ziffli-prod-post-confirmation"
  custom_email_sender_lambda_arn  = "arn:aws:lambda:eu-central-2:${local.account}:function:ziffli-prod-custom-email-sender"
  custom_email_sender_kms_key_arn = "arn:aws:kms:eu-central-2:${local.account}:key/00000000-0000-0000-0000-000000000000"

  callback_urls = ["https://ziffli.ch/auth/callback"]
  logout_urls   = ["https://ziffli.ch/"]
  domain_prefix = "ziffli-prod-${local.account}"

  # Existing pool: keep its live settings.
  prevent_user_existence_errors = "LEGACY"
  password_policy = {
    minimum_length    = 12
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
  }
  explicit_auth_flows           = ["ALLOW_USER_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  oauth_scopes                  = ["openid", "email", "profile"]
  auth_session_validity_minutes = 3
  token_validity_units          = { access_token = "hours", id_token = "hours", refresh_token = "days" }

  tags = { Application = "ziffli", Environment = "prod", ManagedBy = "terraform" }
}

# Hüetabig, eu-central-1: email code and passkeys, optional password.
module "huetabig" {
  source = "../../cognito"

  project_name            = "huetabig-prod"
  username_case_sensitive = false
  domain_name             = "huetabig.ch"
  first_auth_factors      = ["EMAIL_OTP", "WEB_AUTHN", "PASSWORD"]

  email_source_arn       = "arn:aws:ses:eu-central-1:${local.account}:identity/huetabig.ch"
  from_email_address     = "Hüetabig <no-reply@huetabig.ch>"
  reply_to_email_address = "hallo@huetabig.ch"

  custom_message_lambda_arn    = "arn:aws:lambda:eu-central-1:${local.account}:function:huetabig-prod-cognito-message"
  post_confirmation_lambda_arn = "arn:aws:lambda:eu-central-1:${local.account}:function:huetabig-prod-cognito-post-confirmation"

  tags = { Project = "huetabig", Environment = "prod", ManagedBy = "terraform" }
}

# Weinquiz, eu-central-1: the same factors as Hüetabig, its own pool and brand.
module "weinquiz" {
  source = "../../cognito"

  project_name            = "weinquiz-prod"
  username_case_sensitive = false
  domain_name             = "weinquiz.ch"
  first_auth_factors      = ["EMAIL_OTP", "WEB_AUTHN", "PASSWORD"]

  email_source_arn       = "arn:aws:ses:eu-central-1:${local.account}:identity/weinquiz.ch"
  from_email_address     = "Weinquiz <no-reply@weinquiz.ch>"
  reply_to_email_address = "hallo@weinquiz.ch"

  custom_message_lambda_arn = "arn:aws:lambda:eu-central-1:${local.account}:function:weinquiz-prod-cognito-message"

  tags = { Project = "weinquiz", Environment = "prod", ManagedBy = "terraform" }
}

# Skiboard, eu-central-1: email code (replaces the emailed link) and password.
module "skiboard" {
  source = "../../cognito"

  project_name            = "skiboard-prod"
  username_case_sensitive = false
  domain_name             = "skiboard.ch"
  first_auth_factors      = ["EMAIL_OTP", "PASSWORD"]

  email_source_arn       = "arn:aws:ses:eu-central-1:${local.account}:identity/skiboard.ch"
  from_email_address     = "Skiboard <no-reply@skiboard.ch>"
  reply_to_email_address = "hallo@skiboard.ch"

  custom_message_lambda_arn = "arn:aws:lambda:eu-central-1:${local.account}:function:skiboard-prod-cognito-message"

  access_token_validity_minutes = 60
  refresh_token_validity_days   = 90

  tags = { Project = "skiboard", Environment = "prod", ManagedBy = "terraform" }
}

output "issuer_urls" {
  value = {
    futbolmetre = module.futbolmetre.issuer_url
    ziffli      = module.ziffli.issuer_url
    huetabig    = module.huetabig.issuer_url
    weinquiz    = module.weinquiz.issuer_url
    skiboard    = module.skiboard.issuer_url
  }
}
