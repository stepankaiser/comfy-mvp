# 🚀 ComfyUI AWS Deployment Guide

Complete step-by-step guide to deploy ComfyUI with GPU support to AWS.

## 📋 Prerequisites

- ✅ AWS Account with admin privileges
- ✅ AWS CLI installed and configured
- ✅ Terraform installed (v1.0+)
- ✅ Docker installed (for local testing)
- ✅ Git repository access

## 🔧 Step 1: AWS Credentials Setup

### Option A: AWS CLI Configuration
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
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