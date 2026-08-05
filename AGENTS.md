# AGENTS.md

## Commands
Run from the repository root.

| Task | Command | Notes |
|---|---|---|
| Check formatting | `terraform fmt -recursive -check -diff` | Non-mutating; checks every Terraform directory. |
| Format Terraform | `make fmt` | Formats every `.tf` file recursively. |
| Validate shared deployment | `make validate` | Validates `deployments/` and the modules it calls. |

## Configuration boundaries
- The Makefile defaults `dir` to `deployments/`; it accepts a `dir` override for other Terraform roots.
- `deployments/main.tf` is the shared deployment composition root. It calls `aws-ecr/`, `aws-cognito-user-pool/`, and `external-dns-irsa/`.
- `aws-s3-static-hosting/` is not called from `deployments/` and currently does not validate as a standalone root. Resolve its undeclared Route53 data source and logging-bucket output before treating it as deployable.
- `aws-cognito-user-pool/config/` contains the HTML templates loaded by the Cognito user-pool resource.

## State and apply
- Terraform state is local and ignored by Git. Preserve that policy.
- The Makefile’s apply target runs `deployments/backup.sh` after a successful apply. Preserve this backup step when changing the apply workflow.
- Do not run apply or destroy without explicit confirmation.

## Conventions
- Use `jsonencode()` for IAM policies; see `aws-ecr/main.tf` and `external-dns-irsa/main.tf`.
- Use the `us_east_1` provider alias for ACM certificates used by Cognito or CloudFront; see `deployments/providers.tf`.

## Current validation blocker
- `make dir=aws-s3-static-hosting validate` fails because `aws-s3-static-hosting/main.tf` references `data.aws_route53_zone.main` without declaring it, and `aws-s3-static-hosting/outputs.tf` references an undeclared `aws_s3_bucket.docs_logs`.
