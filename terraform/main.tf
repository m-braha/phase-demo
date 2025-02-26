provider "aws" {
  region = "us-west-2"
  # Eng-Experiments account
  allowed_account_ids = ["548199914959"]
}

# Use data sources to reference existing VPC and subnet
data "aws_vpc" "existing" {
  tags = {
    Name = "eng-experiments-vpc"
  }
}

data "aws_subnets" "existing" {
  filter {
    name = "tag:Name"
    values = [
      "eng-experiments-subnet-public1-us-west-2a",
      "eng-experiments-subnet-public2-us-west-2b"
    ]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}

locals {
  namespace = "phase-demo-${var.phase_environment}"
}

# AWS Secrets Manager secret for Phase service token
resource "aws_secretsmanager_secret" "phase_token" {
  name_prefix = "phase/${var.phase_environment}/service-token-"

  tags = {
    Environment = var.phase_environment
    Project     = "phase-demo"
  }

  force_overwrite_replica_secret = true # Makes it easier to clean up
}

# Store the actual Phase token value
resource "aws_secretsmanager_secret_version" "phase_token" {
  secret_id     = aws_secretsmanager_secret.phase_token.id
  secret_string = var.phase_service_token
}

# IAM policy for accessing the Phase service token
resource "aws_iam_policy" "phase_token_access" {
  name_prefix = "phase-token-access-"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [aws_secretsmanager_secret.phase_token.arn]
      }
    ]
  })
}

# ECS Task Role
resource "aws_iam_role" "task_role" {
  name_prefix = "phase-demo-task-"

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

  # Makes it easier to clean up
  force_detach_policies = true
}

resource "aws_iam_role_policy_attachment" "task_phase_token" {
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.phase_token_access.arn
}

# ECS Task Execution Role (for pulling images and secrets)
resource "aws_iam_role" "execution_role" {
  name_prefix = "phase-demo-exec-"

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

  # Makes it easier to clean up
  force_detach_policies = true
}

# Add CloudWatch Logs permissions
resource "aws_iam_role_policy" "execution_logs" {
  name = "cloudwatch-logs"
  role = aws_iam_role.execution_role.id

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
        Resource = [
          "arn:aws:logs:us-west-2:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${local.namespace}:*",
          "arn:aws:logs:us-west-2:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${local.namespace}"
        ]
      }
    ]
  })
}

# Get current AWS account ID for log group ARN
data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy_attachment" "execution_policy" {
  role       = aws_iam_role.execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "execution_secrets_policy" {
  role       = aws_iam_role.execution_role.name
  policy_arn = aws_iam_policy.phase_token_access.arn
}

# Security group for the ALB
resource "aws_security_group" "alb" {
  name_prefix = "phase-demo-alb-"
  description = "Phase demo ALB access"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["50.203.25.222/32"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Update ECS tasks security group to only allow traffic from ALB
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "phase-demo-"
  description = "Phase demo app access"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    protocol        = "tcp"
    from_port       = 3000
    to_port         = 3000
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Cluster - using an existing one if available
resource "aws_ecs_cluster" "main" {
  name = local.namespace

  setting {
    name  = "containerInsights"
    value = "disabled" # Keeps costs down
  }
}

# Create ECR Repository
resource "aws_ecr_repository" "app" {
  name                 = local.namespace
  image_tag_mutability = "MUTABLE" # Allows reusing tags like 'latest'

  force_delete = true # Makes cleanup easier

  image_scanning_configuration {
    scan_on_push = false # Disable for demo purposes
  }
}

# ECR Lifecycle policy to clean up old images
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 3 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 3
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# Output the repository URL and helper commands
output "ecr_repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "ECR repository URL for pushing images"
}

output "docker_push_commands" {
  value       = <<EOF
# Build and push your local image:
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url}
docker build --platform linux/amd64 -t ${local.namespace} .
docker tag ${local.namespace}:latest ${aws_ecr_repository.app.repository_url}:latest
docker push ${aws_ecr_repository.app.repository_url}:latest

# Then run terraform with:
terraform apply -var="container_image=${aws_ecr_repository.app.repository_url}:latest"
EOF
  description = "Commands to push your local image to ECR"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = local.namespace
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256 # Minimum Fargate CPU
  memory                   = 512 # Minimum Fargate memory
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = local.namespace
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "PHASE_APP"
          value = var.phase_app
        },
        {
          name  = "PHASE_ENVIRONMENT"
          value = var.phase_environment
        }
      ]
      secrets = [
        {
          name      = "PHASE_SERVICE_TOKEN"
          valueFrom = aws_secretsmanager_secret.phase_token.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-create-group"  = "true"
          "awslogs-group"         = "/ecs/${local.namespace}"
          "awslogs-region"        = "us-west-2"
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  execution_role_arn = aws_iam_role.execution_role.arn
  task_role_arn      = aws_iam_role.task_role.arn
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "phase-demo-${var.phase_environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.existing.ids
}

# ALB target group
resource "aws_lb_target_group" "app" {
  name        = "phase-demo-${var.phase_environment}"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.existing.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 15
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  # Wait for the ALB to be ready before creating the target group
  depends_on = [aws_lb.main]
}

# ALB listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  # Wait for both ALB and target group to be ready
  depends_on = [
    aws_lb.main,
    aws_lb_target_group.app
  ]
}

# Update ECS service to use ALB
resource "aws_ecs_service" "main" {
  name            = local.namespace
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.existing.ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = local.namespace
    container_port   = 3000
  }

  # Wait for the ALB and listener to be ready before creating the service
  depends_on = [
    aws_lb_listener.http,
    aws_lb.main
  ]
}

# Output the ALB DNS name
output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "Application Load Balancer DNS name"
}

# Output subnet IDs for verification
output "subnet_ids" {
  value       = data.aws_subnets.existing.ids
  description = "Subnet IDs being used"
}

# Debug output for subnet details
output "subnet_debug" {
  value = {
    vpc_id = data.aws_vpc.existing.id
    filters = {
      name = "tag:Name"
      values = [
        "eng-experiments-subnet-public1-us-west-2a",
        "eng-experiments-subnet-public1-us-west-2b"
      ]
    }
  }
  description = "Debug information for subnet lookup"
}
