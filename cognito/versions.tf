terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 5.83.0 added user_pool_tier, sign_in_policy and web_authn_configuration.
      version = ">= 5.83.0, < 6.0.0"
    }
  }
}
