# Piksel-Hub

Terraform configuration for shared AWS resources across multiple accounts.

## Overview

**piksel-hub** manages centralized resources in a shared AWS account that serve multiple workload accounts (Staging and Production). This setup follows a multi-account architecture pattern where common services are centralized to reduce duplication and simplify management.

### Architecture

The infrastructure consists of:

- **Shared Account**: Hosts centralized resources (this repository)
- **Workload Accounts**: Staging and Production environments that consume shared resources 👉🏻 **[piksel-infra repo](https://github.com/piksel-ina/piksel-infra)**

<img src=".images/multi_account-setup.png" width="800" height="auto">

## Shared Resources

### 1. Route53 DNS Management (Steps 1-3)

Centralized DNS configuration for all environments.

**Components:**

- **Hosted Zones**: Public DNS zones for public domains (e.g. `pik-sel.id`, `sandbox.pik-sel.id`)
- **Name Server**: Manages DNS records for all accounts
- **External DNS Integration**: Delegates to Route53 name servers from external DNS provider

**How it works:**

- (1) External DNS server (office) delegates DNS management to Route53
- (2) Route53 hosts public DNS zones
- (3) Workload accounts update DNS records as needed

**Benefits:**

- Single source of truth for DNS
- Automatic DNS record updates from Kubernetes
- Consistent domain management across environments

### 2. Elastic Container Registry (Steps 4-7)

Shared Docker image repository accessible by all workload accounts.

**Components:**

- **ECR Repository**: Stores container images (e.g. `piksel/odc:v1.0`, `piksel/jupyter:v1.0`)
- **Cross-Account IAM Policy**: Grants pull access to workload accounts
- **Private Subnets**: Worker nodes in workload accounts pull images via NAT Gateway

**How it works:**

- (4) ECR repository stores Docker images in shared account
- (5) Workload accounts assume IAM role with ECR pull permissions
- (6) NAT Gateway routes traffic from private subnets to ECR
- (7) Worker nodes pull images from shared ECR

**Benefits:**

- Single image repository for all environments
- No image duplication across accounts
- Centralized image scanning and vulnerability management
- Reduced storage costs

#### ECR Build Cache

Repos with `cached = true` get a companion `-cache` repo for Docker build caching in GitHub Actions.

```yaml
# .github/workflows/build.yml (example for ows)
- uses: aws-actions/amazon-ecr-login@v2
  id: ecr

- uses: docker/setup-buildx-action@v3

- run: |
    docker buildx build \
      --cache-from type=registry,ref=${{ secrets.ECR_REGISTRY }}/ows-cache:buildcache \
      --cache-to type=registry,ref=${{ secrets.ECR_REGISTRY }}/ows-cache:buildcache,mode=max \
      --push \
      -t ${{ secrets.ECR_REGISTRY }}/ows:${{ github.sha }} .
```

### 3. AWS Cognito SSO (Steps 8-11)

Centralized authentication service enabling Single Sign-On across all applications.

**Components:**

- **User Pool**: Central user directory
- **App Clients**: Application 1 and Application 2 configurations
- **SSO Session Management**: Maintains authentication state across apps
- **Secrets Manager**: Stores client credentials in each workload account

**How it works:**

- (8) Cognito User Pool manages user authentication
- (9) App client credentials stored in AWS Secrets Manager (per account)
- (10) Applications read credentials and initiate authentication flow
- (11) Users log in once and access all applications seamlessly

**Authentication Flow:**

```
User → Login (App 1) → Cognito → SSO Session Created
User → Access App 2 → Cognito (session exists) → Automatic Login ✓
```

**Benefits:**

- Single login for multiple applications
- Centralized user management
- Consistent authentication across environments
- Improved security with MFA support

## This Repository

### Infrastructure As Code with Terraform

Honestly, these resources don't really need Terraform since most of them are one-time operations. But I just like using it because:

- It's easier to get an overview of what's provisioned
- Removing and adding resources is just one `terraform apply` away
- It keeps things organized and documented in code

> 🗒️NOTE 1: **I use Local Backend Workflow**
>
> I'm using local backend because it's flexible, quick, cheap, and simple. I'm still managing this alone, so there's no need for the complexity of remote state locking. I just upload the state file to an S3 bucket as backup.

---

> 🗒️NOTE 2: **No Terraform for Cognnito**
>
> I don't use Terraform for managing Cognito because I'm going to need the AWS Console anyway to manage users and design beautiful sign-in pages. It just makes more sense to configure it manually.

### Directories

```
piksel-hub/
├── LICENSE
├── README.md
├── aws-ecr/                 # ECR setup
├── aws-s3-static-hosting/   # To be deployed
├── deployments/             # Main configuration files, calling up the modules
│                            # Route53 is directly configured here
└── external-dns-irsa/       # IAM role setup to be assumed by IRSA in workload accounts

```

### Backup

As I'm not utilizing remote backend, I need to backup. I use a simple mechanism: just upload the tfstate and other files to an S3 bucket.

**Read more about backup: [Terraform State Backup](https://github.com/piksel-ina/piksel-hub/blob/main/deployments/README.md#terraform-state-backup)**
