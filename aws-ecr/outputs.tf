output "ecr_repository_names" {
  description = "Map of ECR repository names"
  value       = { for k, v in aws_ecr_repository.this : k => v.name }
}

output "ecr_repository_arns" {
  description = "Map of ECR repository ARNs"
  value       = { for k, v in aws_ecr_repository.this : k => v.arn }
}

output "ecr_repository_urls" {
  description = "Map of ECR repository URLs for Docker push/pull"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "ecr_cache_repository_urls" {
  description = "Map of ECR cache repository URLs (key = original repo name)"
  value       = { for k, v in aws_ecr_repository.cache : k => v.repository_url }
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

output "eks_ecr_access_role_arn" {
  description = "ARN of the IAM role for EKS ECR access"
  value       = aws_iam_role.eks_ecr_access.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the OIDC provider for GitHub Actions"
  value       = aws_iam_openid_connect_provider.github.arn
}