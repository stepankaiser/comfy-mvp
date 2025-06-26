#!/bin/bash

# Manual Cleanup Script for ComfyUI AWS Resources
# Use this when Terraform destroy fails or for emergency cleanup

set -e

ENV=${1:-test}
REGION=${2:-eu-central-1}

echo "🧹 Starting manual cleanup for environment: $ENV in region: $REGION"
echo "⚠️  This will delete all resources for the specified environment!"
echo ""

read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm
if [ "$confirm" != "yes" ]; then
    echo "❌ Cleanup cancelled"
    exit 1
fi

echo ""
echo "🚀 Starting cleanup process..."

# Function to safely delete resources
safe_delete() {
    local resource_type=$1
    local command=$2
    echo "🗑️  Deleting $resource_type..."
    eval "$command" 2>/dev/null && echo "✅ $resource_type deleted" || echo "ℹ️  $resource_type not found or already deleted"
}

# 1. ECS Services and Tasks
echo "🛑 Stopping ECS services..."
for service in comfyui-golden-image-$ENV-admin comfyui-golden-image-$ENV-user comfyui-golden-image-$ENV-user-manager; do
    echo "Stopping service: $service"
    aws ecs update-service --cluster comfyui-golden-image-$ENV --service $service --desired-count 0 --region $REGION 2>/dev/null || true
    aws ecs wait services-stable --cluster comfyui-golden-image-$ENV --services $service --region $REGION 2>/dev/null || true
    aws ecs delete-service --cluster comfyui-golden-image-$ENV --service $service --region $REGION 2>/dev/null || true
done

# 2. ECS Cluster
safe_delete "ECS Cluster" "aws ecs delete-cluster --cluster comfyui-golden-image-$ENV --region $REGION"

# 3. Load Balancer and Target Groups
echo "🔗 Cleaning up Load Balancer resources..."
aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?contains(LoadBalancerName, 'comfyui-golden-image-$ENV')].LoadBalancerArn" --output text | while read lb_arn; do
    if [ ! -z "$lb_arn" ]; then
        safe_delete "Load Balancer $lb_arn" "aws elbv2 delete-load-balancer --load-balancer-arn $lb_arn --region $REGION"
    fi
done

aws elbv2 describe-target-groups --region $REGION --query "TargetGroups[?contains(TargetGroupName, 'comfyui-golden-i')].TargetGroupArn" --output text | while read tg_arn; do
    if [ ! -z "$tg_arn" ]; then
        safe_delete "Target Group $tg_arn" "aws elbv2 delete-target-group --target-group-arn $tg_arn --region $REGION"
    fi
done

# 4. Auto Scaling Groups and Launch Templates
echo "📈 Cleaning up Auto Scaling resources..."
for asg in comfyui-golden-image-$ENV-gpu-asg; do
    safe_delete "Auto Scaling Group $asg" "aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $asg --force-delete --region $REGION"
done

for lt in comfyui-golden-image-$ENV-gpu-lt; do
    safe_delete "Launch Template $lt" "aws ec2 delete-launch-template --launch-template-name $lt --region $REGION"
done

# 5. Security Groups
echo "🛡️ Cleaning up Security Groups..."
vpc_id=$(aws ec2 describe-vpcs --region $REGION --filters "Name=tag:Name,Values=comfyui-golden-image-$ENV-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null)
if [ "$vpc_id" != "None" ] && [ ! -z "$vpc_id" ]; then
    aws ec2 describe-security-groups --region $REGION --filters "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text | while read sg_id; do
        if [ ! -z "$sg_id" ]; then
            safe_delete "Security Group $sg_id" "aws ec2 delete-security-group --group-id $sg_id --region $REGION"
        fi
    done
fi

# 6. NAT Gateways and EIPs
echo "🌐 Cleaning up NAT Gateways and EIPs..."
if [ "$vpc_id" != "None" ] && [ ! -z "$vpc_id" ]; then
    aws ec2 describe-nat-gateways --region $REGION --filter "Name=vpc-id,Values=$vpc_id" --query 'NatGateways[].NatGatewayId' --output text | while read nat_id; do
        if [ ! -z "$nat_id" ]; then
            safe_delete "NAT Gateway $nat_id" "aws ec2 delete-nat-gateway --nat-gateway-id $nat_id --region $REGION"
        fi
    done
fi

# Release unassociated EIPs
aws ec2 describe-addresses --region $REGION --query 'Addresses[?AssociationId==null].AllocationId' --output text | while read allocation_id; do
    if [ ! -z "$allocation_id" ]; then
        safe_delete "EIP $allocation_id" "aws ec2 release-address --allocation-id $allocation_id --region $REGION"
    fi
done

# 7. Subnets and VPC
echo "🏗️ Cleaning up VPC resources..."
if [ "$vpc_id" != "None" ] && [ ! -z "$vpc_id" ]; then
    # Delete subnets
    aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[].SubnetId' --output text | while read subnet_id; do
        if [ ! -z "$subnet_id" ]; then
            safe_delete "Subnet $subnet_id" "aws ec2 delete-subnet --subnet-id $subnet_id --region $REGION"
        fi
    done
    
    # Delete Internet Gateway
    aws ec2 describe-internet-gateways --region $REGION --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[].InternetGatewayId' --output text | while read igw_id; do
        if [ ! -z "$igw_id" ]; then
            aws ec2 detach-internet-gateway --internet-gateway-id $igw_id --vpc-id $vpc_id --region $REGION 2>/dev/null
            safe_delete "Internet Gateway $igw_id" "aws ec2 delete-internet-gateway --internet-gateway-id $igw_id --region $REGION"
        fi
    done
    
    # Delete VPC
    safe_delete "VPC $vpc_id" "aws ec2 delete-vpc --vpc-id $vpc_id --region $REGION"
fi

# 8. IAM Roles and Policies
echo "👤 Cleaning up IAM resources..."
for role in comfyui-golden-image-$ENV-ecs-task-execution-role \
           comfyui-golden-image-$ENV-ecs-task-role \
           comfyui-golden-image-$ENV-ecs-instance-role \
           comfyui-golden-image-$ENV-user-manager-task-role; do
    
    echo "Cleaning up role: $role"
    
    # Detach managed policies
    aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null | while read policy_arn; do
        if [ ! -z "$policy_arn" ]; then
            safe_delete "Managed Policy $policy_arn from $role" "aws iam detach-role-policy --role-name $role --policy-arn $policy_arn"
        fi
    done
    
    # Delete inline policies
    aws iam list-role-policies --role-name "$role" --query 'PolicyNames[]' --output text 2>/dev/null | while read policy_name; do
        if [ ! -z "$policy_name" ]; then
            safe_delete "Inline Policy $policy_name from $role" "aws iam delete-role-policy --role-name $role --policy-name $policy_name"
        fi
    done
    
    # Remove from instance profiles
    aws iam list-instance-profiles-for-role --role-name "$role" --query 'InstanceProfiles[].InstanceProfileName' --output text 2>/dev/null | while read profile_name; do
        if [ ! -z "$profile_name" ]; then
            safe_delete "Role $role from Instance Profile $profile_name" "aws iam remove-role-from-instance-profile --instance-profile-name $profile_name --role-name $role"
            safe_delete "Instance Profile $profile_name" "aws iam delete-instance-profile --instance-profile-name $profile_name"
        fi
    done
    
    # Delete role
    safe_delete "IAM Role $role" "aws iam delete-role --role-name $role"
done

# 9. ECR Repositories
echo "📦 Cleaning up ECR repositories..."
for repo in comfyui-golden-image-$ENV-app comfyui-golden-image-$ENV-user-manager; do
    safe_delete "ECR Repository $repo" "aws ecr delete-repository --repository-name $repo --force --region $REGION"
done

# 10. CloudWatch Log Groups
echo "📊 Cleaning up CloudWatch resources..."
safe_delete "CloudWatch Log Group" "aws logs delete-log-group --log-group-name /ecs/comfyui-golden-image-$ENV --region $REGION"

# 11. S3 Bucket (optional - be careful!)
echo ""
echo "⚠️  S3 Bucket cleanup (optional):"
echo "S3 bucket comfyui-golden-image-$ENV-storage contains your models and data."
read -p "Do you want to delete the S3 bucket? This will DELETE ALL YOUR MODELS! (type 'DELETE_BUCKET' to confirm): " bucket_confirm
if [ "$bucket_confirm" = "DELETE_BUCKET" ]; then
    safe_delete "S3 Bucket" "aws s3 rb s3://comfyui-golden-image-$ENV-storage --force --region $REGION"
else
    echo "ℹ️  S3 bucket preserved"
fi

echo ""
echo "✅ Manual cleanup completed!"
echo ""
echo "📊 Final verification:"
echo "VPCs: $(aws ec2 describe-vpcs --region $REGION --query 'length(Vpcs[])' --output text)/5"
echo "EIPs: $(aws ec2 describe-addresses --region $REGION --query 'length(Addresses[])' --output text)/5"
echo ""
echo "🎉 Environment '$ENV' has been cleaned up. You can now retry deployment." 