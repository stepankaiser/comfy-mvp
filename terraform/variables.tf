# Terraform Variables for ComfyUI AWS Deployment

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "comfyui-golden-image"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "container_cpu" {
  description = "CPU units for Fargate tasks"
  type        = number
  default     = 4096  # 4 vCPU
}

variable "container_memory" {
  description = "Memory for Fargate tasks in MB"
  type        = number
  default     = 16384  # 16 GB
}

variable "ephemeral_storage" {
  description = "Ephemeral storage for cache in GB"
  type        = number
  default     = 200  # 200 GB NVMe SSD
}

# Auto-scaling configuration
variable "user_service_min_capacity" {
  description = "Minimum number of user service instances"
  type        = number
  default     = 1
}

variable "user_service_max_capacity" {
  description = "Maximum number of user service instances"
  type        = number
  default     = 10
}

variable "user_service_desired_count" {
  description = "Initial desired count for user service"
  type        = number
  default     = 2
}

variable "admin_service_desired_count" {
  description = "Desired count for admin service (typically 1)"
  type        = number
  default     = 1
}

# Auto-scaling thresholds
variable "cpu_target_value" {
  description = "Target CPU utilization for auto-scaling"
  type        = number
  default     = 70.0
}

variable "memory_target_value" {
  description = "Target memory utilization for auto-scaling"
  type        = number
  default     = 80.0
}

variable "scale_in_cooldown" {
  description = "Cooldown period for scale-in operations (seconds)"
  type        = number
  default     = 300  # 5 minutes
}

variable "scale_out_cooldown" {
  description = "Cooldown period for scale-out operations (seconds)"
  type        = number
  default     = 300  # 5 minutes
}

# Cost optimization
variable "enable_spot_instances" {
  description = "Enable Fargate Spot instances for cost savings"
  type        = bool
  default     = false
}

variable "spot_instance_percentage" {
  description = "Percentage of instances to run on Spot (0-100)"
  type        = number
  default     = 70
}

# S3 configuration
variable "s3_lifecycle_ia_days" {
  description = "Days after which objects transition to IA storage"
  type        = number
  default     = 30
}

variable "s3_lifecycle_glacier_days" {
  description = "Days after which objects transition to Glacier"
  type        = number
  default     = 90
}

variable "s3_delete_old_versions_days" {
  description = "Days after which old versions are deleted"
  type        = number
  default     = 7
}

# Monitoring
variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# Security
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the load balancer"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for load balancer"
  type        = bool
  default     = false
}

# Performance tuning
variable "cache_size_percentage" {
  description = "Percentage of ephemeral storage to use for cache"
  type        = number
  default     = 80
}

variable "hot_cache_ratio" {
  description = "Ratio of cache to allocate for hot cache (0.0-1.0)"
  type        = number
  default     = 0.3
} 