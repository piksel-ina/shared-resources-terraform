variable "domain" {
  description = "Domain verified in SES and used as the From domain"
  type        = string
}

variable "mail_from_subdomain" {
  description = "Subdomain of var.domain used as the custom MAIL FROM (bounce) domain"
  type        = string
  default     = "bounces"
}

variable "zone_id" {
  description = "Route53 hosted zone ID for var.domain"
  type        = string
}

variable "user_pool_arn" {
  description = "ARN of the Cognito user pool allowed to send from the identity"
  type        = string
}

variable "configuration_set_name" {
  description = "Name of the SES configuration set"
  type        = string
  default     = "piksel-cognito"
}

variable "notification_email" {
  description = "Email address subscribed to SES bounce/complaint events and alarms"
  type        = string
}

variable "dmarc_policy" {
  description = "DMARC policy for var.domain (none, quarantine, reject)"
  type        = string
  default     = "quarantine"

  validation {
    condition     = contains(["none", "quarantine", "reject"], var.dmarc_policy)
    error_message = "dmarc_policy must be none, quarantine or reject."
  }
}

variable "bounce_rate_threshold" {
  description = "Alarm when the SES account bounce rate exceeds this fraction"
  type        = number
  default     = 0.05
}

variable "complaint_rate_threshold" {
  description = "Alarm when the SES account complaint rate exceeds this fraction"
  type        = number
  default     = 0.001
}

variable "default_tags" {
  description = "Tags applied to taggable resources"
  type        = map(string)
  default     = {}
}
