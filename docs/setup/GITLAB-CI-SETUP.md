# GitLab CI/CD Setup Guide

Complete guide for setting up GitLab CI/CD pipelines for the NixOS Kubernetes Infrastructure project.

## Table of Contents

- [Prerequisites](#prerequisites)
- [AWS Authentication Setup](#aws-authentication-setup)
- [GitLab CI/CD Variables](#gitlab-cicd-variables)
- [Pipeline Configuration](#pipeline-configuration)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- GitLab project with CI/CD enabled
- AWS account with appropriate permissions
- GitLab Runner configured (tagged as `homelab`)
- AWS CLI installed locally for setup

## AWS Authentication Setup

### Automated Setup (Recommended)

Use the provided automation script:

```bash
# Run the IAM setup script
./scripts/setup-gitlab-aws-iam.sh
```

This script will:
- Create a dedicated `gitlab-terraform-ci` IAM user
- Set up minimal S3 permissions for Terraform state
- Generate access keys for GitLab variables
- Provide the exact credentials to add to GitLab

### Manual Setup

If you prefer manual setup:

1. **Create IAM User:**
   ```bash
   aws iam create-user --user-name gitlab-terraform-ci
   ```

2. **Create Policy:**
   ```bash
   aws iam create-policy --policy-name TerraformS3StateAccess --policy-document '{
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
               "Resource": "arn:aws:s3:::stetter-k8s-infra-terraform-state/*"
           },
           {
               "Effect": "Allow",
               "Action": "s3:ListBucket", 
               "Resource": "arn:aws:s3:::stetter-k8s-infra-terraform-state"
           }
       ]
   }'
   ```

3. **Attach Policy:**
   ```bash
   aws iam attach-user-policy --user-name gitlab-terraform-ci --policy-arn arn:aws:iam::ACCOUNT_ID:policy/TerraformS3StateAccess
   ```

4. **Create Access Key:**
   ```bash
   aws iam create-access-key --user-name gitlab-terraform-ci
   ```

## GitLab CI/CD Variables

Configure these variables in your GitLab project:

**Path:** Project Settings → CI/CD → Variables

### Required Variables

| Variable Name | Value | Protected | Masked | Description |
|---------------|-------|-----------|---------|-------------|
| `AWS_ACCESS_KEY_ID` | `AKIA...` | ✅ | ✅ | AWS access key from setup |
| `AWS_SECRET_ACCESS_KEY` | `xyz...` | ✅ | ✅ | AWS secret key from setup |
| `AWS_DEFAULT_REGION` | `us-east-2` | ✅ | ❌ | AWS region for S3 bucket |

### Variable Configuration Best Practices

#### Protected Variables
- **Enable** for all sensitive variables
- Only available to protected branches/tags
- Prevents exposure in fork MRs

#### Masked Variables
- **Enable** for secrets (access keys, tokens)
- GitLab will mask these values in job logs
- **Disable** for non-sensitive values (regions, bucket names)

#### Variable Scopes
- Use **Environment scopes** for different environments
- Example: `production` for main branch, `staging` for develop

## Pipeline Configuration

### Current Pipeline Structure

```yaml
stages:
  - validate    # Terraform validation and formatting
  - plan       # Generate and save Terraform plan
  - deploy     # Apply infrastructure changes (manual)
  - destroy    # Destroy infrastructure (manual)
```

### Key Features

1. **Terraform State Management:**
   - Uses S3 backend configured in `terraform/backend.tf`
   - State file: `s3://stetter-k8s-infra-terraform-state/k8s-infra/dev/terraform.tfstate`

2. **Plan Artifacts:**
   - Plans saved as artifacts for review
   - Expires after 1 week
   - Applied exactly as planned (no drift)

3. **Manual Deployments:**
   - Apply and destroy jobs require manual approval
   - Prevents accidental infrastructure changes

4. **NixOS Integration:**
   - ISO generation from NixOS configurations
   - Proxmox template creation
   - Phase 2 validation

### Pipeline Triggers

| Job | Trigger | When |
|-----|---------|------|
| `tf:validate` | MR + Main | Automatic |
| `tf:plan` | MR + Main | Automatic |
| `tf:apply` | Main only | Manual |
| `tf:destroy` | Main only | Manual |
| `nixos:generate-isos` | Main only | Manual |

## Security Best Practices

### 1. Least Privilege Access

- Dedicated IAM user for CI/CD only
- Minimal S3 permissions (no admin access)
- Regular credential rotation (recommended: 90 days)

### 2. Variable Protection

```yaml
# ✅ Good: Protected and masked sensitive variables
AWS_SECRET_ACCESS_KEY: [PROTECTED] [MASKED]
AWS_ACCESS_KEY_ID: [PROTECTED] [MASKED]

# ✅ Good: Protected but not masked (not secret)
AWS_DEFAULT_REGION: [PROTECTED] [NOT MASKED]

# ❌ Bad: Unprotected sensitive variables
DATABASE_PASSWORD: [NOT PROTECTED] [MASKED]  # Exposed in forks!
```

### 3. Branch Protection

- Enable branch protection on main/production branches
- Require MR approvals for sensitive changes
- Use protected environments for production deployments

### 4. Audit and Monitoring

- Review CI/CD job logs regularly
- Monitor AWS CloudTrail for unexpected API calls
- Set up alerts for failed Terraform operations

### 5. Secret Management

- Never commit secrets to Git
- Use GitLab CI/CD variables for all secrets
- Consider external secret management (HashiCorp Vault, AWS Secrets Manager)

## Troubleshooting

### Common Issues

#### 1. AWS Authentication Failures

**Error:** `NoCredentialsError: Unable to locate credentials`

**Solutions:**
- Verify GitLab variables are set correctly
- Check variable names match exactly (case-sensitive)
- Ensure variables are not masked if used in script logic
- Verify IAM user has correct permissions

#### 2. Terraform State Lock Issues

**Error:** `Error acquiring the state lock`

**Solutions:**
```bash
# Check for stuck locks in DynamoDB (if using)
aws dynamodb scan --table-name terraform-locks

# Force unlock (use carefully)
terraform force-unlock LOCK_ID
```

#### 3. S3 Access Denied

**Error:** `AccessDenied: Access Denied`

**Solutions:**
- Verify S3 bucket name in backend configuration
- Check IAM policy permissions
- Ensure bucket exists and is in correct region

#### 4. Runner Connection Issues

**Error:** `This job is stuck because you don't have any active runners`

**Solutions:**
- Verify GitLab Runner is running and registered
- Check runner tags match job requirements (`homelab`)
- Review runner logs for connection issues

### Debug Mode

Enable debug logging by setting in GitLab variables:
```
TF_LOG: DEBUG
```

### Getting Help

1. Check GitLab CI/CD job logs
2. Review AWS CloudTrail logs
3. Validate Terraform configuration locally
4. Test runner connectivity

## Related Documentation

- [S3 and DynamoDB Setup](./S3-DYNAMODB-SETUP.md)
- [Proxmox API Setup](./PROXMOX-API-SETUP.md)
- [NixOS Template Setup](./NIXOS-TEMPLATE-SETUP.md)
- [Testing Plan](./TESTING-PLAN.md)

## Automation Scripts

- `scripts/setup-gitlab-aws-iam.sh` - AWS IAM user setup
- `scripts/validate-phase2.sh` - Pipeline validation
- `scripts/generate-nixos-isos.sh` - ISO generation
- `scripts/create-proxmox-templates.sh` - Template creation