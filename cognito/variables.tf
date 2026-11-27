# ---------------------------------------------------------------------------
# Naming and identity
# ---------------------------------------------------------------------------

variable "project_name" {
  description = "Product and environment prefix, e.g. \"huetabig-prod\". The pool is named \"<project_name>-users\" and the client \"<project_name>-web\"."
  type        = string
}

variable "pool_name" {
  description = "Overrides the pool name. Only for a pool that already exists under another name (e.g. \"ziffli-prod-parents\"): the name forces replacement."
  type        = string
  default     = null
}

variable "username_case_sensitive" {
  description = "Case sensitivity of the email username. Set false for every new pool. Can only be set at creation: leave null for an existing pool (Futbolmetre, Ziffli), since a change replaces it."
  type        = bool
  default     = null
}

variable "domain_name" {
  description = "The product's root domain. Used as the passkey (WebAuthn) relying party."
  type        = string
}

variable "first_auth_factors" {
  description = "Allowed first sign-in factors: a subset of PASSWORD, EMAIL_OTP and WEB_AUTHN. PASSWORD is always allowed by Cognito when the client offers password flows."
  type        = list(string)
  default     = ["PASSWORD", "EMAIL_OTP", "WEB_AUTHN"]

  validation {
    condition     = length(var.first_auth_factors) > 0 && alltrue([for f in var.first_auth_factors : contains(["PASSWORD", "EMAIL_OTP", "WEB_AUTHN"], f)])
    error_message = "first_auth_factors must be a non-empty subset of PASSWORD, EMAIL_OTP and WEB_AUTHN."
  }
}

# ---------------------------------------------------------------------------
# Email (SES, developer mode)
# ---------------------------------------------------------------------------

variable "email_source_arn" {
  description = "ARN of the product's verified SES identity. Cognito sends codes through it in DEVELOPER mode. May be null only when custom_email_sender_lambda_arn sends every mail itself."
  type        = string
  default     = null
}

variable "from_email_address" {
  description = "From header of Cognito mails, e.g. \"Hüetabig <no-reply@huetabig.ch>\"."
  type        = string
  default     = null
}

variable "reply_to_email_address" {
  description = "Reply-To header of Cognito mails, e.g. \"support@huetabig.ch\"."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Lambda triggers (all optional). Pass unqualified function ARNs; the module
# adds the lambda:InvokeFunction permission for each one that is set.
# ---------------------------------------------------------------------------

variable "pre_sign_up_lambda_arn" {
  description = "Pre sign-up trigger, e.g. an invite gate or verified-email account linking."
  type        = string
  default     = null
}

variable "post_confirmation_lambda_arn" {
  description = "Post confirmation trigger, e.g. creating the product's user record."
  type        = string
  default     = null
}

variable "post_authentication_lambda_arn" {
  description = "Post authentication trigger."
  type        = string
  default     = null
}

variable "custom_message_lambda_arn" {
  description = "Custom message trigger that renders the product's own mail texts and layout. The module ships no mail texts."
  type        = string
  default     = null
}

variable "custom_email_sender_lambda_arn" {
  description = "Custom email sender trigger (the Lambda sends the mail itself). Requires custom_email_sender_kms_key_arn."
  type        = string
  default     = null
}

variable "custom_email_sender_kms_key_arn" {
  description = "KMS key Cognito encrypts codes with for the custom email sender."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Client and OAuth
# ---------------------------------------------------------------------------

variable "social_identity_providers" {
  description = "Identity providers the client offers besides COGNITO, e.g. [\"SignInWithApple\", \"Google\"]. Each must already exist in the pool."
  type        = list(string)
  default     = []
}

variable "callback_urls" {
  description = "OAuth callback URLs. OAuth (code flow) is enabled only when this list is non-empty."
  type        = list(string)
  default     = []
}

variable "logout_urls" {
  description = "OAuth logout URLs."
  type        = list(string)
  default     = []
}

variable "access_token_validity_minutes" {
  description = "Lifetime of access and ID tokens in minutes (5 to 1440). Written in the units of token_validity_units."
  type        = number
  default     = 60

  validation {
    condition     = var.access_token_validity_minutes >= 5 && var.access_token_validity_minutes <= 1440
    error_message = "access_token_validity_minutes must be between 5 and 1440."
  }
}

variable "refresh_token_validity_days" {
  description = "Lifetime of refresh tokens in days (1 to 3650)."
  type        = number
  default     = 30

  validation {
    condition     = var.refresh_token_validity_days >= 1 && var.refresh_token_validity_days <= 3650
    error_message = "refresh_token_validity_days must be between 1 and 3650."
  }
}

variable "prevent_user_existence_errors" {
  description = "ENABLED hides whether an email has an account. LEGACY returns UserNotFoundException, only for an app whose sign-up path depends on it (Ziffli)."
  type        = string
  default     = "ENABLED"

  validation {
    condition     = contains(["ENABLED", "LEGACY"], var.prevent_user_existence_errors)
    error_message = "prevent_user_existence_errors must be ENABLED or LEGACY."
  }
}

variable "explicit_auth_flows" {
  description = "Overrides the client's auth flows. Null = ALLOW_USER_AUTH + ALLOW_REFRESH_TOKEN_AUTH, plus ALLOW_USER_PASSWORD_AUTH and ALLOW_USER_SRP_AUTH when PASSWORD is a first factor."
  type        = list(string)
  default     = null

  validation {
    condition = var.explicit_auth_flows == null || (
      contains(coalesce(var.explicit_auth_flows, []), "ALLOW_REFRESH_TOKEN_AUTH") &&
      alltrue([for f in coalesce(var.explicit_auth_flows, []) : contains(["ALLOW_USER_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_PASSWORD_AUTH", "ALLOW_USER_SRP_AUTH", "ALLOW_CUSTOM_AUTH", "ALLOW_ADMIN_USER_PASSWORD_AUTH"], f)])
    )
    error_message = "explicit_auth_flows must include ALLOW_REFRESH_TOKEN_AUTH and contain only ALLOW_* Cognito flow names."
  }
}

variable "oauth_scopes" {
  description = "OAuth scopes of the client, used only when callback_urls is non-empty."
  type        = list(string)
  default     = ["aws.cognito.signin.user.admin", "email", "openid", "profile"]
}

variable "auth_session_validity_minutes" {
  description = "How long a sign-in session (e.g. waiting for the email code) stays valid, 3 to 15 minutes."
  type        = number
  default     = 15

  validation {
    condition     = var.auth_session_validity_minutes >= 3 && var.auth_session_validity_minutes <= 15
    error_message = "auth_session_validity_minutes must be between 3 and 15."
  }
}

variable "token_validity_units" {
  description = "Units Cognito stores the token lifetimes in. The lifetimes themselves stay in access_token_validity_minutes and refresh_token_validity_days and are converted (60 minutes with \"hours\" is written as 1). Null writes no lifetimes or units, keeping Cognito's defaults (Futbolmetre)."
  type = object({
    access_token  = optional(string, "minutes")
    id_token      = optional(string, "minutes")
    refresh_token = optional(string, "days")
  })
  default = {}

  validation {
    condition = var.token_validity_units == null || (
      contains(["minutes", "hours"], try(var.token_validity_units.access_token, "")) &&
      contains(["minutes", "hours"], try(var.token_validity_units.id_token, "")) &&
      contains(["minutes", "hours", "days"], try(var.token_validity_units.refresh_token, ""))
    )
    error_message = "access_token and id_token units must be minutes or hours; refresh_token minutes, hours or days."
  }
}

# ---------------------------------------------------------------------------
# Pool password policy and Lambda permissions
# ---------------------------------------------------------------------------

variable "password_policy" {
  description = "Password policy. The default is NIST SP 800-63B: at least 10 characters, no character-class rules. Pass an existing pool's policy to keep it."
  type = object({
    minimum_length                   = optional(number, 10)
    require_lowercase                = optional(bool, false)
    require_uppercase                = optional(bool, false)
    require_numbers                  = optional(bool, false)
    require_symbols                  = optional(bool, false)
    temporary_password_validity_days = optional(number, 7)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.password_policy.minimum_length >= 8 && var.password_policy.minimum_length <= 99
    error_message = "password_policy.minimum_length must be between 8 and 99."
  }
}

variable "lambda_permission_condition" {
  description = "How each trigger's lambda:InvokeFunction permission is scoped: source_arn (this pool, the default) or source_account (the account; only to keep permissions that already exist that way, as in Futbolmetre). A change replaces the permissions."
  type        = string
  default     = "source_arn"

  validation {
    condition     = contains(["source_arn", "source_account"], var.lambda_permission_condition)
    error_message = "lambda_permission_condition must be source_arn or source_account."
  }
}

# ---------------------------------------------------------------------------
# Groups and hosted domain
# ---------------------------------------------------------------------------

variable "groups" {
  description = "User groups, as name => { description, precedence }."
  type = map(object({
    description = optional(string)
    precedence  = optional(number)
  }))
  default = {}
}

variable "domain_prefix" {
  description = "Prefix for the Amazon-hosted Cognito domain (<prefix>.auth.<region>.amazoncognito.com). Needed for OAuth and social sign-in. Ignored when custom_domain is set."
  type        = string
  default     = null
}

variable "custom_domain" {
  description = "Custom auth domain, e.g. \"auth.futbolmetre.com\". Takes precedence over domain_prefix. The caller creates the DNS alias to the auth_domain_cloudfront_distribution output."
  type        = string
  default     = null
}

variable "custom_domain_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for custom_domain."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags for every resource that takes them."
  type        = map(string)
  default     = {}
}
