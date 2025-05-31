# =============================================================================
# AccessWeaver RDS PostgreSQL Module
# =============================================================================
# Optimisé pour multi-tenancy avec RLS, haute disponibilité et performance
# Support dev/staging/prod avec scaling automatique selon l'environnement

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
# Local Values - Configuration dynamique selon l'environnement
# =============================================================================
locals {
  # Configuration adaptative selon l'environnement
  is_production = var.environment == "prod"
  is_staging    = var.environment == "staging"
  is_dev        = var.environment == "dev"

  # Paramètres DB selon l'environnement
  db_config = {
    dev = {
      instance_class        = "db.t3.micro"
      allocated_storage     = 20
      max_allocated_storage = 50
      multi_az             = false
      backup_retention     = 1
      backup_window        = "03:00-04:00"
      maintenance_window   = "sun:04:00-sun:05:00"
      deletion_protection  = false
      skip_final_snapshot  = true
    }
    staging = {
      instance_class        = "db.t3.small"
      allocated_storage     = 50
      max_allocated_storage = 200
      multi_az             = true
      backup_retention     = 7
      backup_window        = "03:00-04:00"
      maintenance_window   = "sun:04:00-sun:06:00"
      deletion_protection  = false
      skip_final_snapshot  = false
    }
    prod = {
      instance_class        = "db.r6g.large"
      allocated_storage     = 100
      max_allocated_storage = 1000
      multi_az             = true
      backup_retention     = 30
      backup_window        = "03:00-04:00"
      maintenance_window   = "sun:04:00-sun:06:00"
      deletion_protection  = true
      skip_final_snapshot  = false
    }
  }

  current_config = local.db_config[var.environment]

  common_tags = {
    Name         = "${var.project_name}-${var.environment}-rds"
    Project      = var.project_name
    Environment  = var.environment
    Component    = "database"
    ManagedBy    = "terraform"
    Service      = "accessweaver-rds"
  }
}

# =============================================================================
# Random Password Generation
# =============================================================================
resource "random_password" "master_password" {
  count   = var.master_password == null ? 1 : 0
  length  = 32
  special = true

  # Éviter les caractères problématiques dans les URLs de connexion
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# =============================================================================
# DB Subnet Group - Multi-AZ dans les subnets privés
# =============================================================================
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Security Group - Accès PostgreSQL sécurisé
# =============================================================================
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds-"
  vpc_id      = var.vpc_id
  description = "Security group for AccessWeaver RDS PostgreSQL"

  # PostgreSQL access from ECS services only
  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  # Outbound - minimal required (updates, etc.)
  egress {
    description = "Outbound for updates"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Parameter Group - Configuration PostgreSQL optimisée pour AccessWeaver
# =============================================================================
resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "${var.project_name}-${var.environment}-postgres15-params"

  description = "PostgreSQL parameter group optimized for AccessWeaver multi-tenancy"

  # Optimisations pour AccessWeaver

  # Performance - Connection Management
  parameter {
    name  = "max_connections"
    value = local.is_production ? "200" : local.is_staging ? "100" : "50"
  }

  # Performance - Memory
  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements,auto_explain"
  }

  parameter {
    name  = "effective_cache_size"
    value = local.is_production ? "2GB" : local.is_staging ? "1GB" : "512MB"
  }

  # Performance - Query optimization
  parameter {
    name  = "random_page_cost"
    value = "1.1" # SSD optimized
  }

  parameter {
    name  = "effective_io_concurrency"
    value = "200" # SSD optimized
  }

  # Logging pour debugging et audit
  parameter {
    name  = "log_statement"
    value = local.is_production ? "ddl" : "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = local.is_production ? "1000" : "500" # Log slow queries
  }

  # Row Level Security - Essential pour multi-tenancy
  parameter {
    name  = "row_security"
    value = "on"
  }

  # Auto-explain pour diagnostics
  parameter {
    name  = "auto_explain.log_min_duration"
    value = "2000"
  }

  parameter {
    name  = "auto_explain.log_analyze"
    value = "on"
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# RDS Instance - PostgreSQL 15 avec haute disponibilité
# =============================================================================
resource "aws_db_instance" "main" {
  # Instance Configuration
  identifier = "${var.project_name}-${var.environment}-postgres"
  engine     = "postgres"
  engine_version = "15.4"

  # Compute & Storage
  instance_class        = local.current_config.instance_class
  allocated_storage     = local.current_config.allocated_storage
  max_allocated_storage = local.current_config.max_allocated_storage
  storage_type         = "gp3"
  storage_encrypted    = true
  kms_key_id          = var.kms_key_id

  # High Availability
  multi_az               = local.current_config.multi_az
  availability_zone      = local.current_config.multi_az ? null : data.aws_availability_zones.available.names[0]

  # Database Configuration
  db_name  = var.database_name
  username = var.master_username
  password = var.master_password != null ? var.master_password : random_password.master_password[0].result
  port     = 5432

  # Network & Security
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  publicly_accessible    = false

  # Parameter & Option Groups
  parameter_group_name = aws_db_parameter_group.main.name

  # Backup Configuration
  backup_retention_period   = local.current_config.backup_retention
  backup_window            = local.current_config.backup_window
  copy_tags_to_snapshot    = true
  delete_automated_backups = local.is_production ? false : true

  # Maintenance
  maintenance_window         = local.current_config.maintenance_window
  auto_minor_version_upgrade = true
  allow_major_version_upgrade = false

  # Lifecycle Protection
  deletion_protection = local.current_config.deletion_protection
  skip_final_snapshot = local.current_config.skip_final_snapshot
  final_snapshot_identifier = local.current_config.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Performance Insights (Prod only)
  performance_insights_enabled = local.is_production
  performance_insights_retention_period = local.is_production ? 7 : null

  # Monitoring
  monitoring_interval = local.is_production ? 60 : 0
  monitoring_role_arn = local.is_production ? aws_iam_role.rds_monitoring[0].arn : null

  # Enhanced Monitoring tags
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-postgres"
  })

  depends_on = [
    aws_db_parameter_group.main,
    aws_db_subnet_group.main
  ]

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      password, # Password managed externally after initial creation
    ]
  }
}

# =============================================================================
# Read Replica - Staging et Prod uniquement
# =============================================================================
resource "aws_db_instance" "read_replica" {
  count = (local.is_staging || local.is_production) ? 1 : 0

  identifier = "${var.project_name}-${var.environment}-postgres-replica"

  # Source DB
  replicate_source_db = aws_db_instance.main.identifier

  # Instance Configuration (peut être différente de la source)
  instance_class = local.is_production ? "db.r6g.large" : "db.t3.small"

  # Network
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Monitoring
  performance_insights_enabled = local.is_production
  monitoring_interval = local.is_production ? 60 : 0
  monitoring_role_arn = local.is_production ? aws_iam_role.rds_monitoring[0].arn : null

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-postgres-replica"
    Role = "read-replica"
  })

  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# IAM Role pour Enhanced Monitoring (Prod uniquement)
# =============================================================================
resource "aws_iam_role" "rds_monitoring" {
  count = local.is_production ? 1 : 0

  name = "${var.project_name}-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = local.is_production ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# =============================================================================
# CloudWatch Alarms - Monitoring proactif
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "database_connections" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-connection-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "120"
  statistic           = "Average"
  threshold           = local.is_production ? "160" : local.is_staging ? "80" : "40"
  alarm_description   = "This metric monitors RDS connection count"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = local.common_tags
}

# =============================================================================
# Data Sources
# =============================================================================
data "aws_availability_zones" "available" {
  state = "available"
}