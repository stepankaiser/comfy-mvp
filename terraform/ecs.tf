# ECS Task Definitions and Services for ComfyUI

# IAM Role for ECS Tasks
resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name_prefix}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Tasks (Application Role)
resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# IAM Policy for S3 Access
resource "aws_iam_role_policy" "ecs_task_s3" {
  name = "${local.name_prefix}-ecs-task-s3-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = [
          aws_s3_bucket.models.arn,
          "${aws_s3_bucket.models.arn}/*"
        ]
      }
    ]
  })
}

# CloudWatch Logs Policy
resource "aws_iam_role_policy" "ecs_task_logs" {
  name = "${local.name_prefix}-ecs-task-logs-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Admin Task Definition (GPU-enabled)
resource "aws_ecs_task_definition" "admin" {
  family                   = "${local.name_prefix}-admin"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]  # Changed from FARGATE to EC2 for GPU support
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn

  ephemeral_storage {
    size_in_gib = var.ephemeral_storage
  }

  container_definitions = jsonencode([
    {
      name  = "comfyui-admin"
      image = "${aws_ecr_repository.comfyui.repository_url}:latest"
      
      essential = true
      
      # GPU resource requirements
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
          value = "admin"
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
          value = tostring(var.ephemeral_storage * 0.8) # Use 80% for cache
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
          name  = "NVIDIA_VISIBLE_DEVICES"
          value = "all"
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
          "awslogs-stream-prefix" = "admin"
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
      
      # Resource limits
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

# User Task Definition (GPU-enabled)
resource "aws_ecs_task_definition" "user" {
  family                   = "${local.name_prefix}-user"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]  # Changed from FARGATE to EC2 for GPU support
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn

  ephemeral_storage {
    size_in_gib = var.ephemeral_storage
  }

  container_definitions = jsonencode([
    {
      name  = "comfyui-user"
      image = "${aws_ecr_repository.comfyui.repository_url}:latest"
      
      essential = true
      
      # GPU resource requirements
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
          value = tostring(var.ephemeral_storage * 0.8) # Use 80% for cache
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
          name  = "NVIDIA_VISIBLE_DEVICES"
          value = "all"
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
          "awslogs-stream-prefix" = "user"
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
      
      # Resource limits
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

# Admin ECS Service (GPU-enabled)
resource "aws_ecs_service" "admin" {
  name            = "${local.name_prefix}-admin-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.admin.arn
  desired_count   = var.admin_service_desired_count
  launch_type     = "EC2"  # Changed from FARGATE to EC2 for GPU support

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
    target_group_arn = aws_lb_target_group.admin.arn
    container_name   = "comfyui-admin"
    container_port   = 8190
  }

  depends_on = [
    aws_lb_listener.main,
    aws_ecs_capacity_provider.gpu
  ]

  tags = local.tags
}

# User ECS Service (GPU-enabled)
resource "aws_ecs_service" "user" {
  name            = "${local.name_prefix}-user-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.user.arn
  desired_count   = var.user_service_desired_count
  launch_type     = "EC2"  # Changed from FARGATE to EC2 for GPU support

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
    container_name   = "comfyui-user"
    container_port   = 8190
  }

  depends_on = [
    aws_lb_listener.main,
    aws_ecs_capacity_provider.gpu
  ]

  tags = local.tags
}

# GPU-enabled Auto Scaling Group for ECS
resource "aws_launch_template" "gpu_ecs" {
  name_prefix   = "${local.name_prefix}-gpu-ecs-"
  image_id      = data.aws_ami.ecs_gpu_optimized.id
  instance_type = var.gpu_instance_type
  key_name      = var.key_pair_name

  vpc_security_group_ids = [aws_security_group.ecs_instances.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance.name
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    cluster_name = aws_ecs_cluster.main.name
  }))

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.gpu_instance_storage_gb
      volume_type = "gp3"
      encrypted   = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.tags, {
      Name = "${local.name_prefix}-gpu-ecs-instance"
    })
  }

  tags = local.tags
}

resource "aws_autoscaling_group" "gpu_ecs" {
  name                = "${local.name_prefix}-gpu-ecs-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  min_size            = var.gpu_asg_min_size
  max_size            = var.gpu_asg_max_size
  desired_capacity    = var.gpu_asg_desired_capacity

  launch_template {
    id      = aws_launch_template.gpu_ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = false
  }

  dynamic "tag" {
    for_each = local.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
}

# ECS Capacity Provider for GPU instances
resource "aws_ecs_capacity_provider" "gpu" {
  name = "${local.name_prefix}-gpu-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.gpu_ecs.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }

  tags = local.tags
}

# Associate capacity provider with ECS cluster
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [
    "FARGATE",
    aws_ecs_capacity_provider.gpu.name
  ]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"  # Admin containers use FARGATE
  }
}

# IAM role for ECS instances
resource "aws_iam_role" "ecs_instance" {
  name = "${local.name_prefix}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${local.name_prefix}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance.name

  tags = local.tags
}

# Security group for ECS instances
resource "aws_security_group" "ecs_instances" {
  name        = "${local.name_prefix}-ecs-instances"
  description = "Security group for ECS instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 32768
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-ecs-instances"
  })
}

# Data source for ECS GPU-optimized AMI
data "aws_ami" "ecs_gpu_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-gpu-hvm-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Auto Scaling Target for User Service
resource "aws_appautoscaling_target" "user" {
  max_capacity       = var.user_service_max_capacity
  min_capacity       = var.user_service_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.user.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - Scale Up
resource "aws_appautoscaling_policy" "user_scale_up" {
  name               = "${local.name_prefix}-user-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.user.resource_id
  scalable_dimension = aws_appautoscaling_target.user.scalable_dimension
  service_namespace  = aws_appautoscaling_target.user.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_value
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}

# Auto Scaling Policy - Memory Utilization
resource "aws_appautoscaling_policy" "user_scale_memory" {
  name               = "${local.name_prefix}-user-scale-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.user.resource_id
  scalable_dimension = aws_appautoscaling_target.user.scalable_dimension
  service_namespace  = aws_appautoscaling_target.user.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.memory_target_value
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "admin_cpu_high" {
  alarm_name          = "${local.name_prefix}-admin-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors admin ECS cpu utilization"

  dimensions = {
    ServiceName = aws_ecs_service.admin.name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "user_cpu_high" {
  alarm_name          = "${local.name_prefix}-user-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors user ECS cpu utilization"

  dimensions = {
    ServiceName = aws_ecs_service.user.name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = local.tags
}

# Custom CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.admin.name, "ClusterName", aws_ecs_cluster.main.name],
            [".", "MemoryUtilization", ".", ".", ".", "."],
            [".", "CPUUtilization", "ServiceName", aws_ecs_service.user.name, "ClusterName", aws_ecs_cluster.main.name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ECS Service Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix],
            [".", "RequestCount", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Load Balancer Metrics"
          period  = 300
        }
      }
    ]
  })
} 