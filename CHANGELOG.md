# Changelog

All notable changes to these modules. Versions are git tags; callers pin them
with `?ref=`.

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
