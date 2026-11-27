# One Cognito user pool for ONE product. Never put two products in one pool:
# each product calls this module for its own pool, in its own region.
#
# Resource addresses (this, web, this[...]) match Futbolmetre's former local
# module so its pool and client move onto this module without replacement.

locals {
  pool_name = coalesce(var.pool_name, "${var.project_name}-users")

  password_enabled = contains(var.first_auth_factors, "PASSWORD")
  passkey_enabled  = contains(var.first_auth_factors, "WEB_AUTHN")
  oauth_enabled    = length(var.callback_urls) > 0

  # Cognito requires PASSWORD in the pool's first factors. Whether a product
  # actually offers passwords is decided by the client flows below.
  pool_first_auth_factors = distinct(concat(["PASSWORD"], var.first_auth_factors))

  explicit_auth_flows = concat(
    ["ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_AUTH"],
    local.password_enabled ? ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_USER_SRP_AUTH"] : [],
  )

  hosted_domain = var.custom_domain != null ? var.custom_domain : var.domain_prefix

  # Trigger name => [unqualified function ARN, permission statement id].
  # Statement ids match the ones Futbolmetre and Ziffli already use.
  lambda_triggers = {
    for name, t in {
      pre_sign_up         = [var.pre_sign_up_lambda_arn, "AllowCognitoPreSignUp"]
      post_confirmation   = [var.post_confirmation_lambda_arn, "AllowCognitoPostConfirmation"]
      post_authentication = [var.post_authentication_lambda_arn, "AllowCognitoPostAuthentication"]
      custom_message      = [var.custom_message_lambda_arn, "AllowCognitoCustomMessage"]
      custom_email_sender = [var.custom_email_sender_lambda_arn, "AllowCognitoCustomEmailSender"]
    } : name => { arn = t[0], statement_id = t[1] } if t[0] != null
  }
}

resource "aws_cognito_user_pool" "this" {
  name = local.pool_name

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  mfa_configuration        = "OFF"
  deletion_protection      = "ACTIVE"
  user_pool_tier           = "ESSENTIALS"

  sign_in_policy {
    allowed_first_auth_factors = local.pool_first_auth_factors
  }

  dynamic "web_authn_configuration" {
    for_each = local.passkey_enabled ? [1] : []
    content {
      relying_party_id  = var.domain_name
      user_verification = "preferred"
    }
  }

  dynamic "lambda_config" {
    for_each = length(local.lambda_triggers) > 0 ? [1] : []
    content {
      pre_sign_up         = var.pre_sign_up_lambda_arn
      post_confirmation   = var.post_confirmation_lambda_arn
      post_authentication = var.post_authentication_lambda_arn
      custom_message      = var.custom_message_lambda_arn
      kms_key_id          = var.custom_email_sender_kms_key_arn

      dynamic "custom_email_sender" {
        for_each = var.custom_email_sender_lambda_arn != null ? [1] : []
        content {
          lambda_arn     = var.custom_email_sender_lambda_arn
          lambda_version = "V1_0"
        }
      }
    }
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # NIST SP 800-63B: length, no character-class rules.
  password_policy {
    minimum_length                   = 10
    require_lowercase                = false
    require_numbers                  = false
    require_symbols                  = false
    require_uppercase                = false
    temporary_password_validity_days = 7
  }

  dynamic "email_configuration" {
    for_each = var.email_source_arn != null ? [1] : []
    content {
      email_sending_account  = "DEVELOPER"
      source_arn             = var.email_source_arn
      from_email_address     = var.from_email_address
      reply_to_email_address = var.reply_to_email_address
    }
  }

  tags = var.tags

  lifecycle {
    # Product data is keyed by the Cognito `sub`. A replaced pool issues new
    # subs and orphans every user, so a plan that replaces it must fail.
    prevent_destroy = true

    precondition {
      condition     = var.email_source_arn != null || var.custom_email_sender_lambda_arn != null
      error_message = "Set email_source_arn (SES, developer mode), or custom_email_sender_lambda_arn if the Lambda sends every mail itself."
    }

    precondition {
      condition     = (var.custom_email_sender_lambda_arn == null) == (var.custom_email_sender_kms_key_arn == null)
      error_message = "custom_email_sender_lambda_arn and custom_email_sender_kms_key_arn must be set together."
    }
  }
}

resource "aws_cognito_user_pool_client" "web" {
  name         = "${var.project_name}-web"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret               = false
  auth_session_validity         = 15
  enable_token_revocation       = true
  prevent_user_existence_errors = "ENABLED"
  explicit_auth_flows           = local.explicit_auth_flows
  supported_identity_providers  = concat(["COGNITO"], var.social_identity_providers)

  allowed_oauth_flows_user_pool_client = local.oauth_enabled
  allowed_oauth_flows                  = local.oauth_enabled ? ["code"] : null
  allowed_oauth_scopes                 = local.oauth_enabled ? ["aws.cognito.signin.user.admin", "email", "openid", "profile"] : null
  callback_urls                        = local.oauth_enabled ? var.callback_urls : null
  logout_urls                          = local.oauth_enabled ? var.logout_urls : null

  access_token_validity  = var.access_token_validity_minutes
  id_token_validity      = var.access_token_validity_minutes
  refresh_token_validity = var.refresh_token_validity_days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

resource "aws_cognito_user_group" "this" {
  for_each = var.groups

  name         = each.key
  user_pool_id = aws_cognito_user_pool.this.id
  description  = each.value.description
  precedence   = each.value.precedence
}

resource "aws_cognito_user_pool_domain" "this" {
  count = local.hosted_domain != null ? 1 : 0

  user_pool_id    = aws_cognito_user_pool.this.id
  domain          = local.hosted_domain
  certificate_arn = var.custom_domain != null ? var.custom_domain_certificate_arn : null

  lifecycle {
    precondition {
      condition     = var.custom_domain == null || var.custom_domain_certificate_arn != null
      error_message = "custom_domain needs custom_domain_certificate_arn (ACM, us-east-1)."
    }
  }
}

resource "aws_lambda_permission" "trigger" {
  for_each = local.lambda_triggers

  statement_id = each.value.statement_id
  action       = "lambda:InvokeFunction"
  # The function name, not the ARN: arn:aws:lambda:<region>:<account>:function:<name>
  function_name = split(":", each.value.arn)[6]
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.this.arn
}
