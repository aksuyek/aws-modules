output "user_pool_id" {
  description = "Cognito user pool ID."
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "Cognito user pool ARN."
  value       = aws_cognito_user_pool.this.arn
}

output "client_id" {
  description = "ID of the public web/app client (no secret)."
  value       = aws_cognito_user_pool_client.web.id
}

output "issuer_url" {
  description = "Token issuer (iss claim), for JWT authorizers."
  value       = "https://${aws_cognito_user_pool.this.endpoint}"
}

output "jwks_url" {
  description = "JSON Web Key Set URL for verifying tokens."
  value       = "https://${aws_cognito_user_pool.this.endpoint}/.well-known/jwks.json"
}

output "auth_domain" {
  description = "Hosted auth hostname, or null when no domain is configured."
  value = (
    var.custom_domain != null ? var.custom_domain :
    var.domain_prefix != null ? "${var.domain_prefix}.auth.${split("_", aws_cognito_user_pool.this.id)[0]}.amazoncognito.com" :
    null
  )
}

output "auth_domain_cloudfront_distribution" {
  description = "CloudFront target for a custom_domain DNS alias (hosted zone Z2FDTNDATAQYW2), or null."
  value       = var.custom_domain != null ? aws_cognito_user_pool_domain.this[0].cloudfront_distribution : null
}

output "group_names" {
  description = "Names of the groups created in the pool."
  value       = [for g in aws_cognito_user_group.this : g.name]
}
