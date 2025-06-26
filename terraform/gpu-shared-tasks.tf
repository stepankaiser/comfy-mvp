# GPU Shared Task Definitions for ComfyUI
# Supports both dedicated GPU and GPU sharing scenarios

# Shared GPU User Task Definition (multiple containers per GPU)
resource "aws_ecs_task_definition" "user_shared_gpu" {
  count                    = var.enable_gpu_sharing ? 1 : 0
  family                   = "${local.name_prefix}-user-shared-gpu"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.container_cpu / var.containers_per_gpu
  memory                   = var.container_memory / var.containers_per_gpu
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn

  # ephemeral_storage not supported for EC2 launch type
  # Storage is managed by the EC2 instance

  container_definitions = jsonencode([
    {
      name  = "comfyui-user-shared"
      image = "${aws_ecr_repository.comfyui.repository_url}:latest"
      
      essential = true
      
      # GPU resource requirements - simplified for sharing
      resourceRequirements = [
        {
          type  = "GPU"
          value = "1"
        }
      ]
      
      portMappings = [
        {
          containerPort = 8190
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "CONTAINER_ROLE"
          value = "user"
        },
        {
          name  = "S3_BUCKET_NAME"
          value = aws_s3_bucket.models.id
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "S3_ENDPOINT"
          value = "https://s3.${var.aws_region}.amazonaws.com"
        },
        {
          name  = "CACHE_STRATEGY"
          value = "intelligent"
        },
        {
          name  = "CACHE_SIZE_GB"
          value = tostring((var.gpu_instance_storage_gb / var.containers_per_gpu) * 0.8)
        },
        {
          name  = "PYTHONPATH"
          value = "/app/shared_python:/app/custom_nodes"
        },
        {
          name  = "LD_LIBRARY_PATH"
          value = "/app/shared_libs"
        },
        {
          name  = "COMFYUI_DISABLE_MANAGER_INSTALL"
          value = "1"
        },
        {
          name  = "NVIDIA_DRIVER_CAPABILITIES"
          value = "compute,utility"
        },
        {
          name  = "CUDA_MPS_PIPE_DIRECTORY"
          value = "/tmp/nvidia-mps"
        },
        {
          name  = "CUDA_MPS_LOG_DIRECTORY"
          value = "/tmp/nvidia-log"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "user-shared"
        }
      }
      
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:8190/ || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
      
      # Resource limits for sharing
      ulimits = [
        {
          name      = "nofile"
          softLimit = 32768
          hardLimit = 32768
        }
      ]
      
      # Shared volumes for GPU sharing
      mountPoints = [
        {
          sourceVolume  = "nvidia-mps"
          containerPath = "/tmp/nvidia-mps"
          readOnly      = false
        }
      ]
    }
  ])

  # Volume for NVIDIA MPS (Multi-Process Service) sharing
  volume {
    name      = "nvidia-mps"
    host_path = "/tmp/nvidia-mps"
  }

  tags = local.tags
}

# Dedicated GPU Task Definition (1 container = 1 full GPU)
resource "aws_ecs_task_definition" "user_dedicated_gpu" {
  count                    = var.enable_gpu_sharing ? 0 : 1
  family                   = "${local.name_prefix}-user-dedicated-gpu"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn

  # ephemeral_storage not supported for EC2 launch type
  # Storage is managed by the EC2 instance

  container_definitions = jsonencode([
    {
      name  = "comfyui-user-dedicated"
      image = "${aws_ecr_repository.comfyui.repository_url}:latest"
      
      essential = true
      
      # Full GPU allocation
      resourceRequirements = [
        {
          type  = "GPU"
          value = "1"
        }
      ]
      
      portMappings = [
        {
          containerPort = 8190
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "CONTAINER_ROLE"
          value = "user"
        },
        {
          name  = "S3_BUCKET_NAME"
          value = aws_s3_bucket.models.id
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "S3_ENDPOINT"
          value = "https://s3.${var.aws_region}.amazonaws.com"
        },
        {
          name  = "CACHE_STRATEGY"
          value = "intelligent"
        },
        {
          name  = "CACHE_SIZE_GB"
          value = tostring(var.gpu_instance_storage_gb * 0.8)
        },
        {
          name  = "PYTHONPATH"
          value = "/app/shared_python:/app/custom_nodes"
        },
        {
          name  = "LD_LIBRARY_PATH"
          value = "/app/shared_libs"
        },
        {
          name  = "COMFYUI_DISABLE_MANAGER_INSTALL"
          value = "1"
        },
        {
          name  = "NVIDIA_DRIVER_CAPABILITIES"
          value = "compute,utility"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "user-dedicated"
        }
      }
      
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:8190/ || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
      
      ulimits = [
        {
          name      = "nofile"
          softLimit = 65536
          hardLimit = 65536
        }
      ]
    }
  ])

  tags = local.tags
}

# Update the existing user service to use the appropriate task definition
resource "aws_ecs_service" "user_flexible" {
  name            = "${local.name_prefix}-user-flexible-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = var.enable_gpu_sharing ? aws_ecs_task_definition.user_shared_gpu[0].arn : aws_ecs_task_definition.user_dedicated_gpu[0].arn
  desired_count   = var.user_service_desired_count * (var.enable_gpu_sharing ? var.containers_per_gpu : 1)

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.gpu.name
    weight           = 100
  }

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.user.arn
    container_name   = var.enable_gpu_sharing ? "comfyui-user-shared" : "comfyui-user-dedicated"
    container_port   = 8190
  }

  depends_on = [
    aws_lb_listener.main,
    aws_ecs_capacity_provider.gpu
  ]

  tags = local.tags
} 