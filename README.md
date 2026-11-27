# aws-modules

Shared Terraform/OpenTofu modules for Aksüyek GmbH products. Each module is
pinned by tag:

```hcl
source = "git::https://github.com/aksuyek/aws-modules.git//cognito?ref=v1.0.0"
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

### What is fixed

Every pool built from this module has, with no input to change it:

- email as the username (`username_attributes = ["email"]`), email auto-verified
- `deletion_protection = "ACTIVE"` and `prevent_destroy`: a plan that would
  replace the pool fails instead of orphaning every user's `sub`
- the Essentials tier (needed for email codes and passkeys)
- email-only account recovery, no MFA
- passwords of at least 10 characters with no character-class rules (NIST SP 800-63B)
- one public client: no secret, token revocation on,
  `prevent_user_existence_errors = "ENABLED"`, auth session 15 minutes, flows
  `ALLOW_USER_AUTH` + `ALLOW_REFRESH_TOKEN_AUTH`, plus `ALLOW_USER_PASSWORD_AUTH`
  and `ALLOW_USER_SRP_AUTH` when `PASSWORD` is in `first_auth_factors`
- OAuth code flow only when `callback_urls` is non-empty
- mail through the product's SES identity in `DEVELOPER` mode

**No mail texts live here.** Each product passes its own `custom_message`
Lambda (or a `custom_email_sender`) that renders through its own mail layout.

### Inputs

| Name | Default | Notes |
| --- | --- | --- |
| `project_name` | required | e.g. `huetabig-prod`; pool `<project_name>-users`, client `<project_name>-web` |
| `pool_name` | `null` | only for an existing pool with another name; the name forces replacement |
| `domain_name` | required | passkey relying party, e.g. `huetabig.ch` |
| `first_auth_factors` | all three | subset of `PASSWORD`, `EMAIL_OTP`, `WEB_AUTHN` (Cognito always keeps `PASSWORD` in the pool policy; leaving it out removes the password flows from the client) |
| `email_source_arn` | `null` | SES identity ARN; may be null only with `custom_email_sender_lambda_arn` |
| `from_email_address`, `reply_to_email_address` | `null` | |
| `pre_sign_up_lambda_arn`, `post_confirmation_lambda_arn`, `post_authentication_lambda_arn`, `custom_message_lambda_arn` | `null` | unqualified function ARNs; the module adds each `aws_lambda_permission` |
| `custom_email_sender_lambda_arn` + `custom_email_sender_kms_key_arn` | `null` | set both or neither |
| `social_identity_providers` | `[]` | e.g. `["SignInWithApple"]`; each must already exist in the pool |
| `callback_urls`, `logout_urls` | `[]` | |
| `groups` | `{}` | `name => { description, precedence }` |
| `access_token_validity_minutes` | `60` | also the ID token |
| `refresh_token_validity_days` | `30` | |
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
  source = "git::https://github.com/aksuyek/aws-modules.git//cognito?ref=v1.0.0"

  project_name       = local.project_name # futbolmetre-prod
  domain_name        = var.domain_name    # futbolmetre.com
  first_auth_factors = ["PASSWORD", "EMAIL_OTP", "WEB_AUTHN"]

  email_source_arn       = module.ses.domain_identity_arn
  from_email_address     = "Futbolmetre <no-reply@${var.domain_name}>"
  reply_to_email_address = "support@${var.domain_name}"

  pre_sign_up_lambda_arn    = aws_lambda_function.account_linking.arn # now in the FM root
  social_identity_providers = ["SignInWithApple"]

  callback_urls = ["https://${var.domain_name}/auth/callback", "futbolmetre://auth/callback"]
  logout_urls   = ["https://${var.domain_name}/", "futbolmetre://"]

  groups = {
    admins = { description = "Futbolmetre production administrators", precedence = 1 }
  }

  custom_domain                 = local.auth_domain
  custom_domain_certificate_arn = module.auth_certificate.certificate_arn

  tags = local.tags
}
```

#### Ziffli (eu-central-2, Zurich, custom email sender)

```hcl
module "cognito" {
  source = "git::https://github.com/aksuyek/aws-modules.git//cognito?ref=v1.0.0"

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
}
```

#### Hüetabig (eu-central-1)

```hcl
module "cognito" {
  source = "git::https://github.com/aksuyek/aws-modules.git//cognito?ref=v1.0.0"

  project_name       = "huetabig-prod"
  domain_name        = "huetabig.ch"
  first_auth_factors = ["EMAIL_OTP", "WEB_AUTHN", "PASSWORD"]

  email_source_arn       = aws_sesv2_email_identity.domain.arn
  from_email_address     = "Hüetabig <no-reply@huetabig.ch>"
  reply_to_email_address = "hallo@huetabig.ch"

  custom_message_lambda_arn    = aws_lambda_function.cognito_message.arn
  post_confirmation_lambda_arn = aws_lambda_function.cognito_post_confirmation.arn

  tags = local.tags
}
```

#### Weinquiz (eu-central-1)

```hcl
module "cognito" {
  source = "git::https://github.com/aksuyek/aws-modules.git//cognito?ref=v1.0.0"

  project_name       = "weinquiz-prod"
  domain_name        = "weinquiz.ch"
  first_auth_factors = ["EMAIL_OTP", "WEB_AUTHN", "PASSWORD"]

  email_source_arn       = aws_sesv2_email_identity.domain.arn
  from_email_address     = "Weinquiz <no-reply@weinquiz.ch>"
  reply_to_email_address = "hallo@weinquiz.ch"

  custom_message_lambda_arn = aws_lambda_function.cognito_message.arn

  tags = local.tags
}
```

#### Skiboard (eu-central-1)

```hcl
module "cognito" {
  source = "git::https://github.com/aksuyek/aws-modules.git//cognito?ref=v1.0.0"

  project_name       = "skiboard-prod"
  domain_name        = "skiboard.ch"
  first_auth_factors = ["EMAIL_OTP", "PASSWORD"]

  email_source_arn       = aws_sesv2_email_identity.domain.arn
  from_email_address     = "Skiboard <no-reply@skiboard.ch>"
  reply_to_email_address = "hallo@skiboard.ch"

  custom_message_lambda_arn = aws_lambda_function.cognito_message.arn

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
  from = module.cognito.aws_route53_record.auth_custom_domain[0]
  to   = aws_route53_record.auth_custom_domain # alias to module.cognito.auth_domain_cloudfront_distribution
}
# The account-linking Lambda, its role, policy, attachment and log group move
# to the root the same way (module.cognito.<addr> -> <addr>).
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
