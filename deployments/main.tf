locals {
  staging_account_id = "326641642924"
  dev_account_id     = "236122835646"
}


# --- Route 53 Setup ---

# Route 53 Hosted Zones
module "zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 3.0"

  zones = {
    "staging.pik-sel.id" = {
      comment = "staging.pik-sel.id"
      tags = {
        Environment = "staging"
      }
    },
    "pik-sel.id" = {
      comment = "pik-sel.id main domain"
      tags = {
        Environment = "production"
      }
    },
    "piksel.big.go.id" = {
      comment = "piksel.big.go.id main domain"
      tags = {
        Environment = "production"
      }
    },
    "staging.piksel.big.go.id" = {
      comment = "piksel.big.go.id staging domain"
      tags = {
        Environment = "staging"
      }
    }
  }

  tags = merge(var.default_tags, {
    ManagedBy = "Terraform"
  })
}

# Create NS record in parent domain for staging subdomain
module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  version = "~> 3.0"

  zone_id = module.zones.route53_zone_zone_id["pik-sel.id"]

  records = [
    {
      name    = "staging"
      type    = "NS"
      ttl     = 300
      records = module.zones.route53_zone_name_servers["staging.pik-sel.id"]
    }
  ]
  depends_on = [module.zones]
}

# Create NS record in parent domain for staging subdomain in piksel.big.go.id
module "records_staging_big" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  version = "~> 3.0"

  zone_id = module.zones.route53_zone_zone_id["piksel.big.go.id"]

  records = [
    {
      name    = "staging"
      type    = "NS"
      ttl     = 300
      records = module.zones.route53_zone_name_servers["staging.piksel.big.go.id"]
    }
  ]

  depends_on = [module.zones]
}

# IRSA for ExternaDNS 
module "irsa-externaldns" {
  source = "../external-dns-irsa"

  zone_ids    = module.zones.route53_zone_zone_id
  project     = var.project
  environment = var.environment
  cross_account_configs = [
    {
      env                  = "staging"
      account_id           = local.staging_account_id
      namespace            = "external-dns"
      service_account_name = "external-dns-sa"
      hosted_zone_names    = ["staging.pik-sel.id", "staging.piksel.big.go.id"]
    }
  ]
}

# --- ECR Setup ---

data "aws_caller_identity" "current" {}

# AWS ECR
module "ecr" {
  source             = "../aws-ecr"
  project            = var.project
  current_account_id = data.aws_caller_identity.current.account_id

  ecr_repos = {
    "piksel-core"     = { keep_last = 8 }
    "inadc-core"      = { cached = true }
    "data-production" = {}
    "coastlines"      = { is_mutable = true }
    "terriamap"       = {}
    "ows"             = { cached = true }
    "dc-explorer"     = {}
    "jupyter-lab"     = { cached = true }
    "jupyter-dev"     = { cached = true }
  }

  github_org = "piksel-ina"

  account_ids = {
    "dev"     = local.dev_account_id
    "staging" = local.staging_account_id
  }

  default_tags = var.default_tags
}

# --- Cognito Setup ---

# ACM Certificate for Cognito Custom Domain (Must be in us-east-1)
resource "aws_acm_certificate" "cognito_certificate" {
  provider          = aws.us_east_1
  domain_name       = var.auth_domain
  validation_method = "DNS"

  tags = merge(var.default_tags, {
    Name = "cognito-auth-domain-cert"
  })
}

# DNS Validation Record for ACM
resource "aws_route53_record" "cognito_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cognito_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = module.zones.route53_zone_zone_id["piksel.big.go.id"]
}

# ACM Certificate Validation
resource "aws_acm_certificate_validation" "cognito_cert" {
  region                  = "us-east-1"
  certificate_arn         = aws_acm_certificate.cognito_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.cognito_cert_validation : record.fqdn]
}

# Placeholder A record
resource "aws_route53_record" "piksel_root" {
  zone_id = module.zones.route53_zone_zone_id["piksel.big.go.id"]
  name    = "piksel.big.go.id"
  type    = "A"
  ttl     = 300
  records = ["127.0.0.1"]
}

# Cognito User Pool Module
module "cognito_user_pool" {
  source = "../aws-cognito-user-pool"

  user_pool_name  = "piksel-users"
  domain          = var.auth_domain
  certificate_arn = aws_acm_certificate.cognito_certificate.arn

  clients = [
    {
      name                 = "argo-workflows-staging"
      allowed_oauth_flows  = ["code"]
      allowed_oauth_scopes = ["email", "openid", "profile"]
      callback_urls        = ["https://argo.staging.piksel.big.go.id/oauth2/callback"]
      logout_urls          = ["https://argo.staging.piksel.big.go.id/"]
      generate_secret      = true

    },
    {
      name                 = "jupyterhub-staging"
      allowed_oauth_flows  = ["code"]
      allowed_oauth_scopes = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]
      callback_urls        = ["https://sandbox.staging.piksel.big.go.id/hub/oauth_callback"]
      logout_urls          = ["https://sandbox.staging.piksel.big.go.id/"]
      generate_secret      = true
    },
    {
      name                 = "grafana-staging"
      allowed_oauth_flows  = ["code"]
      allowed_oauth_scopes = ["email", "openid", "profile"]
      callback_urls        = ["https://grafana.staging.piksel.big.go.id/login/generic_oauth"]
      logout_urls          = ["https://grafana.staging.piksel.big.go.id/"]
      generate_secret      = true
    }
  ]

  default_tags = var.default_tags

  depends_on = [aws_route53_record.piksel_root]
}

# DNS Record for Custom Domain (Alias to CloudFront)
resource "aws_route53_record" "cognito_auth_domain" {
  zone_id = module.zones.route53_zone_zone_id["piksel.big.go.id"]
  name    = var.auth_domain
  type    = "A"

  alias {
    name                   = module.cognito_user_pool.domain_cloud_front_domain
    zone_id                = module.cognito_user_pool.domain_cloud_front_zone_id
    evaluate_target_health = false
  }
}
