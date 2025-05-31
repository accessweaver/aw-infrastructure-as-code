# =============================================================================
# AccessWeaver ECS Module
# =============================================================================
# Module pour orchestrer les microservices AccessWeaver sur AWS ECS Fargate
#
# OBJECTIF:
# - Déployer les services AccessWeaver (PDP, PAP, Auth, etc.) sur Fargate
# - Configuration adaptative selon l'environnement (dev/staging/prod)
# - Auto-scaling basé sur métriques (CPU, mémoire, requêtes)
# - Intégration avec ALB, RDS, Redis via service discovery
# - Secrets management avec AWS Secrets Manager
#
# ARCHITECTURE:
# - ECS Cluster Fargate (serverless, pas de gestion d'instances)
# - Services ECS pour chaque microservice AccessWeaver
# - Task definitions optimisées par environnement
# - Service discovery via AWS Cloud Map
# - Auto-scaling groups avec scaling policies
#
# SERVICES ACCESSWEAVER DÉPLOYÉS:
# - aw-api-gateway: Point d'entrée + auth JWT
# - aw-pdp-service: Policy Decision Point (autorisation)
# - aw-pap-service: Policy Administration Point
# - aw-tenant-service: Gestion multi-tenancy
# - aw-audit-service: Logging et compliance
# =============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# =============================================================================
# Local Values - Configuration adaptative selon l'environnement
# =============================================================================
locals {
  # Détection environnement pour configuration adaptative
  is_production = var.environment == "prod"
  is_staging    = var.environment == "staging"
  is_dev        = var.environment == "dev"

  # Configuration ECS selon environnement
  # Ressources CPU/Memory en fonction de la charge attendue
  ecs_config = {
    dev = {
      cluster_insights = false
      container_insights = false

      # Ressources minimales pour développement
      default_cpu    = 256   # 0.25 vCPU
      default_memory = 512   # 512 MB

      # Scaling minimal
      min_capacity = 1
      max_capacity = 2

      # Health checks plus permissifs
      health_check_grace_period = 300  # 5 minutes
      deregistration_delay = 30        # 30 secondes
    }
    staging = {
      cluster_insights = true
      container_insights = true

      # Ressources intermédiaires pour tests réalistes
      default_cpu    = 512   # 0.5 vCPU
      default_memory = 1024  # 1 GB

      # Scaling modéré
      min_capacity = 1
      max_capacity = 4

      # Health checks équilibrés
      health_check_grace_period = 180  # 3 minutes
      deregistration_delay = 60        # 1 minute
    }
    prod = {
      cluster_insights = true
      container_insights = true

      # Ressources robustes pour production
      default_cpu    = 1024  # 1 vCPU
      default_memory = 2048  # 2 GB

      # Scaling agressif pour HA
      min_capacity = 2
      max_capacity = 10

      # Health checks stricts
      health_check_grace_period = 120  # 2 minutes
      deregistration_delay = 300       # 5 minutes
    }
  }

  current_config = local.ecs_config[var.environment]

  # Services AccessWeaver à déployer
  # Configuration par service avec ressources adaptées
  accessweaver_services = {
    api-gateway = {
      name = "aw-api-gateway"
      container_port = 8080
      cpu = local.is_production ? 1024 : local.is_staging ? 512 : 256
      memory = local.is_production ? 2048 : local.is_staging ? 1024 : 512
      desired_count = local.is_production ? 3 : local.is_staging ? 2 : 1
      essential = true
      public = true  # Exposé via ALB
      health_check_path = "/actuator/health"

      # Variables d'environnement spécifiques
      environment_variables = {
        SERVER_PORT = "8080"
        SPRING_PROFILES_ACTIVE = var.environment
        EUREKA_CLIENT_ENABLED = "true"
        MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE = "health,info,metrics"
      }
    }

    pdp-service = {
      name = "aw-pdp-service"
      container_port = 8081
      cpu = local.is_production ? 2048 : local.is_staging ? 1024 : 512
      memory = local.is_production ? 4096 : local.is_staging ? 2048 : 1024
      desired_count = local.is_production ? 3 : local.is_staging ? 2 : 1
      essential = true
      public = false  # Service interne
      health_check_path = "/actuator/health"

      # PDP a besoin de plus de ressources (évaluation OPA)
      environment_variables = {
        SERVER_PORT = "8081"
        SPRING_PROFILES_ACTIVE = var.environment
        OPA_EMBEDDED_ENABLED = "true"
        CACHE_REDIS_ENABLED = "true"
      }
    }

    pap-service = {
      name = "aw-pap-service"
      container_port = 8082
      cpu = local.is_production ? 1024 : local.is_staging ? 512 : 256
      memory = local.is_production ? 2048 : local.is_staging ? 1024 : 512
      desired_count = local.is_production ? 2 : local.is_staging ? 1 : 1
      essential = true
      public = false  # Service interne
      health_check_path = "/actuator/health"

      environment_variables = {
        SERVER_PORT = "8082"
        SPRING_PROFILES_ACTIVE = var.environment
        SPRING_JPA_HIBERNATE_DDL_AUTO = "validate"
      }
    }

    tenant-service = {
      name = "aw-tenant-service"
      container_port = 8083
      cpu = local.is_production ? 512 : local.is_staging ? 256 : 256
      memory = local.is_production ? 1024 : local.is_staging ? 512 : 512
      desired_count = local.is_production ? 2 : 1
      essential = true
      public = false  # Service interne
      health_check_path = "/actuator/health"

      environment_variables = {
        SERVER_PORT = "8083"
        SPRING_PROFILES_ACTIVE = var.environment
        TENANT_ISOLATION_ENABLED = "true"
      }
    }

    audit-service = {
      name = "aw-audit-service"
      container_port = 8084
      cpu = local.is_production ? 512 : local.is_staging ? 256 : 256
      memory = local.is_production ? 1024 : local.is_staging ? 512 : 512
      desired_count = local.is_production ? 2 : 1
      essential = false  # Non critique pour le fonctionnement
      public = false     # Service interne
      health_check_path = "/actuator/health"

      environment_variables = {
        SERVER_PORT = "8084"
        SPRING_PROFILES_ACTIVE = var.environment
        LOGGING_LEVEL_ROOT = local.is_production ? "INFO" : "DEBUG"
      }
    }
  }

  # Tags communs pour toutes les ressources ECS
  common_tags = {
    Name        = "${var.project_name}-${var.environment}-ecs"
    Project     = var.project_name
    Environment = var.environment
    Component   = "compute"
    ManagedBy   = "terraform"
    Service     = "accessweaver-ecs"
  }
}

# =============================================================================
# ECS Cluster - Fargate serverless
# =============================================================================
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  # Configuration insights selon environnement
  dynamic "setting" {
    for_each = local.current_config.container_insights ? [1] : []
    content {
      name  = "containerInsights"
      value = "enabled"
    }
  }

  # Configuration des capacity providers via une ressource séparée
  # Les capacity providers sont maintenant configurés via aws_ecs_cluster_capacity_providers

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ecs-cluster"
  })
}

# Configuration des capacity providers pour le cluster ECS
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name
  
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight           = local.is_production ? 100 : 70  # Prod = 100% Fargate, autres = 70% Fargate + 30% Spot
    base             = local.current_config.min_capacity
  }

  # Fargate Spot pour économiser en dev/staging
  dynamic "default_capacity_provider_strategy" {
    for_each = local.is_production ? [] : [1]
    content {
      capacity_provider = "FARGATE_SPOT"
      weight           = 30
    }
  }
}

# =============================================================================
# CloudWatch Log Groups - Un par service
# =============================================================================
resource "aws_cloudwatch_log_group" "service_logs" {
  for_each = local.accessweaver_services

  name              = "/ecs/${var.project_name}-${var.environment}/${each.value.name}"
  retention_in_days = local.is_production ? 30 : local.is_staging ? 14 : 7

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${var.environment}-${each.value.name}-logs"
    Service = each.value.name
  })
}

# =============================================================================
# Service Discovery - AWS Cloud Map
# =============================================================================
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.project_name}-${var.environment}.local"
  description = "Private DNS namespace for AccessWeaver services"
  vpc         = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-dns-namespace"
  })
}

resource "aws_service_discovery_service" "services" {
  for_each = local.accessweaver_services

  name = each.value.name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  # Note: health_check_grace_period_seconds n'est pas supporté dans aws_service_discovery_service
  # Il sera configuré au niveau du service ECS

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${var.environment}-${each.value.name}-discovery"
    Service = each.value.name
  })
}

# =============================================================================
# IAM Role pour ECS Tasks
# =============================================================================
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role"

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

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Permission pour accéder aux secrets (DB passwords, API keys, etc.)
resource "aws_iam_role_policy" "ecs_secrets_policy" {
  name = "${var.project_name}-${var.environment}-ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"
        ]
      }
    ]
  })
}

# IAM Role pour les tâches (runtime permissions)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-${var.environment}-ecs-task-role"

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

  tags = local.common_tags
}

# Permissions pour services AccessWeaver (CloudWatch, X-Ray, etc.)
resource "aws_iam_role_policy" "ecs_task_runtime_policy" {
  name = "${var.project_name}-${var.environment}-ecs-task-runtime-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.project_name}-${var.environment}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "AccessWeaver/${var.environment}"
          }
        }
      }
    ]
  })
}

# =============================================================================
# Security Group pour ECS Services
# =============================================================================
resource "aws_security_group" "ecs_services" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-services-"
  vpc_id      = var.vpc_id
  description = "Security group for AccessWeaver ECS services"

  # Trafic entrant depuis ALB uniquement (pour services publics)
  ingress {
    description     = "HTTP from ALB"
    from_port       = 8080
    to_port         = 8090  # Range pour tous les services
    protocol        = "tcp"
    security_groups = var.alb_security_group_ids
  }

  # Communication inter-services
  ingress {
    description = "Inter-service communication"
    from_port   = 8080
    to_port     = 8090
    protocol    = "tcp"
    self        = true
  }

  # Accès sortant pour :
  # - Base de données (PostgreSQL)
  # - Cache (Redis)
  # - Internet (updates, API externes)
  egress {
    description = "Database access"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [var.rds_security_group_id]
  }

  egress {
    description = "Redis cache access"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    security_groups = [var.redis_security_group_id]
  }

  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP outbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ecs-services-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Task Definitions - Une par service AccessWeaver
# =============================================================================
resource "aws_ecs_task_definition" "services" {
  for_each = local.accessweaver_services

  family                   = "${var.project_name}-${var.environment}-${each.value.name}"
  network_mode            = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                     = each.value.cpu
  memory                  = each.value.memory
  execution_role_arn      = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn          = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = each.value.name
      image = "${var.container_registry}/${each.value.name}:${var.image_tag}"

      essential = each.value.essential

      portMappings = [
        {
          containerPort = each.value.container_port
          protocol      = "tcp"
        }
      ]

      # Variables d'environnement communes + spécifiques
      environment = concat(
        [
          for key, value in merge(
            var.common_environment_variables,
            each.value.environment_variables
          ) : {
          name  = key
          value = value
        }
        ]
      )

      # Secrets depuis AWS Secrets Manager
      secrets = [
        {
          name      = "DATABASE_PASSWORD"
          valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/database:password::"
        },
        {
          name      = "REDIS_AUTH_TOKEN"
          valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/redis:auth_token::"
        }
      ]

      # Configuration logging
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.service_logs[each.key].name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }

      # Health check pour service discovery
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:${each.value.container_port}${each.value.health_check_path} || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      # Configuration runtime
      cpu    = 0  # CPU allocation relative
      memory = each.value.memory

      # Montages tmpfs pour performance
      mountPoints = []
      volumesFrom = []

      # Configuration réseau
      linuxParameters = {
        initProcessEnabled = true
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${var.environment}-${each.value.name}-task"
    Service = each.value.name
  })
}

# =============================================================================
# ECS Services - Orchestration avec auto-scaling
# =============================================================================
resource "aws_ecs_service" "services" {
  for_each = local.accessweaver_services

  name            = "${var.project_name}-${var.environment}-${each.value.name}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = each.value.desired_count

  # Fargate launch type
  launch_type = "FARGATE"

  # Configuration réseau
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_services.id]
    assign_public_ip = false  # Subnets privés uniquement
  }

  # Service discovery
  service_registries {
    registry_arn = aws_service_discovery_service.services[each.key].arn
  }

  # Configuration ALB pour services publics
  dynamic "load_balancer" {
    for_each = each.value.public ? [1] : []
    content {
      target_group_arn = var.target_group_arns[each.value.name]
      container_name   = each.value.name
      container_port   = each.value.container_port
    }
  }

  # Stratégie de déploiement
  deployment_controller {
    type = "ECS"
  }
  
  # Configuration du déploiement
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = local.is_production ? 100 : 50

  # Délai avant déregistration ALB
  health_check_grace_period_seconds = each.value.public ? local.current_config.health_check_grace_period : null

  # Note: Les target groups ALB sont déjà définis et passés via var.target_group_arns

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${var.environment}-${each.value.name}-service"
    Service = each.value.name
    Public  = tostring(each.value.public)
  })
}

# =============================================================================
# Auto Scaling Configuration
# =============================================================================
resource "aws_appautoscaling_target" "ecs_targets" {
  for_each = local.accessweaver_services

  max_capacity       = local.current_config.max_capacity
  min_capacity       = local.current_config.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.services[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.services]
}

# Scaling policy basé sur CPU
resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  for_each = local.accessweaver_services

  name               = "${var.project_name}-${var.environment}-${each.value.name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_targets[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_targets[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_targets[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = local.is_production ? 70 : 80  # Plus agressif en prod
    scale_out_cooldown = 300  # 5 minutes
    scale_in_cooldown  = 300  # 5 minutes
  }
}

# Scaling policy basé sur mémoire
resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  for_each = local.accessweaver_services

  name               = "${var.project_name}-${var.environment}-${each.value.name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_targets[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_targets[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_targets[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = 80
    scale_out_cooldown = 300
    scale_in_cooldown  = 600  # Plus conservateur pour mémoire
  }
}

# =============================================================================
# Data Sources
# =============================================================================
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}