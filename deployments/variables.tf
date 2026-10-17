# --- Common Variables ---
variable "project" {
  description = "The name of the project"
  type        = string
  default     = "Piksel"
}

variable "environment" {
  description = "The environment of the deployment"
  type        = string
  default     = "shared"
}

variable "aws_region" {
  description = "Region to deploy resources in"
  type        = string
  default     = "ap-southeast-3"
}

variable "default_tags" {
  description = "A map of default tags to apply to all AWS resources"
  type        = map(string)
  default = {
    "Terraform"   = true
    "Project"     = "Piksel"
    "Service"     = "pik-sel.id"
    "Owner"       = "Piksel-Devops-Team"
    "Environment" = "shared"
  }
}


# --- VPC Configuration Variables ---
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to use for subnets"
  type        = number
  default     = 2
}

# --- NAT Gateway Configuration ---
variable "single_nat_gateway" {
  description = "Enable a single NAT Gateway for all private subnets (cheaper, less availability)"
  type        = bool
  default     = true
}

variable "one_nat_gateway_per_az" {
  description = "Enable one NAT Gateway per Availability Zone (higher availability, higher cost)"
  type        = bool
  default     = false
}

# --- VPC Flow Logs Configuration ---
variable "enable_flow_log" {
  description = "Enable VPC Flow Logs for monitoring network traffic"
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Retention period for VPC Flow Logs in CloudWatch (in days)"
  type        = number
  default     = 90
}

# --- Cognito Configuration ---
variable "auth_domain" {
  description = "The domain to use for Cognito Hosted UI"
  type        = string
  default     = "oauth.piksel.big.go.id"
}

variable "website_cloudfront_domain_name" {
  description = "CloudFront domain serving the production website; null keeps the pre-cutover placeholder"
  type        = string
  default     = "d3gi2an0j9pzay.cloudfront.net"
  nullable    = true

  validation {
    condition     = var.website_cloudfront_domain_name == null || endswith(var.website_cloudfront_domain_name, ".cloudfront.net")
    error_message = "website_cloudfront_domain_name must be null or an AWS CloudFront domain name."
  }
}
