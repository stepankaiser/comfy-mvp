# User Manager Service for ComfyUI Environment Management

# ECR Repository for User Manager
resource "aws_ecr_repository" "user_manager" {
  name                 = "${local.name_prefix}-user-manager"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

# Task Definition for User Manager
resource "aws_ecs_task_definition" "user_manager" {
  family                   = "${local.name_prefix}-user-manager"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512   # 0.5 vCPU
  memory                   = 1024  # 1 GB
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn           = aws_iam_role.user_manager_task.arn

  container_definitions = jsonencode([
    {
      name  = "user-manager"
      image = "${aws_ecr_repository.user_manager.repository_url}:latest"
      
      essential = true
      
      portMappings = [
        {
          containerPort = 5000
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "ECS_CLUSTER"
          value = aws_ecs_cluster.main.name
        },
        {
          name  = "ALB_DNS_NAME"
          value = aws_lb.main.dns_name
        },
        {
          name  = "FLASK_ENV"
          value = var.environment == "prod" ? "production" : "development"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "user-manager"
        }
      }
      
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:5000/health || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    }
  ])

  tags = local.tags
}

# IAM Role for User Manager Task
resource "aws_iam_role" "user_manager_task" {
  name = "${local.name_prefix}-user-manager-task-role"

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

# IAM Policy for User Manager ECS Operations
resource "aws_iam_role_policy" "user_manager_ecs" {
  name = "${local.name_prefix}-user-manager-ecs-policy"
  role = aws_iam_role.user_manager_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:ListServices",
          "ecs:DescribeServices",
          "ecs:CreateService",
          "ecs:UpdateService",
          "ecs:DeleteService",
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ecs:DescribeClusters",
          "ecs:DescribeTaskDefinition",
          "ecs:TagResource"
        ]
        Resource = [
          aws_ecs_cluster.main.arn,
          "${aws_ecs_cluster.main.arn}/*",
          "arn:aws:ecs:${var.aws_region}:*:task-definition/${local.name_prefix}-user*",
          "arn:aws:ecs:${var.aws_region}:*:service/${aws_ecs_cluster.main.name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_task_execution.arn,
          aws_iam_role.ecs_task.arn
        ]
      }
    ]
  })
}

# ECS Service for User Manager
resource "aws_ecs_service" "user_manager" {
  name            = "${local.name_prefix}-user-manager-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.user_manager.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.user_manager.arn
    container_name   = "user-manager"
    container_port   = 5000
  }

  depends_on = [aws_lb_listener.main]

  tags = local.tags
}

# Target Group for User Manager
resource "aws_lb_target_group" "user_manager" {
  name     = "${local.name_prefix}-user-manager-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = local.tags
}

# Add User Manager route to ALB
resource "aws_lb_listener_rule" "user_manager" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 50

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.user_manager.arn
  }

  condition {
    path_pattern {
      values = ["/manager/*", "/manager"]
    }
  }

  tags = local.tags
} 