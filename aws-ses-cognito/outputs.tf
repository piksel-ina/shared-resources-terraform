output "identity_arn" {
  description = "ARN of the SES domain identity (Cognito email_configuration.source_arn)"
  value       = aws_sesv2_email_identity.this.arn
}

output "configuration_set_name" {
  description = "SES configuration set name (Cognito email_configuration.configuration_set)"
  value       = aws_sesv2_configuration_set.this.configuration_set_name
}

output "events_topic_arn" {
  description = "SNS topic receiving SES problem events and reputation alarms"
  value       = aws_sns_topic.ses_events.arn
}
