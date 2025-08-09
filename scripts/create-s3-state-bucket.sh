# Set variables
export PROJECT_NAME="homelab-proxmox-iac"
export AWS_REGION="us-east-2"  # Change to your preferred region
export S3_BUCKET_NAME="stetter-${PROJECT_NAME}-tf-state"
export DYNAMODB_TABLE_NAME="${PROJECT_NAME}-tf-locks"

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

# Create DynamoDB table for state locking
echo "Creating DynamoDB table for state locking: $DYNAMODB_TABLE_NAME"
aws dynamodb create-table \
    --table-name $DYNAMODB_TABLE_NAME \
    --attribute-definitions \
        AttributeName=LockID,AttributeType=S \
    --key-schema \
        AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput \
        ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region $AWS_REGION

# Wait for table to be active
echo "Waiting for DynamoDB table to become active..."
aws dynamodb wait table-exists --table-name $DYNAMODB_TABLE_NAME --region $AWS_REGION

echo "DynamoDB table created successfully: $DYNAMODB_TABLE_NAME"
echo ""
echo "✅ Terraform backend setup complete!"
echo "   S3 Bucket: $S3_BUCKET_NAME"  
echo "   DynamoDB Table: $DYNAMODB_TABLE_NAME"
echo "   Region: $AWS_REGION"
