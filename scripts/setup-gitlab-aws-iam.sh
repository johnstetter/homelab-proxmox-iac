#!/usr/bin/env bash
#
# Setup AWS IAM user for GitLab CI/CD Terraform operations
#
# This script creates a dedicated IAM user with minimal permissions
# for Terraform state management in S3.
#
# Usage: ./setup-gitlab-aws-iam.sh
#

set -euo pipefail

# Configuration
IAM_USER="gitlab-terraform-ci"
POLICY_NAME="TerraformS3StateAccess"
S3_BUCKET="stetter-homelab-proxmox-iac-tf-state"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get AWS account ID
get_account_id() {
    aws sts get-caller-identity --query Account --output text
}

main() {
    log_info "Setting up AWS IAM user for GitLab CI/CD..."
    
    # Get account ID
    ACCOUNT_ID=$(get_account_id)
    log_info "AWS Account ID: $ACCOUNT_ID"
    
    # Check if user already exists
    if aws iam get-user --user-name "$IAM_USER" &>/dev/null; then
        log_warn "IAM user '$IAM_USER' already exists"
    else
        log_info "Creating IAM user: $IAM_USER"
        aws iam create-user --user-name "$IAM_USER"
    fi
    
    # Create policy document
    POLICY_DOC=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::${S3_BUCKET}/*"
        },
        {
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::${S3_BUCKET}"
        }
    ]
}
EOF
)
    
    # Create policy
    POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
    if aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
        log_warn "Policy '$POLICY_NAME' already exists"
    else
        log_info "Creating IAM policy: $POLICY_NAME"
        aws iam create-policy \
            --policy-name "$POLICY_NAME" \
            --policy-document "$POLICY_DOC"
    fi
    
    # Attach policy to user
    log_info "Attaching policy to user..."
    aws iam attach-user-policy \
        --user-name "$IAM_USER" \
        --policy-arn "$POLICY_ARN"
    
    # Create access key
    log_info "Creating access key..."
    ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name "$IAM_USER")
    
    # Extract credentials
    ACCESS_KEY_ID=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.AccessKeyId')
    SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.SecretAccessKey')
    
    # Display results
    echo
    log_info "✅ Setup complete! Add these variables to GitLab CI/CD settings:"
    echo
    echo "Project Settings → CI/CD → Variables (mark as Protected and Masked):"
    echo
    echo "AWS_ACCESS_KEY_ID: $ACCESS_KEY_ID"
    echo "AWS_SECRET_ACCESS_KEY: $SECRET_ACCESS_KEY"
    echo "AWS_DEFAULT_REGION: us-east-2"
    echo
    log_warn "⚠️  Store these credentials securely - they cannot be retrieved again!"
    echo
}

# Check dependencies
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is required but not installed"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &>/dev/null; then
    log_error "AWS credentials not configured or invalid"
    exit 1
fi

main "$@"