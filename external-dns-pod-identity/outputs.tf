output "role_arn" {
  description = "ARN of the ExternalDNS Pod Identity target role"
  value       = aws_iam_role.this.arn
}

output "policy_arn" {
  description = "ARN of the Route53 policy attached to the target role"
  value       = aws_iam_policy.this.arn
}
