resource "aws_cognito_user_pool" "this" {
  name = var.user_pool_name

  alias_attributes         = ["email", "preferred_username"]
  auto_verified_attributes = ["email"]

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = false
    name                     = "email"
    required                 = true
    string_attribute_constraints {
      min_length = 1
      max_length = 2048
    }
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "phone_number"
    required                 = true
    string_attribute_constraints {
      min_length = 8
      max_length = 15
    }
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Verifikasi Akun PIKSEL / PIKSEL Account Verification"
    email_message        = file("${path.module}/config/email-verification.html")
  }

  admin_create_user_config {
    allow_admin_create_user_only = true
    invite_message_template {
      email_subject = "Undangan Akun PIKSEL / PIKSEL Account Invitation"
      email_message = file("${path.module}/config/email-invite.html")
      sms_message   = "[PIKSEL] Halo {username}, kata sandi sementara Anda: {####}. Jangan bagikan kode ini."
    }
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }

    recovery_mechanism {
      name     = "verified_phone_number"
      priority = 2
    }
  }

  deletion_protection = "ACTIVE"

  tags = var.default_tags
}

resource "aws_cognito_user_pool_client" "this" {
  for_each = { for client in var.clients : client.name => client }

  name         = each.value.name
  user_pool_id = aws_cognito_user_pool.this.id

  allowed_oauth_flows                  = each.value.allowed_oauth_flows
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = each.value.allowed_oauth_scopes
  callback_urls                        = each.value.callback_urls
  logout_urls                          = each.value.logout_urls
  supported_identity_providers         = ["COGNITO"]
  explicit_auth_flows                  = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]

  access_token_validity  = lookup(each.value, "access_token_validity", 720)
  id_token_validity      = lookup(each.value, "id_token_validity", 720)
  refresh_token_validity = lookup(each.value, "refresh_token_validity", 30)

  token_validity_units {
    access_token  = lookup(each.value, "access_token_unit", "minutes")
    id_token      = lookup(each.value, "id_token_unit", "minutes")
    refresh_token = lookup(each.value, "refresh_token_unit", "days")
  }

  generate_secret = lookup(each.value, "generate_secret", false)
}

resource "aws_cognito_user_pool_domain" "this" {
  count                 = var.domain != "" ? 1 : 0
  domain                = var.domain
  certificate_arn       = var.certificate_arn
  user_pool_id          = aws_cognito_user_pool.this.id
  managed_login_version = 2
}

# Admin Group
resource "aws_cognito_user_group" "admin" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Administrator group with full access"

}

# Coastline Group
resource "aws_cognito_user_group" "coastline" {
  name         = "coastline"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Data Access: EFS /data/coastlines"
}

# Moderate Users Group
resource "aws_cognito_user_group" "moderate_users" {
  name         = "moderate-users"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Unlock jupyter medium instance"
}

# Power Users Group
resource "aws_cognito_user_group" "power_users" {
  name         = "power-users"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Unlock jupyter large instance"
}

# Argo User Group
resource "aws_cognito_user_group" "argo_user" {
  name         = "argo-user"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Argo Workflows data-production user"
}

