# aws-modules

Shared Terraform/OpenTofu modules for Aksüyek GmbH products. Each module is
pinned by tag:

```hcl
source = "git::https://github.com/aksuyek/aws-modules.git//cognito?ref=v1.2.0"
```

| Module | What it builds |
| --- | --- |
| [`cognito`](cognito/) | One Cognito user pool, its public client, optional groups, hosted domain and Lambda triggers |

## cognito

### The rule

**One pool per product. Never put two products in one pool.** Each product
calls this module for its own pool, in its own account region (Ziffli in
eu-central-2, the others in eu-central-1). There is no shared pool and no
central login (decision of 25 Nov 2026, ticket AK-002).

### What is fixed, and what are defaults

Every pool built from this module has, with no input to change it:

- email as the username (`username_attributes = ["email"]`), email auto-verified
- `deletion_protection = "ACTIVE"` and `prevent_destroy`: a plan that would
  replace the pool fails instead of orphaning every user's `sub`
- the Essentials tier (needed for email codes and passkeys)
- email-only account recovery, no MFA
- the Lambda triggers' `lambda:InvokeFunction` permissions, created by the module
- mail through the product's SES identity in `DEVELOPER` mode

Defaults that a **new** pool keeps and that only an existing pool overrides,
to keep its live settings (Futbolmetre, Ziffli):

- passwords of at least 10 characters with no character-class rules (NIST SP 800-63B): `password_policy`
- `prevent_user_existence_errors = "ENABLED"`: `prevent_user_existence_errors`
- client flows `ALLOW_USER_AUTH` + `ALLOW_REFRESH_TOKEN_AUTH`, plus
  `ALLOW_USER_PASSWORD_AUTH` and `ALLOW_USER_SRP_AUTH` when `PASSWORD` is in
  `first_auth_factors`: `explicit_auth_flows`
- OAuth scopes `aws.cognito.signin.user.admin`, `email`, `openid`, `profile`: `oauth_scopes`
- auth session 15 minutes: `auth_session_validity_minutes`
- token lifetimes stored in minutes/minutes/days: `token_validity_units`
- trigger permissions scoped to the pool's ARN: `lambda_permission_condition`

Always: one public client with no secret and token revocation on, refresh
token rotation off (refresh with `InitiateAuth` `REFRESH_TOKEN_AUTH`), and the
OAuth code flow only when `callback_urls` is non-empty.

**No mail texts live here.** Each product passes its own `custom_message`
Lambda (or a `custom_email_sender`) that renders through its own mail layout.

### Inputs

| Name | Default | Notes |
| --- | --- | --- |
| `project_name` | required | e.g. `huetabig-prod`; pool `<project_name>-users`, client `<project_name>-web` |
| `username_case_sensitive` | `null` | set `false` on every new pool; fixed at creation, so leave null for Futbolmetre and Ziffli |
| `pool_name` | `null` | only for an existing pool with another name; the name forces replacement |
| `domain_name` | required | passkey relying party, e.g. `huetabig.ch` |
| `first_auth_factors` | all three | subset of `PASSWORD`, `EMAIL_OTP`, `WEB_AUTHN` (Cognito always keeps `PASSWORD` in the pool policy; leaving it out removes the password flows from the client) |
| `email_source_arn` | `null` | SES identity ARN; may be null only with `custom_email_sender_lambda_arn` |
| `from_email_address`, `reply_to_email_address` | `null` | |
| `pre_sign_up_lambda_arn`, `post_confirmation_lambda_arn`, `post_authentication_lambda_arn`, `custom_message_lambda_arn` | `null` | unqualified function ARNs; `""` counts as null. The module creates each `aws_lambda_permission`: callers must not, or the statement ids collide |
| `trigger_names` | `null` | the triggers whose ARN is set, e.g. `["custom_message"]`. **Required when a trigger Lambda is created in the same apply** (every fresh stack): its ARN is unknown at plan time, and without this the plan fails with `Invalid for_each argument`. Must match the ARNs that are set |
| `custom_email_sender_lambda_arn` + `custom_email_sender_kms_key_arn` | `null` | set both or neither |
| `social_identity_providers` | `[]` | e.g. `["SignInWithApple"]`; each must already exist in the pool |
| `callback_urls`, `logout_urls` | `[]` | |
| `groups` | `{}` | `name => { description, precedence }` |
| `access_token_validity_minutes` | `60` | also the ID token |
| `refresh_token_validity_days` | `30` | |
| `prevent_user_existence_errors` | `"ENABLED"` | `"LEGACY"` only for an app that relies on `UserNotFoundException` (Ziffli) |
| `password_policy` | NIST rule | object: `minimum_length` (10), `require_lowercase`, `require_uppercase`, `require_numbers`, `require_symbols` (all false), `temporary_password_validity_days` (7); omitted fields keep these defaults |
| `explicit_auth_flows` | `null` | overrides the computed flow list; must include `ALLOW_REFRESH_TOKEN_AUTH` |
| `oauth_scopes` | `["aws.cognito.signin.user.admin", "email", "openid", "profile"]` | used only with OAuth |
| `auth_session_validity_minutes` | `15` | 3 to 15 |
| `token_validity_units` | `{ access_token = "minutes", id_token = "minutes", refresh_token = "days" }` | the units Cognito stores lifetimes in; lifetimes are converted (60 minutes in `"hours"` = 1). `null` writes no lifetimes or units and keeps Cognito's defaults (60 min / 60 min / 30 days); the two lifetime inputs must then stay at 60 and 30 |
| `lambda_permission_condition` | `"source_arn"` | `"source_account"` only to keep permissions that already exist that way (Futbolmetre); a change replaces them |
| `domain_prefix` | `null` | Amazon-hosted domain; needed for OAuth/social sign-in |
| `custom_domain`, `custom_domain_certificate_arn` | `null` | e.g. `auth.futbolmetre.com` (ACM in us-east-1); wins over `domain_prefix`. The caller owns the DNS alias |
| `tags` | `{}` | |

### Outputs

`user_pool_id`, `user_pool_arn`, `client_id`, `issuer_url`, `jwks_url`, plus
`auth_domain`, `auth_domain_cloudfront_distribution` and `group_names`.

### Examples, one per product

All five are also in [`examples/cognito/main.tf`](examples/cognito/main.tf),
which CI validates. ARNs below are placeholders for each product's own resources.

#### Futbolmetre (eu-central-1)

```hcl
module "cognito" {
  source = "git::https://github.com/aksuyek/aws-modules.git//cognito?ref=v1.2.0"

  project_name       = local.project_name # futbolmetre-prod
  domain_name        = var.domain_name    # futbolmetre.com
  first_auth_factors = ["PASSWORD", "EMAIL_OTP", "WEB_AUTHN"]

  email_source_arn       = module.ses.domain_identity_arn
  from_email_address     = "Futbolmetre <no-reply@${var.domain_name}>"
  reply_to_email_address = "support@${var.domain_name}"

  pre_sign_up_lambda_arn    = aws_lambda_function.account_linking.arn # now in the FM root
  custom_message_lambda_arn = aws_lambda_function.custom_message.arn  # now in the FM root
  social_identity_providers = ["SignInWithApple"]

  callback_urls = ["https://${var.domain_name}/auth/callback", "futbolmetre://auth/callback"]
  logout_urls   = ["https://${var.domain_name}/", "futbolmetre://"]

  groups = {
    admins = { description = "Futbolmetre production administrators", precedence = 1 }
  }

  custom_domain                 = local.auth_domain
  custom_domain_certificate_arn = module.auth_certificate.certificate_arn

  # Keep the live pool's settings (no behaviour change in FM-021).
  password_policy = {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
  }
  token_validity_units        = null # lifetimes were never set
  lambda_permission_condition = "source_account"

  tags = local.tags
}
```

#### Ziffli (eu-central-2, Zurich, custom email sender)

```hcl
module "cognito" {
  source = "git::https://github.com/aksuyek/aws-modules.git//cognito?ref=v1.2.0"

  project_name       = local.prefix          # ziffli-prod
  pool_name          = "${local.prefix}-parents" # existing pool name
  domain_name        = var.domain_name       # ziffli.ch
  first_auth_factors = ["PASSWORD", "EMAIL_OTP"]

  pre_sign_up_lambda_arn          = aws_lambda_function.pre_signup.arn
  post_confirmation_lambda_arn    = aws_lambda_function.post_confirmation.arn
  custom_email_sender_lambda_arn  = aws_lambda_function.custom_email_sender.arn
  custom_email_sender_kms_key_arn = aws_kms_key.cognito_email.arn

  callback_urls = ["https://${var.domain_name}/auth/callback"]
  logout_urls   = ["https://${var.domain_name}/"]
  domain_prefix = "${local.prefix}-${data.aws_caller_identity.current.account_id}"

  # Keep the live pool's settings (no behaviour change in ZF-018).
  # LEGACY: new-parent sign-up depends on UserNotFoundException.
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
}
```

#### Hüetabig (eu-central-1)

```hcl
module "cognito" {
  source = "git::https://github.com/aksuyek/aws-modules.git//cognito?ref=v1.2.0"

  project_name            = "huetabig-prod"
  username_case_sensitive = false # new pool: set at creation
  domain_name        = "huetabig.ch"
  first_auth_factors = ["EMAIL_OTP", "WEB_AUTHN", "PASSWORD"]

  email_source_arn       = aws_sesv2_email_identity.domain.arn
  from_email_address     = "Hüetabig <no-reply@huetabig.ch>"
  reply_to_email_address = "hallo@huetabig.ch"

  custom_message_lambda_arn    = aws_lambda_function.cognito_message.arn
  post_confirmation_lambda_arn = aws_lambda_function.cognito_post_confirmation.arn
  trigger_names                = ["custom_message", "post_confirmation"] # Lambdas created in the same apply

  tags = local.tags
}
```

#### Weinquiz (eu-central-1)

```hcl
module "cognito" {
  source = "git::https://github.com/aksuyek/aws-modules.git//cognito?ref=v1.2.0"

  project_name            = "weinquiz-prod"
  username_case_sensitive = false # new pool: set at creation
  domain_name        = "weinquiz.ch"
  first_auth_factors = ["EMAIL_OTP", "WEB_AUTHN", "PASSWORD"]

  email_source_arn       = aws_sesv2_email_identity.domain.arn
  from_email_address     = "Weinquiz <no-reply@weinquiz.ch>"
  reply_to_email_address = "hallo@weinquiz.ch"

  custom_message_lambda_arn = aws_lambda_function.cognito_message.arn
  trigger_names             = ["custom_message"] # Lambda created in the same apply

  tags = local.tags
}
```

#### Skiboard (eu-central-1)

```hcl
module "cognito" {
  source = "git::https://github.com/aksuyek/aws-modules.git//cognito?ref=v1.2.0"

  project_name            = "skiboard-prod"
  username_case_sensitive = false # new pool: set at creation
  domain_name        = "skiboard.ch"
  first_auth_factors = ["EMAIL_OTP", "PASSWORD"]

  email_source_arn       = aws_sesv2_email_identity.domain.arn
  from_email_address     = "Skiboard <no-reply@skiboard.ch>"
  reply_to_email_address = "hallo@skiboard.ch"

  custom_message_lambda_arn = aws_lambda_function.cognito_message.arn
  trigger_names             = ["custom_message"] # Lambda created in the same apply

  tags = local.tags
}
```

### Moving an existing pool onto the module

The pool must never be replaced: `name`, `username_attributes`,
`alias_attributes` and `username_configuration` force replacement (AWS
provider 5.x), and so do a group's `name`, the domain's `domain` and every
argument of `aws_lambda_permission`. Use `moved` blocks in the caller, then
check the plan shows **0 to destroy** for the pool and client before anyone
applies.

Futbolmetre (FM-021), from its former local module of the same name:

```hcl
moved {
  from = module.cognito.aws_cognito_user_group.admins
  to   = module.cognito.aws_cognito_user_group.this["admins"]
}
moved {
  from = module.cognito.aws_lambda_permission.account_linking
  to   = module.cognito.aws_lambda_permission.trigger["pre_sign_up"]
}
moved {
  from = module.cognito.aws_lambda_permission.custom_message
  to   = module.cognito.aws_lambda_permission.trigger["custom_message"]
}
moved {
  from = module.cognito.aws_route53_record.auth_custom_domain[0]
  to   = aws_route53_record.auth_custom_domain # alias to module.cognito.auth_domain_cloudfront_distribution
}
# The account-linking and custom-message Lambdas, their roles, policies,
# attachments and log groups move to the root the same way
# (module.cognito.<addr> -> <addr>).
# aws_cognito_user_pool_domain.this -> this[0] is moved automatically.
```

Ziffli (ZF-018), from root resources:

```hcl
moved {
  from = aws_cognito_user_pool.parents
  to   = module.cognito.aws_cognito_user_pool.this
}
moved {
  from = aws_cognito_user_pool_client.web
  to   = module.cognito.aws_cognito_user_pool_client.web
}
moved {
  from = aws_cognito_user_pool_domain.parents
  to   = module.cognito.aws_cognito_user_pool_domain.this[0]
}
moved {
  from = aws_lambda_permission.cognito_pre_signup
  to   = module.cognito.aws_lambda_permission.trigger["pre_sign_up"]
}
moved {
  from = aws_lambda_permission.cognito_post_confirmation
  to   = module.cognito.aws_lambda_permission.trigger["post_confirmation"]
}
moved {
  from = aws_lambda_permission.cognito_custom_email_sender
  to   = module.cognito.aws_lambda_permission.trigger["custom_email_sender"]
}
```

## Development

```bash
tofu fmt -check -recursive
cd cognito && tofu init -backend=false && tofu validate
cd ../examples/cognito && tofu init -backend=false && tofu validate
```

CI (`.github/workflows/validate.yml`) runs the same on every push and pull
request. Nothing here is ever applied from this repo; agents never run
`tofu apply`.

Release: update `CHANGELOG.md`, commit, `git tag vX.Y.Z`, push the tag.
Callers bump `?ref=` themselves.
