# Changelog

All notable changes to these modules. Versions are git tags; callers pin them
with `?ref=`.

## v1.1.0 - 2026-11-28

### cognito

Additive: every new input defaults to v1.0.0's behaviour, so callers on
v1.0.0 can bump `?ref=` with no plan change. The inputs let Futbolmetre
(FM-021) and Ziffli (ZF-018) move onto the module and keep their live pool and
client settings.

- `prevent_user_existence_errors` (default `"ENABLED"`; Ziffli `"LEGACY"`).
- `password_policy` object (default the NIST rule: 10 characters, no classes).
- `explicit_auth_flows` override (default null = the computed list).
- `oauth_scopes` (default `aws.cognito.signin.user.admin`, `email`, `openid`, `profile`).
- `auth_session_validity_minutes` (default 15).
- `token_validity_units` (default minutes/minutes/days). Lifetimes stay in
  minutes and days and are converted to these units; `null` writes no
  lifetimes or units (Futbolmetre, where they were never set).
- `lambda_permission_condition` (default `"source_arn"`; `"source_account"`
  keeps Futbolmetre's existing permissions from being replaced).
- README: the `custom_message` permission's `moved` block for Futbolmetre,
  and the examples for Futbolmetre and Ziffli pass their live settings.

## v1.0.0 - 2026-11-27

### cognito

- First release, lifted from Futbolmetre's `infra/terraform/modules/cognito`
  (AK-002). One user pool per product.
- Fixed: email username, deletion protection ACTIVE plus `prevent_destroy`,
  Essentials tier, email-only recovery, 10-character password policy without
  character classes, public client without secret, token revocation,
  `prevent_user_existence_errors = "ENABLED"`, `ALLOW_USER_AUTH` +
  `ALLOW_REFRESH_TOKEN_AUTH` (+ password/SRP flows when `PASSWORD` is a factor),
  SES developer-mode mail.
- Inputs for first factors, SES identity and headers, the pre sign-up, post
  confirmation, post authentication, custom message and custom email sender
  triggers (with their Lambda permissions), social providers, OAuth URLs,
  groups, token validity, hosted or custom domain, `username_case_sensitive`
  (set false on new pools) and tags. Empty-string trigger ARNs count as unset.
- Outputs: `user_pool_id`, `user_pool_arn`, `client_id`, `issuer_url`,
  `jwks_url`, `auth_domain`, `auth_domain_cloudfront_distribution`, `group_names`.
- Moved out of the module, into Futbolmetre: the account-linking Lambda, the
  Turkish verification texts, the `admins` group description and the
  `support@` Reply-To.
