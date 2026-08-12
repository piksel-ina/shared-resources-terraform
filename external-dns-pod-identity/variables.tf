variable "environment" {
  description = "Workload environment allowed to use the target role"
  type        = string
}

variable "workload_account_id" {
  description = "AWS account ID containing the EKS cluster and Pod Identity source role"
  type        = string
}

variable "source_role_arn" {
  description = "ARN of the EKS Pod Identity role allowed to assume the target role"
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the EKS cluster allowed to request target-role credentials"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace allowed to request target-role credentials"
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes service account allowed to request target-role credentials"
  type        = string
}

variable "hosted_zone_ids" {
  description = "Route53 hosted zone IDs the target role can manage"
  type        = list(string)
}

variable "default_tags" {
  description = "Tags applied to the IAM role and policy"
  type        = map(string)
  default     = {}
}
