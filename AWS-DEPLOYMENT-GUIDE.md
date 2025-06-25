# 🚀 AWS Deployment Guide - ComfyUI Golden Image System

Complete guide for deploying ComfyUI Golden Image system to AWS using ECS Fargate with intelligent S3 caching.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Manual Deployment](#manual-deployment)
- [Configuration](#configuration)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Cost Optimization](#cost-optimization)

## 🏗️ Architecture Overview

### High-Level Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   CloudFront    │────│  Application     │────│    ECS Fargate      │
│   (CDN/Cache)   │    │  Load Balancer   │    │   Auto Scaling      │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
                                │                         │
                                │                         │
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│      S3         │    │   ElastiCache    │    │  Local NVMe SSD     │
│ (Golden Image)  │    │   (Hot Cache)    │    │  (Working Cache)    │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
```

### Key Components

- **ECS Fargate**: Serverless container orchestration
- **Application Load Balancer**: High availability and routing
- **S3**: Centralized model storage with lifecycle management
- **Intelligent Caching**: Hot/Cold cache tiers with LRU eviction
- **Auto Scaling**: Automatic scaling based on CPU/Memory usage
- **CloudWatch**: Monitoring and alerting

### Performance Features

- **200GB NVMe Cache**: Ultra-fast local storage
- **Parallel Downloads**: 4-8 concurrent S3 streams
- **Background Prefetching**: Popular models preloaded
- **Smart Eviction**: LRU with usage analytics
- **Transfer Acceleration**: S3 optimized endpoints

## 📋 Prerequisites

### AWS Account Setup

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Terraform** >= 1.5.0 installed
4. **Docker** for local testing
5. **GitHub repository** for CI/CD

### Required AWS Permissions

Your AWS user/role needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:*",
        "ec2:*",
        "iam:*",
        "s3:*",
        "ecr:*",
        "elasticloadbalancing:*",
        "logs:*",
        "application-autoscaling:*",
        "cloudwatch:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### Terraform Backend Setup

Create S3 bucket for Terraform state:

```bash
aws s3 mb s3://your-terraform-state-bucket
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled
```

## 🚀 Quick Start

### 1. GitHub Secrets Setup

Add these secrets to your GitHub repository:

```bash
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
TERRAFORM_STATE_BUCKET=your-terraform-state-bucket
```

### 2. Automatic Deployment

Simply push to the `main` branch:

```bash
git checkout main
git pull origin main
git push origin main
```

The GitHub Actions workflow will:
- ✅ Deploy infrastructure with Terraform
- ✅ Build and push Docker image to ECR
- ✅ Deploy to ECS Fargate
- ✅ Run health checks and smoke tests

### 3. Access Your Deployment

After successful deployment, access:

- **Admin Interface**: `http://your-alb-dns-name/admin/`
- **User Interface**: `http://your-alb-dns-name/user/`
- **CloudWatch Dashboard**: AWS Console → CloudWatch → Dashboards

## 🔧 Manual Deployment

### Step 1: Clone and Setup

```bash
git clone https://github.com/your-username/ComfyUIWeb.git
cd ComfyUIWeb
git checkout feature/aws-deployment
```

### Step 2: Configure Terraform

```bash
cd terraform

# Initialize Terraform
terraform init \
  -backend-config="bucket=your-terraform-state-bucket" \
  -backend-config="key=comfyui-golden-image/terraform.tfstate" \
  -backend-config="region=eu-central-1"

# Plan deployment
terraform plan \
  -var="aws_region=eu-central-1" \
  -var="environment=prod" \
  -var="container_cpu=4096" \
  -var="container_memory=16384" \
  -var="ephemeral_storage=200"

# Apply infrastructure
terraform apply
```

### Step 3: Build and Push Docker Image

```bash
# Get ECR repository URL
ECR_URL=$(terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region eu-central-1 | \
  docker login --username AWS --password-stdin $ECR_URL

# Build and push image
docker build -f aws-Dockerfile -t $ECR_URL:latest .
docker push $ECR_URL:latest
```

### Step 4: Deploy ECS Services

```bash
# Update ECS services
aws ecs update-service \
  --cluster comfyui-golden-image-prod-cluster \
  --service comfyui-golden-image-prod-admin-service \
  --force-new-deployment

aws ecs update-service \
  --cluster comfyui-golden-image-prod-cluster \
  --service comfyui-golden-image-prod-user-service \
  --force-new-deployment
```

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `CONTAINER_ROLE` | Container role (admin/user) | user | ✅ |
| `S3_BUCKET_NAME` | S3 bucket for models | - | ✅ |
| `AWS_REGION` | AWS region | eu-central-1 | ✅ |
| `CACHE_SIZE_GB` | Local cache size in GB | 160 | ❌ |
| `CACHE_STRATEGY` | Caching strategy | intelligent | ❌ |

### Terraform Variables

```hcl
# terraform/terraform.tfvars
aws_region = "eu-central-1"
project_name = "comfyui-golden-image"
environment = "prod"
container_cpu = 4096      # 4 vCPU
container_memory = 16384  # 16 GB
ephemeral_storage = 200   # 200 GB
```

### Popular Models Configuration

Edit `aws-entrypoint.sh` to customize preloaded models:

```bash
POPULAR_MODELS=(
    "models/checkpoints/sd_xl_base_1.0.safetensors"
    "models/vae/sdxl_vae.safetensors"
    "models/loras/your_popular_lora.safetensors"
    # Add your most used models here
)
```

## 📊 Monitoring

### CloudWatch Dashboard

Access the auto-created dashboard:
1. Go to AWS Console → CloudWatch → Dashboards
2. Open `comfyui-golden-image-prod-dashboard`

Key metrics:
- **CPU/Memory Utilization**: ECS service performance
- **Request Count**: Load balancer traffic
- **Response Time**: Application performance
- **Error Rates**: 4xx/5xx responses

### Health Checks

Each container includes health monitoring:

```bash
# Check container health
docker exec -it container_id python3 /app/monitoring/health.py

# Sample output:
{
  "status": "healthy",
  "timestamp": 1703123456.789,
  "cache_usage_gb": 45.2,
  "hot_cache_usage_gb": 12.8,
  "memory_usage_percent": 67.5,
  "comfyui_running": true
}
```

### Cache Performance Monitoring

```python
# Get cache statistics
from scripts.cache_manager import get_cache_manager

manager = get_cache_manager()
stats = manager.get_cache_stats()
print(json.dumps(stats, indent=2))
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Container Startup Failures

**Symptoms**: ECS tasks keep stopping, health checks fail

**Solutions**:
```bash
# Check ECS logs
aws logs tail /ecs/comfyui-golden-image-prod --follow

# Common fixes:
# - Verify S3 bucket permissions
# - Check IAM role policies
# - Ensure ECR image exists
```

#### 2. S3 Connection Issues

**Symptoms**: "Cannot connect to S3 bucket" errors

**Solutions**:
```bash
# Test S3 access
aws s3 ls s3://your-bucket-name

# Check IAM permissions:
# - s3:GetObject, s3:PutObject, s3:ListBucket
# - Correct bucket name in environment variables
```

#### 3. High Memory Usage

**Symptoms**: Containers getting killed by OOM

**Solutions**:
```bash
# Increase container memory
terraform apply -var="container_memory=32768"  # 32 GB

# Or reduce cache size
terraform apply -var="ephemeral_storage=100"   # 100 GB
```

#### 4. Slow Model Loading

**Symptoms**: Long wait times for model loading

**Solutions**:
```bash
# Check cache hit rate
python3 /app/scripts/cache_manager.py

# Optimize popular models list
# Enable S3 Transfer Acceleration
# Increase cache size
```

### Debug Commands

```bash
# ECS service status
aws ecs describe-services \
  --cluster comfyui-golden-image-prod-cluster \
  --services comfyui-golden-image-prod-admin-service

# Container logs
aws logs get-log-events \
  --log-group-name /ecs/comfyui-golden-image-prod \
  --log-stream-name admin/comfyui-admin/task-id

# Load balancer health
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:...
```

## 💰 Cost Optimization

### Resource Optimization

#### Fargate Pricing (eu-central-1)

| Resource | Specification | Monthly Cost* |
|----------|---------------|---------------|
| **Admin** | 4 vCPU, 16GB RAM | ~$120 |
| **User (2x)** | 4 vCPU, 16GB RAM | ~$240 |
| **Storage** | 200GB ephemeral | Included |
| **ALB** | Standard | ~$20 |
| **S3** | 1TB storage | ~$25 |
| **Data Transfer** | 100GB/month | ~$10 |
| **Total** | | **~$415/month** |

*Prices are estimates and may vary

#### Cost Reduction Strategies

1. **Use Spot Instances** (50-70% savings):
```hcl
# In terraform/ecs.tf
capacity_providers = ["FARGATE", "FARGATE_SPOT"]

default_capacity_provider_strategy {
  base              = 1
  weight            = 20
  capacity_provider = "FARGATE"
}

default_capacity_provider_strategy {
  base              = 0
  weight            = 80
  capacity_provider = "FARGATE_SPOT"
}
```

2. **Auto Scaling Optimization**:
```hcl
# Scale down during off-hours
resource "aws_appautoscaling_scheduled_action" "scale_down" {
  name               = "scale-down-night"
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.user.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  schedule           = "cron(0 22 * * ? *)"  # 10 PM

  scalable_target_action {
    min_capacity = 0
    max_capacity = 2
  }
}
```

3. **S3 Lifecycle Management**:
```hcl
# Automatically move to cheaper storage
rule {
  id     = "cost_optimization"
  status = "Enabled"

  transition {
    days          = 30
    storage_class = "STANDARD_IA"  # 40% cheaper
  }

  transition {
    days          = 90
    storage_class = "GLACIER"      # 80% cheaper
  }
}
```

### Monitoring Costs

```bash
# AWS Cost Explorer CLI
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

## 🔒 Security Best Practices

### Network Security

- **Private Subnets**: ECS tasks run in private subnets
- **Security Groups**: Restrictive inbound/outbound rules
- **ALB**: Only HTTP/HTTPS ports exposed publicly

### IAM Security

- **Principle of Least Privilege**: Minimal required permissions
- **Role-based Access**: Separate roles for admin/user containers
- **No Hardcoded Credentials**: Uses IAM roles and instance profiles

### Container Security

- **Non-root User**: Containers run as non-root user
- **Image Scanning**: ECR vulnerability scanning enabled
- **Read-only Filesystem**: Where possible

## 📈 Scaling Guidelines

### Vertical Scaling

```bash
# Increase container resources
terraform apply \
  -var="container_cpu=8192" \
  -var="container_memory=32768" \
  -var="ephemeral_storage=400"
```

### Horizontal Scaling

```bash
# Increase max instances
resource "aws_appautoscaling_target" "user" {
  max_capacity = 20  # Scale up to 20 instances
  min_capacity = 2
}
```

### Performance Tuning

1. **Cache Size Optimization**:
   - Monitor cache hit rates
   - Adjust hot/cold cache ratio
   - Increase ephemeral storage if needed

2. **S3 Performance**:
   - Use S3 Transfer Acceleration
   - Optimize request patterns
   - Consider CloudFront for static assets

3. **Network Optimization**:
   - Place resources in same AZ when possible
   - Use enhanced networking
   - Monitor network utilization

## 🆘 Support

### Getting Help

1. **GitHub Issues**: Report bugs and feature requests
2. **AWS Support**: For AWS-specific issues
3. **Documentation**: Check this guide and AWS docs

### Useful Resources

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [ComfyUI Documentation](https://github.com/comfyanonymous/ComfyUI)

---

## 🎉 Conclusion

This AWS deployment provides:

- ✅ **Production-ready**: Auto-scaling, monitoring, health checks
- ✅ **Cost-optimized**: Intelligent caching, lifecycle management
- ✅ **Highly available**: Multi-AZ deployment, load balancing
- ✅ **Secure**: Private networks, IAM roles, image scanning
- ✅ **Maintainable**: Infrastructure as Code, CI/CD pipeline

Your ComfyUI Golden Image system is now ready for production workloads! 🚀 