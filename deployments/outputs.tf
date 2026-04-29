# --- Account Information ---
output "account_info" {
  description = "AWS Account information"
  value = {
    current = data.aws_caller_identity.current.account_id
    dev     = local.dev_account_id
    staging = local.staging_account_id
  }
}

# --- Route53 Zones (All Zones) ---
output "route53_zones" {
  description = "All Route53 zones information"
  value = {
    zone_ids     = module.zones.route53_zone_zone_id
    zone_arns    = module.zones.route53_zone_zone_arn
    name_servers = module.zones.route53_zone_name_servers
  }
}

# --- Route53 Zones (pik-sel.id domain) ---
output "piksel_id_zones" {
  description = "Route53 zones for pik-sel.id domain"
  value = {
    production = {
      zone_id      = module.zones.route53_zone_zone_id["pik-sel.id"]
      name_servers = module.zones.route53_zone_name_servers["pik-sel.id"]
      domain       = "pik-sel.id"
    }
    staging = {
      zone_id      = module.zones.route53_zone_zone_id["staging.pik-sel.id"]
      name_servers = module.zones.route53_zone_name_servers["staging.pik-sel.id"]
      domain       = "staging.pik-sel.id"
    }
  }
}

# --- Route53 Zones (piksel.big.go.id domain) ---
output "piksel_big_go_id_zones" {
  description = "Route53 zones for piksel.big.go.id domain - Delegate name servers to big.go.id"
  value = {
    production = {
      zone_id      = module.zones.route53_zone_zone_id["piksel.big.go.id"]
      name_servers = module.zones.route53_zone_name_servers["piksel.big.go.id"]
      domain       = "piksel.big.go.id"
    }
    staging = {
      zone_id      = module.zones.route53_zone_zone_id["staging.piksel.big.go.id"]
      name_servers = module.zones.route53_zone_name_servers["staging.piksel.big.go.id"]
      domain       = "staging.piksel.big.go.id"
    }
  }
}

# --- ExternalDNS IRSA ---
output "externaldns_irsa" {
  description = "ExternalDNS IRSA cross-account configuration"
  value = {
    role_arns            = module.irsa-externaldns.externaldns_crossaccount_role_arns
    route53_policy_arns  = module.irsa-externaldns.cross_account_route53_policy_policy_arns
    cloudfront_role_arns = module.irsa-externaldns.odc_cloudfront_crossaccount_role_arns
  }
}

# --- ECR Repository ---
output "ecr_repositories" {
  description = "ECR repositories information"
  value = {
    for repo_name in keys(module.ecr.ecr_repository_names) : repo_name => {
      name = module.ecr.ecr_repository_names[repo_name]
      arn  = module.ecr.ecr_repository_arns[repo_name]
      url  = module.ecr.ecr_repository_urls[repo_name]
    }
  }
}

output "ecr_cache_repositories" {
  description = "ECR cache repositories information (key = original repo name)"
  value       = module.ecr.ecr_cache_repository_urls
}

# --- IAM Roles ---
output "iam_roles" {
  description = "IAM roles for various services"
  value = {
    github_actions       = module.ecr.github_actions_role_arn
    eks_ecr_access       = module.ecr.eks_ecr_access_role_arn
    github_oidc_provider = module.ecr.github_oidc_provider_arn
  }
}

# --- Delegation Instructions (Human-readable) ---
output "delegation_instructions" {
  description = "NS records to delegate to parent domains"
  value = {
    "piksel.big.go.id" = {
      message      = "Contact big.go.id administrator to create NS records"
      parent_zone  = "big.go.id"
      record_name  = "piksel"
      record_type  = "NS"
      name_servers = module.zones.route53_zone_name_servers["piksel.big.go.id"]
    }
    "staging.piksel.big.go.id" = {
      message      = "Automatically delegated within piksel.big.go.id zone"
      parent_zone  = "piksel.big.go.id"
      record_name  = "staging"
      record_type  = "NS"
      name_servers = module.zones.route53_zone_name_servers["staging.piksel.big.go.id"]
    }
  }
}

# --- Cognito User Pool ---
output "cognito_user_pool_id" {
  description = "The ID of the Cognito User Pool"
  value       = module.cognito_user_pool.user_pool_id
}

output "cognito_user_pool_endpoint" {
  description = "The Endpoint of the Cognito User Pool"
  value       = module.cognito_user_pool.user_pool_endpoint
}

output "cognito_client_ids" {
  description = "Map of Cognito Client Name to Client ID"
  value       = module.cognito_user_pool.client_ids
}
