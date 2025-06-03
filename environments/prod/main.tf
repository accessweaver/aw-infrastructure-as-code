# =============================================================================
# AccessWeaver Production Environment - Main Configuration
# =============================================================================
# Configuration complète pour l'environnement de production
# Optimisée pour la haute disponibilité et la sécurité (~$350-500/mois)
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

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
# Provider Configuration
# =============================================================================
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      CostCenter  = "Engineering"
      Repository  = "accessweaver/aw-infrastructure-as-code"
    }
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

# =============================================================================
# Local Variables
# =============================================================================
locals {
  # Common naming convention
  name_prefix = "${var.project_name}-${var.environment}"

  # AZ selection (use all available for production, but limit to 3 for cost)
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # Tags to apply to all resources
  common_tags = merge(
    var.default_tags,
    {
      Environment = var.environment
      Project     = var.project_name
    }
  )
}

# =============================================================================
# Networking - VPC Module
# =============================================================================
module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr          = var.vpc_cidr
  availability_zones = local.azs

  # Production optimizations
  enable_nat_gateway = true
  single_nat_gateway = false  # Multi-AZ for high availability
  one_nat_per_az     = true   # One NAT Gateway per AZ
  enable_flow_logs   = true   # Enable flow logs for security
  flow_logs_retention = 90    # Retain logs for 90 days for compliance

  default_tags = local.common_tags
}

# =============================================================================
# Database - RDS PostgreSQL Module
# =============================================================================
module "rds" {
  source = "../../modules/rds"

  project_name           = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  allowed_security_groups = [module.ecs.security_group_id]

  # Database configuration
  database_name    = var.database_name
  master_username  = var.database_username
  master_password  = var.database_password # From terraform.tfvars

  # Production specific overrides
  instance_class_override        = var.rds_instance_class
  allocated_storage_override     = var.rds_allocated_storage
  backup_retention_period_override = 30  # 30 days backup in production
  multi_az_override              = true  # Multi-AZ for high availability
  enable_read_replica            = true  # Enable read replica for production
  num_read_replicas              = 2     # Two read replicas for high load
  deletion_protection_override   = true  # Protect against accidental deletion
  
  # Enhanced Security
  storage_encrypted              = true  # Encrypt storage
  apply_immediately              = false # Schedule changes during maintenance window
  maintenance_window             = "sun:03:00-sun:05:00" # Maintenance during off-hours
  
  # Enhanced Monitoring
  enhanced_monitoring_interval   = 30    # 30 seconds interval
  performance_insights_enabled   = true  # Enable performance insights
  performance_insights_retention = 731   # Retain for 731 days (2 years)

  # Monitoring
  sns_topic_arn = aws_sns_topic.alerts.arn

  additional_tags = local.common_tags
}

# =============================================================================
# Cache - Redis ElastiCache Module
# =============================================================================
module "redis" {
  source = "../../modules/redis"

  project_name             = var.project_name
  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  allowed_security_groups = [module.ecs.security_group_id]

  # Redis configuration
  auth_token = var.redis_auth_token # From terraform.tfvars

  # Production specific configuration
  node_type_override              = var.redis_node_type
  num_cache_clusters_override     = 3  # Multiple nodes for high availability
  enable_cluster_mode_override    = true  # Enable cluster mode for production
  snapshot_retention_limit        = 30
  num_shards                      = 3     # Multiple shards for better performance
  replicas_per_shard              = 1     # One replica per shard
  automatic_failover_enabled      = true  # Enable automatic failover

  # Maintenance
  maintenance_window              = "sun:03:00-sun:05:00" # Maintenance during off-hours
  apply_immediately               = false # Schedule changes during maintenance window

  # Monitoring
  sns_topic_arn = aws_sns_topic.alerts.arn
  enable_slow_log = true  # Enable slow log for performance monitoring

  additional_tags = local.common_tags
}

# =============================================================================
# Container Orchestration - ECS Module
# =============================================================================
module "ecs" {
  source = "../../modules/ecs"

  project_name               = var.project_name
  environment               = var.environment
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids

  # Integration with other services
  alb_security_group_ids    = [module.alb.security_group_id]
  rds_security_group_id     = module.rds.security_group_id
  redis_security_group_id   = module.redis.security_group_id

  # Container configuration
  container_registry = var.ecr_repository_url
  image_tag         = var.image_tag

  # Production optimizations
  container_insights_enabled = true   # Enable container insights for monitoring
  enable_fargate_spot       = false   # No Spot instances in production for stability
  enable_execute_command    = false   # Disable direct execution for security
  
  # High availability configuration
  min_capacity              = 3       # Minimum number of tasks
  max_capacity              = 10      # Maximum number of tasks
  
  # Auto-scaling configurations
  cpu_high_threshold        = 70      # Scale up when CPU utilization is above 70%
  cpu_low_threshold         = 30      # Scale down when CPU utilization is below 30%
  memory_high_threshold     = 70      # Scale up when memory utilization is above 70%
  memory_low_threshold      = 30      # Scale down when memory utilization is below 30%

  # Environment variables
  common_environment_variables = {
    SPRING_PROFILES_ACTIVE = var.environment
    LOG_LEVEL             = "INFO"
    JAVA_OPTS            = "-Xmx1024m -Xms512m"  # Larger heap for production
  }

  # Target groups from ALB
  target_group_arns = {
    "aw-api-gateway" = module.alb.target_group_arns["api-gateway"]
  }

  additional_tags = local.common_tags
}

# =============================================================================
# Load Balancer - ALB Module
# =============================================================================
module "alb" {
  source = "../../modules/alb"

  project_name           = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  ecs_security_group_id = module.ecs.security_group_id

  # Access configuration
  allowed_cidr_blocks = var.allowed_ip_ranges  # Restricted access for production

  # SSL/Domain
  custom_domain     = var.custom_domain
  route53_zone_id   = var.route53_zone_id
  
  # Production optimizations
  enable_waf         = true   # Enable WAF for security
  enable_access_logs = true   # Enable access logs for auditing
  deletion_protection = true  # Protect against accidental deletion
  
  # Additional security features
  ssl_policy         = "ELBSecurityPolicy-TLS13-1-2-2021-06"  # Modern TLS policy
  idle_timeout       = 60     # 60 seconds idle timeout
  
  # WAF Rules
  waf_rules = {
    "AWSManagedRulesCommonRuleSet"       = 0,
    "AWSManagedRulesKnownBadInputsRuleSet" = 1,
    "AWSManagedRulesSQLiRuleSet"         = 2,
    "AWSManagedRulesLinuxRuleSet"        = 3
  }

  # Monitoring
  sns_topic_arn = aws_sns_topic.alerts.arn

  additional_tags = local.common_tags
}

# =============================================================================
# Secrets Management
# =============================================================================
resource "aws_secretsmanager_secret" "database" {
  name = "${local.name_prefix}/database"
  description = "Database credentials for AccessWeaver ${var.environment}"
  
  recovery_window_in_days = 30  # 30 days recovery window

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    password = module.rds.db_master_password
    endpoint = module.rds.db_instance_endpoint
    port     = module.rds.db_instance_port
    username = module.rds.master_username
    database = module.rds.database_name
  })
}

resource "aws_secretsmanager_secret" "redis" {
  name = "${local.name_prefix}/redis"
  description = "Redis credentials for AccessWeaver ${var.environment}"
  
  recovery_window_in_days = 30  # 30 days recovery window

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({
    auth_token = var.redis_auth_token
    endpoint   = module.redis.primary_endpoint
    port       = module.redis.port
  })
}

resource "aws_secretsmanager_secret" "jwt" {
  name = "${local.name_prefix}/jwt"
  description = "JWT signing secret for AccessWeaver ${var.environment}"
  
  recovery_window_in_days = 30  # 30 days recovery window

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id = aws_secretsmanager_secret.jwt.id
  secret_string = jsonencode({
    secret     = random_password.jwt_secret.result
    expiration = "3600"
  })
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

# =============================================================================
# Monitoring & Alerting
# =============================================================================
resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "alerts_slack" {
  count     = var.slack_webhook_url != null ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "https"
  endpoint  = var.slack_webhook_url
}

resource "aws_sns_topic_subscription" "alerts_pagerduty" {
  count     = var.pagerduty_integration_url != null ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "https"
  endpoint  = var.pagerduty_integration_url
}

# Enhanced CloudWatch Dashboard for production
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
            ["AWS/ECS", "CPUUtilization", "ClusterName", module.ecs.cluster_name, "ServiceName", "${local.name_prefix}-api-gateway"],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", module.ecs.cluster_name, "ServiceName", "${local.name_prefix}-api-gateway"]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Service Metrics"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", module.rds.db_instance_id],
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", module.rds.db_instance_id],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", module.rds.db_instance_id]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Metrics"
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
            ["AWS/ElastiCache", "CPUUtilization", "CacheClusterId", module.redis.cluster_id],
            ["AWS/ElastiCache", "NetworkBytesIn", "CacheClusterId", module.redis.cluster_id],
            ["AWS/ElastiCache", "NetworkBytesOut", "CacheClusterId", module.redis.cluster_id]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Redis Metrics"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", module.alb.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", module.alb.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", module.alb.alb_arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Metrics"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", module.alb.alb_arn_suffix, { "period": 60, "stat": "p50" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", module.alb.alb_arn_suffix, { "period": 60, "stat": "p90" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", module.alb.alb_arn_suffix, { "period": 60, "stat": "p99" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Response Time Percentiles"
        }
      }
    ]
  })
}

# CloudWatch Alarms for critical metrics
resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  alarm_name          = "${local.name_prefix}-api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "This metric monitors 5XX errors from the API Gateway"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    LoadBalancer = module.alb.alb_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "api_latency" {
  alarm_name          = "${local.name_prefix}-api-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  extended_statistic  = "p99"
  threshold           = 0.5  # 500ms
  alarm_description   = "This metric monitors API latency (p99)"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    LoadBalancer = module.alb.alb_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.name_prefix}-rds-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  alarm_name          = "${local.name_prefix}-redis-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors Redis CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    CacheClusterId = module.redis.cluster_id
  }
}

# =============================================================================
# Outputs
# =============================================================================
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.alb.alb_dns_name
}

output "public_url" {
  description = "Public URL to access AccessWeaver"
  value       = module.alb.public_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = module.redis.primary_endpoint
  sensitive   = true
}

output "estimated_monthly_cost" {
  description = "Estimated monthly AWS costs"
  value = {
    vpc    = "$25-40 (Multiple NAT Gateways)"
    rds    = "$100-150 (db.m5.large Multi-AZ + Read Replicas)"
    redis  = "$80-120 (cache.m5.large Cluster Mode)"
    ecs    = "$100-150 (Fargate)"
    alb    = "$45-60 (Application Load Balancer + WAF + Logs)"
    total  = "$350-500/month"
  }
}
