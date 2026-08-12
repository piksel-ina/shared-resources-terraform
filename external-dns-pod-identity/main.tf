resource "aws_iam_role" "this" {
  name = "externaldns-pod-identity-target-role-${lower(var.environment)}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.workload_account_id}:root"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Condition = {
          ArnEquals = {
            "aws:PrincipalARN" = var.source_role_arn
          }
          StringEquals = {
            "aws:RequestTag/eks-cluster-arn"            = var.cluster_arn
            "aws:RequestTag/kubernetes-namespace"       = var.namespace
            "aws:RequestTag/kubernetes-service-account" = var.service_account_name
          }
        }
      }
    ]
  })

  tags = var.default_tags
}

resource "aws_iam_policy" "this" {
  name        = "ExternalDNSPodIdentityRoute53Policy-${var.environment}"
  description = "Allow ExternalDNS from ${var.environment} to manage its Route53 hosted zones"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRoute53ListOperations"
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName",
          "route53:GetChange",
          "route53:GetHostedZoneCount"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowHostedZoneOperations"
        Effect = "Allow"
        Action = [
          "route53:GetHostedZone",
          "route53:ListResourceRecordSets",
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [
          for zone_id in var.hosted_zone_ids :
          "arn:aws:route53:::hostedzone/${zone_id}"
        ]
      },
      {
        Sid    = "AllowHealthCheckOperations"
        Effect = "Allow"
        Action = [
          "route53:CreateHealthCheck",
          "route53:DeleteHealthCheck",
          "route53:GetHealthCheck",
          "route53:ListHealthChecks",
          "route53:UpdateHealthCheck"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.default_tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}
