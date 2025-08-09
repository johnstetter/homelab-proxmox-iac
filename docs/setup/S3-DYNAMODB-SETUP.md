# S3 + DynamoDB Setup Guide for Terraform State Backend

This guide provides step-by-step instructions for setting up AWS S3 and DynamoDB for Terraform remote state management with security best practices.

## 🎯 Overview

Terraform remote state backend using AWS provides:
- **State locking** via DynamoDB to prevent concurrent modifications
- **State storage** in S3 with versioning and encryption
- **Collaboration** across team members and CI/CD systems
- **Backup and recovery** with S3 versioning and cross-region replication

## 🔧 Prerequisites

- AWS CLI installed and configured
- Terraform >= 1.0 installed
- Appropriate AWS permissions (see IAM section below)

## 🏗️ Step 1: Create S3 Bucket for State Storage

### Create S3 Bucket
```bash
# Set variables
export PROJECT_NAME="k8s-infra"
export AWS_REGION="us-east-1"  # Change to your preferred region
export S3_BUCKET_NAME="${PROJECT_NAME}-terraform-state-$(date +%s)"

# Create the S3 bucket
aws s3api create-bucket \
    --bucket $S3_BUCKET_NAME \
    --region $AWS_REGION

# Enable versioning for backup/rollback
aws s3api put-bucket-versioning \
    --bucket $S3_BUCKET_NAME \
    --versioning-configuration Status=Enabled

# Enable server-side encryption
aws s3api put-bucket-encryption \
    --bucket $S3_BUCKET_NAME \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'

# Block public access (security best practice)
aws s3api put-public-access-block \
    --bucket $S3_BUCKET_NAME \
    --public-access-block-configuration \
        BlockPublicAcls=true,\
        IgnorePublicAcls=true,\
        BlockPublicPolicy=true,\
        RestrictPublicBuckets=true
```

### Configure Lifecycle Policy (Optional)
```bash
# Create lifecycle policy to manage old versions
cat > lifecycle-policy.json <<EOF
{
    "Rules": [
        {
            "ID": "DeleteOldVersions",
            "Status": "Enabled",
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 90
            },
            "AbortIncompleteMultipartUpload": {
                "DaysAfterInitiation": 1
            }
        }
    ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
    --bucket $S3_BUCKET_NAME \
    --lifecycle-configuration file://lifecycle-policy.json

rm lifecycle-policy.json
```

## 🗄️ Step 2: Create DynamoDB Table for State Locking

### Create DynamoDB Table
```bash
# Create DynamoDB table for state locking
export DYNAMODB_TABLE_NAME="${PROJECT_NAME}-terraform-locks"

aws dynamodb create-table \
    --table-name $DYNAMODB_TABLE_NAME \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region $AWS_REGION

# Wait for table to be created
aws dynamodb wait table-exists \
    --table-name $DYNAMODB_TABLE_NAME \
    --region $AWS_REGION

echo "DynamoDB table created successfully"
```

### Enable Point-in-Time Recovery (Optional)
```bash
# Enable point-in-time recovery for additional backup
aws dynamodb put-continuous-backups \
    --table-name $DYNAMODB_TABLE_NAME \
    --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true
```

## 🔐 Step 3: IAM Policy and User Setup

### Create IAM Policy
```bash
# Create IAM policy for Terraform backend access
cat > terraform-backend-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::$S3_BUCKET_NAME",
                "arn:aws:s3:::$S3_BUCKET_NAME/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem",
                "dynamodb:DescribeTable"
            ],
            "Resource": "arn:aws:dynamodb:$AWS_REGION:*:table/$DYNAMODB_TABLE_NAME"
        }
    ]
}
EOF

# Create the policy
aws iam create-policy \
    --policy-name TerraformBackendPolicy \
    --policy-document file://terraform-backend-policy.json

# Get your AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

rm terraform-backend-policy.json
```

### Create IAM User (for CI/CD)
```bash
# Create IAM user for Terraform operations
export IAM_USER_NAME="terraform-backend-user"

aws iam create-user --user-name $IAM_USER_NAME

# Attach policy to user
aws iam attach-user-policy \
    --user-name $IAM_USER_NAME \
    --policy-arn "arn:aws:iam::$AWS_ACCOUNT_ID:policy/TerraformBackendPolicy"

# Create access keys
aws iam create-access-key --user-name $IAM_USER_NAME
```

**⚠️ Important**: Save the access key and secret key from the output above. You'll need them for GitLab CI/CD variables.

## 🔧 Step 4: Configure Terraform Backend

### Update backend.tf
```hcl
# terraform/backend.tf
terraform {
  backend "s3" {
    bucket         = "k8s-infra-terraform-state-1234567890"  # Replace with your bucket name
    key            = "k8s-infra/terraform.tfstate"
    region         = "us-east-1"  # Replace with your region
    dynamodb_table = "k8s-infra-terraform-locks"  # Replace with your table name
    encrypt        = true
  }
}
```

### Initialize Terraform with Backend
```bash
cd terraform/

# Initialize Terraform with the new backend
terraform init

# If migrating from local state, Terraform will ask to copy the state
# Answer 'yes' to migrate your existing state to S3
```

## 🚀 Step 5: GitLab CI/CD Configuration

### Set GitLab CI/CD Variables
In your GitLab project, go to **Settings > CI/CD > Variables** and add:

```
AWS_ACCESS_KEY_ID: <access-key-from-step-3>
AWS_SECRET_ACCESS_KEY: <secret-key-from-step-3>
AWS_DEFAULT_REGION: us-east-1
TF_VAR_proxmox_api_url: https://your-proxmox:8006/api2/json
TF_VAR_proxmox_api_token: your-token-id=your-token-secret
```

### Update GitLab CI Pipeline
```yaml
# .gitlab-ci.yml
variables:
  TF_ROOT: "${CI_PROJECT_DIR}/terraform"
  TF_STATE_NAME: "${CI_PROJECT_NAME}"
  AWS_DEFAULT_REGION: "us-east-1"

default:
  image: hashicorp/terraform:1.6.0
  before_script:
    - cd ${TF_ROOT}
    - terraform init
```

## 🔍 Step 6: Verification and Testing

### Test Backend Configuration
```bash
# Test that backend is working
cd terraform/
terraform plan

# Check state location
terraform state list

# Verify state is in S3
aws s3 ls s3://$S3_BUCKET_NAME/k8s-infra/

# Check DynamoDB for locks (should be empty when not running)
aws dynamodb scan --table-name $DYNAMODB_TABLE_NAME
```

### Test State Locking
```bash
# In one terminal, run a long-running operation
terraform plan -lock-timeout=10s

# In another terminal, try to run terraform (should fail due to lock)
terraform plan -lock-timeout=5s
```

## 🔐 Security Best Practices

### 1. Least Privilege Access
- Use separate IAM users for different environments
- Limit S3 bucket access to specific prefixes
- Use IAM roles instead of users when possible

### 2. Encryption
- Enable S3 bucket encryption (AES256 or KMS)
- Use KMS customer-managed keys for additional security
- Enable encryption in transit

### 3. Monitoring and Auditing
```bash
# Enable CloudTrail for API logging
aws cloudtrail create-trail \
    --name terraform-backend-trail \
    --s3-bucket-name your-cloudtrail-bucket

# Enable S3 access logging
aws s3api put-bucket-logging \
    --bucket $S3_BUCKET_NAME \
    --bucket-logging-status '{
        "LoggingEnabled": {
            "TargetBucket": "your-access-logs-bucket",
            "TargetPrefix": "terraform-state-logs/"
        }
    }'
```

### 4. Backup Strategy
- Enable S3 versioning (already configured above)
- Set up cross-region replication for critical states
- Regular backups of DynamoDB table

## 🛠️ Troubleshooting

### Common Issues

**Error: "NoSuchBucket"**
```bash
# Verify bucket exists and you have access
aws s3 ls s3://$S3_BUCKET_NAME
```

**Error: "ResourceNotFoundException" (DynamoDB)**
```bash
# Check if table exists
aws dynamodb describe-table --table-name $DYNAMODB_TABLE_NAME
```

**Error: "AccessDenied"**
```bash
# Verify IAM permissions
aws iam get-user-policy --user-name $IAM_USER_NAME --policy-name TerraformBackendPolicy
```

### Cleanup (if needed)
```bash
# Delete DynamoDB table
aws dynamodb delete-table --table-name $DYNAMODB_TABLE_NAME

# Delete S3 bucket (must be empty first)
aws s3 rm s3://$S3_BUCKET_NAME --recursive
aws s3api delete-bucket --bucket $S3_BUCKET_NAME

# Delete IAM user
aws iam detach-user-policy --user-name $IAM_USER_NAME --policy-arn "arn:aws:iam::$AWS_ACCOUNT_ID:policy/TerraformBackendPolicy"
aws iam delete-user --user-name $IAM_USER_NAME
aws iam delete-policy --policy-arn "arn:aws:iam::$AWS_ACCOUNT_ID:policy/TerraformBackendPolicy"
```

## 📚 Additional Resources

- [Terraform S3 Backend Documentation](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [AWS S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)

---

**Next Steps**: After completing this setup, update your `terraform/backend.tf` with the actual bucket and table names, then run `terraform init` to migrate your state to the remote backend.