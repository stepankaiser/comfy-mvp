# ComfyUI AWS Deployment Configuration
# Production-ready setup with GPU sharing

# Basic Configuration
aws_region   = "eu-central-1"
project_name = "comfyui-golden-image"
environment  = "dev"  # Start with dev, change to prod later

# Container Resources (optimized for GPU sharing)
container_cpu    = 4096   # 4 vCPU per container
container_memory = 16384  # 16 GB per container
ephemeral_storage = 200   # 200 GB cache per container

# Auto-scaling Configuration (conservative start)
user_service_min_capacity    = 0   # Scale to zero when not used
user_service_max_capacity    = 6   # Allow up to 6 user containers
user_service_desired_count   = 2   # Start with 2 user containers
admin_service_desired_count  = 1   # 1 admin container

# Auto-scaling Thresholds
cpu_target_value     = 70.0  # Scale up when CPU > 70%
memory_target_value  = 80.0  # Scale up when Memory > 80%
scale_in_cooldown    = 300   # 5 minutes before scaling down
scale_out_cooldown   = 300   # 5 minutes before scaling up

# Cost Optimization
enable_spot_instances    = false  # Start with On-Demand for stability
spot_instance_percentage = 0     # No spot instances initially

# S3 Lifecycle Management
s3_lifecycle_ia_days      = 30  # Move to IA storage after 30 days
s3_lifecycle_glacier_days = 90  # Move to Glacier after 90 days
s3_delete_old_versions_days = 7 # Delete old versions after 7 days

# Monitoring
enable_detailed_monitoring = true
log_retention_days        = 7

# Security
allowed_cidr_blocks      = ["0.0.0.0/0"]  # Open access (restrict in production)
enable_deletion_protection = false        # Disabled for easier testing

# Performance Tuning
cache_size_percentage = 80   # Use 80% of ephemeral storage for cache
hot_cache_ratio      = 0.3  # 30% hot cache, 70% cold cache

# GPU Configuration
gpu_instance_type        = "g4dn.xlarge"  # NVIDIA T4 16GB GPU
gpu_instance_storage_gb  = 200            # 200GB EBS storage
gpu_asg_min_size        = 0               # Scale to zero for cost savings
gpu_asg_max_size        = 3               # Max 3 GPU instances
gpu_asg_desired_capacity = 1              # Start with 1 GPU instance

# GPU Sharing Configuration (2 containers per GPU for cost efficiency)
enable_gpu_sharing         = true   # Enable GPU sharing
gpu_memory_reservation_mb  = 4096   # 4GB per container (allows 2-4 containers per T4)
containers_per_gpu        = 2       # 2 containers share 1 GPU

# Optional: EC2 Key Pair for SSH access to GPU instances
# key_pair_name = "your-key-pair-name" 