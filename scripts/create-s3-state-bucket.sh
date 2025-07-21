# Set variables
export PROJECT_NAME="k8s-infra"
export AWS_REGION="us-east-2"  # Change to your preferred region
export S3_BUCKET_NAME="stetter-${PROJECT_NAME}-terraform-state"

# Create the S3 bucket with proper location constraint
if [ "$AWS_REGION" = "us-east-1" ]; then
    aws s3api create-bucket \
        --bucket $S3_BUCKET_NAME \
        --region $AWS_REGION
else
    aws s3api create-bucket \
        --bucket $S3_BUCKET_NAME \
        --region $AWS_REGION \
        --create-bucket-configuration LocationConstraint=$AWS_REGION
fi

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
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "S3 bucket created successfully: $S3_BUCKET_NAME"
