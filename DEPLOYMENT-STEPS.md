# 🚀 ComfyUI AWS Deployment Guide

## 🎯 Overview
This guide provides a systematic approach to deploying and managing ComfyUI on AWS with proper cleanup procedures to prevent account pollution.

## 🚀 Initial Setup (One-time)

### 1. Setup Terraform Backend
```bash
# Make script executable
chmod +x setup-terraform-backend.sh

# Run setup (will create S3 bucket and DynamoDB table)
./setup-terraform-backend.sh
```

This will output a bucket name like `comfyui-terraform-state-1640995200`. **Save this for GitHub Secrets.**

### 2. Configure GitHub Secrets
Add these secrets to your GitHub repository:
- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key  
- `TERRAFORM_STATE_BUCKET`: The bucket name from step 1

### 3. IAM Policy
Apply the corrected IAM policy from `aws-iam-policy.json` to your AWS user/role.

## 📋 Deployment Process

### Option A: Automatic Deployment (Recommended)
1. Push to `feature/aws-deployment` branch
2. GitHub Actions automatically deploys infrastructure
3. Monitor progress in Actions tab

### Option B: Manual Deployment
```bash
cd terraform
terraform init \
  -backend-config="bucket=YOUR_BUCKET_NAME" \
  -backend-config="key=comfyui-golden-image/terraform.tfstate" \
  -backend-config="region=eu-central-1"

terraform plan -var="environment=test"
terraform apply
```

## 🧹 Cleanup Process (CRITICAL)

### When Deployment Fails
**ALWAYS clean up before retrying deployment!**

#### Option A: Automated Cleanup (Recommended)
1. Go to GitHub Actions → "AWS Infrastructure Destroy"
2. Click "Run workflow"
3. Select environment (test/dev/prod)
4. Type "DESTROY" to confirm
5. Run workflow

#### Option B: Manual Cleanup
```bash
cd terraform
terraform destroy -var="environment=test"

# Clean up any orphaned resources
./manual-cleanup.sh test
```

### Manual Cleanup Script
Create `manual-cleanup.sh`:
```bash
#!/bin/bash
ENV=${1:-test}

echo "🧹 Cleaning up orphaned resources for environment: $ENV"

# IAM Roles
for role in comfyui-golden-image-$ENV-ecs-task-execution-role \
           comfyui-golden-image-$ENV-ecs-task-role \
           comfyui-golden-image-$ENV-ecs-instance-role \
           comfyui-golden-image-$ENV-user-manager-task-role; do
  echo "Cleaning role: $role"
  aws iam detach-role-policy --role-name "$role" --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>/dev/null
  aws iam delete-role --role-name "$role" 2>/dev/null
done

# ECR Repositories
aws ecr delete-repository --repository-name comfyui-golden-image-$ENV-app --force 2>/dev/null
aws ecr delete-repository --repository-name comfyui-golden-image-$ENV-user-manager --force 2>/dev/null

# CloudWatch Logs
aws logs delete-log-group --log-group-name /ecs/comfyui-golden-image-$ENV 2>/dev/null

# Release unassociated EIPs
aws ec2 describe-addresses --query 'Addresses[?AssociationId==null].AllocationId' --output text | \
while read allocation_id; do
  if [ ! -z "$allocation_id" ]; then
    aws ec2 release-address --allocation-id "$allocation_id" 2>/dev/null
  fi
done

echo "✅ Cleanup completed"
```

## 🔄 Deployment Workflow

### Successful Deployment
```
1. Push code → 2. GitHub Actions → 3. Infrastructure created → 4. Applications deployed
```

### Failed Deployment  
```
1. Deployment fails → 2. Run destroy workflow → 3. Fix issues → 4. Retry deployment
```

**NEVER skip step 2!** This prevents resource conflicts and AWS account pollution.

## 📊 Resource Limits to Monitor

| Resource | Limit | Current Usage Check |
|----------|-------|-------------------|
| VPCs | 5 per region | `aws ec2 describe-vpcs --query 'length(Vpcs[])'` |
| EIPs | 5 per region | `aws ec2 describe-addresses --query 'length(Addresses[])'` |
| ECR repos | 10,000 | `aws ecr describe-repositories --query 'length(repositories[])'` |

## 🛠️ Troubleshooting

### Common Issues

#### "VPC Limit Exceeded"
```bash
# Check current VPC count
aws ec2 describe-vpcs --query 'length(Vpcs[])'

# If at limit (5), delete unused VPCs or run destroy workflow
```

#### "Address Limit Exceeded" 
```bash
# Release unassociated EIPs
aws ec2 describe-addresses --query 'Addresses[?AssociationId==null].AllocationId' --output text | \
while read allocation_id; do
  aws ec2 release-address --allocation-id "$allocation_id"
done
```

#### "IAM Role Already Exists"
```bash
# Always run destroy workflow before retrying deployment
```

## 🔒 Security Best Practices

1. **Use least privilege IAM policies** (provided in `aws-iam-policy.json`)
2. **Enable Terraform state encryption** (automatically configured)
3. **Use remote state backend** (S3 + DynamoDB locking)
4. **Regular cleanup** after failed deployments
5. **Monitor resource usage** to stay within limits

## 📈 Monitoring & Maintenance

### Health Checks
- GitHub Actions include automatic health checks
- Load balancer health checks monitor service status
- CloudWatch monitors resource usage

### Cost Optimization
- Use Spot instances for non-critical workloads
- Enable S3 lifecycle policies for model storage
- Monitor CloudWatch costs and set billing alerts

## 🎯 Environment Management

### Multiple Environments
- `test`: Development and testing
- `dev`: Staging environment  
- `prod`: Production deployment

Each environment is isolated with separate:
- VPCs and networking
- ECS clusters
- S3 buckets
- IAM roles

### Environment Switching
```bash
# Deploy to different environment
terraform apply -var="environment=dev"

# Destroy specific environment
terraform destroy -var="environment=dev"
```

## 📞 Support

If you encounter issues:
1. Check GitHub Actions logs
2. Verify AWS resource limits
3. Run destroy workflow to clean up
4. Check IAM permissions
5. Review Terraform state consistency

## 📋 Prerequisites

- ✅ AWS Account with **specific permissions** (see [AWS-IAM-SETUP.md](AWS-IAM-SETUP.md))
- ✅ AWS CLI installed and configured
- ✅ Terraform installed (v1.0+)
- ✅ Docker installed (for local testing)
- ✅ Git repository access

> **💡 Tip:** You don't need full admin privileges! See [AWS-IAM-SETUP.md](AWS-IAM-SETUP.md) for minimal required permissions.

## 🔧 Step 1: AWS Credentials Setup

> **🔐 Important:** First set up IAM permissions! See [AWS-IAM-SETUP.md](AWS-IAM-SETUP.md) for detailed guide.

### Option A: AWS CLI Configuration
```bash
aws configure
# Enter your AWS Access Key ID (from IAM User)
# Enter your AWS Secret Access Key (from IAM User)
# Default region: eu-central-1
# Default output format: json
```

### Option B: Environment Variables
```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="eu-central-1"
```

### Verify AWS Access
```bash
aws sts get-caller-identity
# Should return your User ARN, not root account
```

## 🗄️ Step 2: Setup Terraform Backend

Run the backend setup script:
```bash
chmod +x setup-terraform-backend.sh
./setup-terraform-backend.sh
```

This will create:
- ✅ S3 bucket for Terraform state
- ✅ DynamoDB table for state locking
- ✅ Display backend configuration

## 📝 Step 3: Update Terraform Backend Configuration

Update `terraform/main.tf` with the backend configuration from Step 2:

```hcl
terraform {
  backend "s3" {
    bucket         = "comfyui-golden-image-terraform-state-XXXXXXXXX"
    key            = "comfyui/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "comfyui-golden-image-terraform-locks"
    encrypt        = true
  }
}
```

## ⚙️ Step 4: Configure Deployment

Review and modify `terraform/terraform.tfvars`:

```hcl
# Basic settings
aws_region   = "eu-central-1"
project_name = "comfyui-golden-image"
environment  = "dev"

# GPU Configuration
gpu_instance_type = "g4dn.xlarge"  # NVIDIA T4 16GB
enable_gpu_sharing = true          # 2 containers per GPU
containers_per_gpu = 2             # Cost optimization
```

## 🚀 Step 5: Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Plan deployment (review changes)
terraform plan

# Apply deployment
terraform apply
```

**Expected deployment time: 10-15 minutes**

## 🐋 Step 6: Build and Push Docker Images

### ComfyUI Image
```bash
# Get ECR login
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <your-account-id>.dkr.ecr.eu-central-1.amazonaws.com

# Build and push ComfyUI image
docker build -f aws-Dockerfile -t <your-account-id>.dkr.ecr.eu-central-1.amazonaws.com/comfyui-golden-image-dev:latest .
docker push <your-account-id>.dkr.ecr.eu-central-1.amazonaws.com/comfyui-golden-image-dev:latest
```

### User Manager Image
```bash
# Build and push User Manager image
cd user-manager
docker build -t <your-account-id>.dkr.ecr.eu-central-1.amazonaws.com/comfyui-golden-image-dev-user-manager:latest .
docker push <your-account-id>.dkr.ecr.eu-central-1.amazonaws.com/comfyui-golden-image-dev-user-manager:latest
cd ..
```

## 🔄 Step 7: Update ECS Services

```bash
# Update Admin service
aws ecs update-service \
  --cluster comfyui-golden-image-dev-cluster \
  --service comfyui-golden-image-dev-admin-service \
  --force-new-deployment

# Update User service
aws ecs update-service \
  --cluster comfyui-golden-image-dev-cluster \
  --service comfyui-golden-image-dev-user-service \
  --force-new-deployment

# Update User Manager service
aws ecs update-service \
  --cluster comfyui-golden-image-dev-cluster \
  --service comfyui-golden-image-dev-user-manager-service \
  --force-new-deployment
```

## 🔍 Step 8: Verify Deployment

### Get Load Balancer URL
```bash
aws elbv2 describe-load-balancers \
  --names comfyui-golden-image-dev-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text
```

### Test Endpoints
```bash
ALB_DNS="your-alb-dns-name"

# Test Admin ComfyUI
curl -I http://$ALB_DNS/admin/

# Test User Manager
curl -I http://$ALB_DNS/manager/

# Test User ComfyUI
curl -I http://$ALB_DNS/user/
```

## 🎯 Step 9: Access Your Deployment

### Admin ComfyUI
```
http://your-alb-dns/admin/
```

### User Manager (Create/Delete User Environments)
```
http://your-alb-dns/manager/
```

### User ComfyUI Instances
```
http://your-alb-dns/user/
```

## 📊 Step 10: Monitor Deployment

### CloudWatch Logs
```bash
# View ECS logs
aws logs describe-log-groups --log-group-name-prefix /ecs/comfyui

# Stream logs
aws logs tail /ecs/comfyui-golden-image-dev --follow
```

### ECS Console
- Go to AWS ECS Console
- Select `comfyui-golden-image-dev-cluster`
- Monitor services and tasks

### GPU Monitoring
- CloudWatch Metrics → Custom Namespaces → `AWS/ECS/GPU`
- Monitor GPU utilization, memory, temperature

## 💰 Cost Monitoring

### Expected Monthly Costs (dev environment):
- **1x g4dn.xlarge GPU instance**: ~$380/month
- **2x User containers** (shared GPU): ~$190/month per user
- **1x Admin container**: ~$190/month
- **Infrastructure** (ALB, S3, etc.): ~$55/month
- **Total baseline**: ~$625/month

### Cost Optimization:
- GPU instances scale to 0 when not used
- Enable Spot instances for 50-70% savings
- Use S3 lifecycle policies for model storage

## 🛠️ Troubleshooting

### Common Issues:

1. **GPU instances not starting**
   - Check GPU instance limits in AWS
   - Verify g4dn.xlarge availability in your region

2. **Docker image pull failures**
   - Ensure ECR repositories exist
   - Check IAM permissions for ECS task execution

3. **Load balancer health checks failing**
   - Wait 5-10 minutes for services to stabilize
   - Check CloudWatch logs for container errors

4. **GPU sharing not working**
   - Verify NVIDIA MPS is running on instances
   - Check container GPU memory limits

### Support Commands:
```bash
# Check ECS service status
aws ecs describe-services --cluster comfyui-golden-image-dev-cluster --services comfyui-golden-image-dev-admin-service

# Check task health
aws ecs describe-tasks --cluster comfyui-golden-image-dev-cluster --tasks $(aws ecs list-tasks --cluster comfyui-golden-image-dev-cluster --query 'taskArns[0]' --output text)

# Check GPU instance status
aws ec2 describe-instances --filters "Name=tag:Name,Values=comfyui-golden-image-dev-gpu-ecs-instance"
```

## 🔄 GitHub Actions Alternative

If you prefer automated deployment, set up GitHub Secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `TERRAFORM_STATE_BUCKET`
- `TERRAFORM_LOCK_TABLE`

Then push to `feature/aws-deployment` branch to trigger automatic deployment.

## 🎉 Success!

Your ComfyUI deployment is now running with:
- ✅ GPU-accelerated containers (NVIDIA T4)
- ✅ Auto-scaling user environments
- ✅ Web-based user management
- ✅ S3 model storage with intelligent caching
- ✅ Production-ready monitoring and logging

Happy generating! 🎨 