#!/bin/bash

# Setup Terraform Backend for ComfyUI AWS Deployment
# This script creates S3 bucket and DynamoDB table for Terraform state management

set -e

# Configuration
BUCKET_NAME="comfyui-terraform-state-$(date +%s)"
DYNAMODB_TABLE="comfyui-terraform-locks"
AWS_REGION="eu-central-1"

echo "🚀 Setting up Terraform backend infrastructure..."
echo "Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo "Region: $AWS_REGION"

# Create S3 bucket for Terraform state
echo "📦 Creating S3 bucket for Terraform state..."
aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION"

# Enable versioning on the bucket
echo "📝 Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

# Enable server-side encryption
echo "🔒 Enabling server-side encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'

# Block public access
echo "🛡️ Blocking public access..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create DynamoDB table for state locking
echo "🔐 Creating DynamoDB table for state locking..."
aws dynamodb create-table \
    --table-name "$DYNAMODB_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region "$AWS_REGION"

# Wait for table to be active
echo "⏳ Waiting for DynamoDB table to be active..."
aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"

echo ""
echo "✅ Terraform backend setup completed!"
echo ""
echo "📋 Add these to your GitHub Secrets:"
echo "TERRAFORM_STATE_BUCKET=$BUCKET_NAME"
echo ""
echo "🔧 Backend configuration:"
echo "bucket = \"$BUCKET_NAME\""
echo "key    = \"comfyui-golden-image/terraform.tfstate\""
echo "region = \"$AWS_REGION\""
echo "dynamodb_table = \"$DYNAMODB_TABLE\""
echo ""
echo "🚀 You can now run Terraform with remote state!" 