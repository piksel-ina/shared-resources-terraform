data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  mail_from_domain = "${var.mail_from_subdomain}.${var.domain}"
  account_id       = data.aws_caller_identity.current.account_id
  region           = data.aws_region.current.region
}

# --- SES identity ---

resource "aws_sesv2_configuration_set" "this" {
  configuration_set_name = var.configuration_set_name

  reputation_options {
    reputation_metrics_enabled = true
  }

  sending_options {
    sending_enabled = true
  }

  tags = var.default_tags
}

resource "aws_sesv2_email_identity" "this" {
  email_identity         = var.domain
  configuration_set_name = aws_sesv2_configuration_set.this.configuration_set_name

  dkim_signing_attributes {
    next_signing_key_length = "RSA_2048_BIT"
  }

  tags = var.default_tags
}

resource "aws_sesv2_email_identity_mail_from_attributes" "this" {
  email_identity         = aws_sesv2_email_identity.this.email_identity
  mail_from_domain       = local.mail_from_domain
  behavior_on_mx_failure = "USE_DEFAULT_VALUE"
}

resource "aws_sesv2_email_identity_policy" "cognito" {
  email_identity = aws_sesv2_email_identity.this.email_identity
  policy_name    = "cognito-user-pool"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCognitoUserPool"
        Effect    = "Allow"
        Principal = { Service = "cognito-idp.amazonaws.com" }
        Action    = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource  = aws_sesv2_email_identity.this.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
            "aws:SourceArn"     = var.user_pool_arn
          }
        }
      }
    ]
  })
}

# --- DNS ---

resource "aws_route53_record" "dkim" {
  count = 3

  zone_id = var.zone_id
  name    = "${aws_sesv2_email_identity.this.dkim_signing_attributes[0].tokens[count.index]}._domainkey.${var.domain}"
  type    = "CNAME"
  ttl     = 1800
  records = ["${aws_sesv2_email_identity.this.dkim_signing_attributes[0].tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "mail_from_mx" {
  zone_id = var.zone_id
  name    = local.mail_from_domain
  type    = "MX"
  ttl     = 1800
  records = ["10 feedback-smtp.${local.region}.amazonses.com"]
}

resource "aws_route53_record" "mail_from_spf" {
  zone_id = var.zone_id
  name    = local.mail_from_domain
  type    = "TXT"
  ttl     = 1800
  records = ["v=spf1 include:amazonses.com -all"]
}

resource "aws_route53_record" "domain_spf" {
  zone_id = var.zone_id
  name    = var.domain
  type    = "TXT"
  ttl     = 1800
  records = ["v=spf1 include:amazonses.com -all"]
}

resource "aws_route53_record" "dmarc" {
  zone_id = var.zone_id
  name    = "_dmarc.${var.domain}"
  type    = "TXT"
  ttl     = 1800
  records = ["v=DMARC1; p=${var.dmarc_policy}; rua=mailto:${var.notification_email}; fo=1"]
}

# --- Event notifications ---

resource "aws_sns_topic" "ses_events" {
  name = "${var.configuration_set_name}-ses-events"
  tags = var.default_tags
}

resource "aws_sns_topic_policy" "ses_events" {
  arn = aws_sns_topic.ses_events.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSESPublish"
        Effect    = "Allow"
        Principal = { Service = "ses.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.ses_events.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
            "AWS:SourceArn"     = aws_sesv2_configuration_set.this.arn
          }
        }
      },
      {
        Sid       = "AllowCloudWatchAlarms"
        Effect    = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.ses_events.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.ses_events.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_sesv2_configuration_set_event_destination" "sns" {
  configuration_set_name = aws_sesv2_configuration_set.this.configuration_set_name
  event_destination_name = "sns-problems"

  event_destination {
    enabled              = true
    matching_event_types = ["BOUNCE", "COMPLAINT", "DELIVERY_DELAY", "REJECT", "RENDERING_FAILURE"]

    sns_destination {
      topic_arn = aws_sns_topic.ses_events.arn
    }
  }

  depends_on = [aws_sns_topic_policy.ses_events]
}

# --- Reputation alarms ---

resource "aws_cloudwatch_metric_alarm" "bounce_rate" {
  alarm_name          = "${var.configuration_set_name}-ses-bounce-rate"
  alarm_description   = "SES account bounce rate above ${var.bounce_rate_threshold * 100}%"
  namespace           = "AWS/SES"
  metric_name         = "Reputation.BounceRate"
  statistic           = "Maximum"
  period              = 3600
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.bounce_rate_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.ses_events.arn]
  ok_actions          = [aws_sns_topic.ses_events.arn]
  tags                = var.default_tags
}

resource "aws_cloudwatch_metric_alarm" "complaint_rate" {
  alarm_name          = "${var.configuration_set_name}-ses-complaint-rate"
  alarm_description   = "SES account complaint rate above ${var.complaint_rate_threshold * 100}%"
  namespace           = "AWS/SES"
  metric_name         = "Reputation.ComplaintRate"
  statistic           = "Maximum"
  period              = 3600
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.complaint_rate_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.ses_events.arn]
  ok_actions          = [aws_sns_topic.ses_events.arn]
  tags                = var.default_tags
}
