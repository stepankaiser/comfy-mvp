#!/bin/bash

# ComfyUI Terraform Backend Setup Script
# Creates S3 bucket and DynamoDB table for Terraform state management

set -e

PROJECT_NAME="comfyui-golden-image"
REGION="eu-central-1"
BUCKET_NAME="${PROJECT_NAME}-terraform-state-$(date +%s)"
DYNAMODB_TABLE="${PROJECT_NAME}-terraform-locks"

echo "🚀 Setting up Terraform backend for ComfyUI deployment..."
echo "Region: $REGION"
echo "Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE"

# Create S3 bucket for Terraform state
echo "📦 Creating S3 bucket..."
aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region $REGION \
    --create-bucket-configuration LocationConstraint=$REGION

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket $BUCKET_NAME \
    --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket $BUCKET_NAME \
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
aws s3api put-public-access-block \
    --bucket $BUCKET_NAME \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create DynamoDB table for state locking
echo "🔒 Creating DynamoDB table for state locking..."
aws dynamodb create-table \
    --table-name $DYNAMODB_TABLE \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region $REGION

# Wait for table to be created
echo "⏳ Waiting for DynamoDB table to be ready..."
aws dynamodb wait table-exists --table-name $DYNAMODB_TABLE --region $REGION

echo "✅ Terraform backend setup complete!"
echo ""
echo "📝 Update your terraform/main.tf backend configuration:"
echo ""
echo "terraform {"
echo "  backend \"s3\" {"
echo "    bucket         = \"$BUCKET_NAME\""
echo "    key            = \"comfyui/terraform.tfstate\""
echo "    region         = \"$REGION\""
echo "    dynamodb_table = \"$DYNAMODB_TABLE\""
echo "    encrypt        = true"
echo "  }"
echo "}"
echo ""
echo "🔑 Also set these GitHub Secrets:"
echo "AWS_ACCESS_KEY_ID: [your-access-key-id]"
echo "AWS_SECRET_ACCESS_KEY: [your-secret-access-key]"
echo "TERRAFORM_STATE_BUCKET: $BUCKET_NAME"
echo "TERRAFORM_LOCK_TABLE: $DYNAMODB_TABLE" 