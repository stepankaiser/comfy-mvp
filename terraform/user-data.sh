#!/bin/bash

# ECS GPU-optimized instance user data script
# This script configures the ECS agent on GPU instances

# Set ECS cluster name
echo "ECS_CLUSTER=${cluster_name}" >> /etc/ecs/ecs.config

# Enable GPU support
echo "ECS_ENABLE_GPU_SUPPORT=true" >> /etc/ecs/ecs.config

# Configure container instance attributes
echo "ECS_INSTANCE_ATTRIBUTES={\"gpu\":\"true\"}" >> /etc/ecs/ecs.config

# Enable task IAM role
echo "ECS_ENABLE_TASK_IAM_ROLE=true" >> /etc/ecs/ecs.config

# Set log level
echo "ECS_LOGLEVEL=info" >> /etc/ecs/ecs.config

# Configure Docker daemon for GPU support
cat > /etc/docker/daemon.json << 'EOF'
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    },
    "log-driver": "awslogs",
    "log-opts": {
        "awslogs-group": "ecs-gpu-instances",
        "awslogs-region": "eu-central-1"
    }
}
EOF

# Restart Docker daemon
systemctl restart docker

# Install CloudWatch agent
yum update -y
yum install -y amazon-cloudwatch-agent

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "metrics": {
        "namespace": "AWS/ECS/GPU",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60,
                "totalcpu": false
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            },
            "swap": {
                "measurement": [
                    "swap_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/ecs/ecs-init.log",
                        "log_group_name": "ecs-gpu-instances",
                        "log_stream_name": "{instance_id}/ecs-init.log"
                    },
                    {
                        "file_path": "/var/log/ecs/ecs-agent.log",
                        "log_group_name": "ecs-gpu-instances",
                        "log_stream_name": "{instance_id}/ecs-agent.log"
                    },
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "ecs-gpu-instances",
                        "log_stream_name": "{instance_id}/messages"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Install nvidia-docker2 (already included in ECS GPU-optimized AMI, but ensure it's configured)
systemctl enable docker
systemctl enable ecs

# Set up NVIDIA MPS for GPU sharing
mkdir -p /tmp/nvidia-mps /tmp/nvidia-log
chmod 777 /tmp/nvidia-mps /tmp/nvidia-log

# Create NVIDIA MPS startup script
cat > /usr/local/bin/nvidia-mps-setup.sh << 'EOF'
#!/bin/bash
# NVIDIA Multi-Process Service setup for GPU sharing

export CUDA_VISIBLE_DEVICES=0
export CUDA_MPS_PIPE_DIRECTORY=/tmp/nvidia-mps
export CUDA_MPS_LOG_DIRECTORY=/tmp/nvidia-log

# Check if GPU is available
if command -v nvidia-smi &> /dev/null && nvidia-smi -L | grep -q "GPU"; then
    echo "Setting up NVIDIA MPS for GPU sharing..."
    
    # Start MPS control daemon
    nvidia-cuda-mps-control -d
    
    # Set memory limit per client (4GB per container)
    echo "set_default_active_thread_percentage 50" | nvidia-cuda-mps-control
    echo "set_default_mem_grow_delta 1073741824" | nvidia-cuda-mps-control  # 1GB chunks
    
    echo "NVIDIA MPS started successfully"
else
    echo "No GPU detected, skipping MPS setup"
fi
EOF

chmod +x /usr/local/bin/nvidia-mps-setup.sh

# Create systemd service for NVIDIA MPS
cat > /etc/systemd/system/nvidia-mps.service << 'EOF'
[Unit]
Description=NVIDIA Multi-Process Service
After=docker.service
Requires=docker.service

[Service]
Type=forking
User=root
ExecStart=/usr/local/bin/nvidia-mps-setup.sh
ExecStop=/bin/bash -c "echo quit | nvidia-cuda-mps-control"
RemainAfterExit=yes
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nvidia-mps.service
systemctl start nvidia-mps.service

# Set up GPU monitoring script
cat > /usr/local/bin/gpu-monitor.sh << 'EOF'
#!/bin/bash
# Simple GPU monitoring script

while true; do
    if command -v nvidia-smi &> /dev/null; then
        GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1)
        GPU_MEM=$(nvidia-smi --query-gpu=utilization.memory --format=csv,noheader,nounits | head -1)
        GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -1)
        
        # Send custom metrics to CloudWatch
        aws cloudwatch put-metric-data \
            --namespace "AWS/ECS/GPU" \
            --metric-data MetricName=GPUUtilization,Value=$GPU_UTIL,Unit=Percent \
            --region eu-central-1 2>/dev/null
            
        aws cloudwatch put-metric-data \
            --namespace "AWS/ECS/GPU" \
            --metric-data MetricName=GPUMemoryUtilization,Value=$GPU_MEM,Unit=Percent \
            --region eu-central-1 2>/dev/null
            
        aws cloudwatch put-metric-data \
            --namespace "AWS/ECS/GPU" \
            --metric-data MetricName=GPUTemperature,Value=$GPU_TEMP,Unit=None \
            --region eu-central-1 2>/dev/null
    fi
    
    sleep 60
done
EOF

chmod +x /usr/local/bin/gpu-monitor.sh

# Create systemd service for GPU monitoring
cat > /etc/systemd/system/gpu-monitor.service << 'EOF'
[Unit]
Description=GPU Monitoring Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/gpu-monitor.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl enable gpu-monitor.service
systemctl start gpu-monitor.service

# Ensure ECS agent starts after all configuration
systemctl restart ecs

# Log completion
echo "ECS GPU instance configuration completed at $(date)" >> /var/log/user-data.log 