# =============================================================================
# AccessWeaver Redis ElastiCache Module
# =============================================================================
# Module optimisé pour le cache distribué d'AccessWeaver
#
# OBJECTIF:
# - Cache haute performance pour les décisions d'autorisation (<1ms)
# - Support multi-tenancy avec namespacing automatique
# - Configuration adaptative selon l'environnement (dev/staging/prod)
# - Sécurité enterprise avec chiffrement et authentification
#
# ARCHITECTURE:
# - Dev: Single node (cost-optimized)
# - Staging: Replication group (2 nodes, 1 replica)
# - Prod: Cluster mode avec sharding (3+ nodes, haute disponibilité)
#
# INTÉGRATION ACCESSWEAVER:
# - Cache L2 pour les décisions RBAC/ABAC/ReBAC
# - Session storage pour les tokens JWT
# - Rate limiting par tenant
# - Pub/Sub pour invalidation de cache cross-services
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
  # Détection de l'environnement pour configuration adaptative
  is_production = var.environment == "prod"
  is_staging    = var.environment == "staging"
  is_dev        = var.environment == "dev"

  # Configuration Redis selon l'environnement
  # DEV: Single node pour économiser les coûts
  # STAGING: Replication group pour tester la HA
  # PROD: Cluster mode avec sharding pour performance et HA
  redis_config = {
    dev = {
      node_type               = "cache.t3.micro"
      num_cache_clusters      = 1
      num_node_groups         = null  # Pas de cluster mode
      replicas_per_node_group = null
      port                    = 6379
      parameter_group_family  = "redis7.x"
      engine_version         = "7.0"
      at_rest_encryption     = true
      transit_encryption     = true
      auth_token_enabled     = true
      multi_az               = false
      automatic_failover     = false
      snapshot_retention     = 1
      snapshot_window        = "03:00-05:00"
      maintenance_window     = "sun:05:00-sun:06:00"
    }
    staging = {
      node_type               = "cache.t3.small"
      num_cache_clusters      = 2        # 1 primary + 1 replica
      num_node_groups         = null     # Pas encore de cluster
      replicas_per_node_group = null
      port                    = 6379
      parameter_group_family  = "redis7.x"
      engine_version         = "7.0"
      at_rest_encryption     = true
      transit_encryption     = true
      auth_token_enabled     = true
      multi_az               = true
      automatic_failover     = true
      snapshot_retention     = 5
      snapshot_window        = "03:00-05:00"
      maintenance_window     = "sun:05:00-sun:07:00"
    }
    prod = {
      node_type               = "cache.r6g.large"
      num_cache_clusters      = null     # Utilise cluster mode
      num_node_groups         = 3        # 3 shards pour distribution
      replicas_per_node_group = 2        # 2 replicas par shard = HA
      port                    = 6379
      parameter_group_family  = "redis7.x"
      engine_version         = "7.0"
      at_rest_encryption     = true
      transit_encryption     = true
      auth_token_enabled     = true
      multi_az               = true
      automatic_failover     = true
      snapshot_retention     = 7
      snapshot_window        = "03:00-05:00"
      maintenance_window     = "sun:05:00-sun:08:00"
    }
  }

  current_config = local.redis_config[var.environment]

  # Utilise cluster mode en production uniquement
  use_cluster_mode = local.is_production

  # Tags communs pour toutes les ressources
  common_tags = {
    Name        = "${var.project_name}-${var.environment}-redis"
    Project     = var.project_name
    Environment = var.environment
    Component   = "cache"
    ManagedBy   = "terraform"
    Service     = "accessweaver-redis"
    Purpose     = "authorization-cache"
  }
}

# =============================================================================
# Random Auth Token Generation
# =============================================================================
# Génération automatique d'un token d'authentification sécurisé
# Le token sera utilisé par les applications pour s'authentifier à Redis
resource "random_password" "auth_token" {
  count   = var.auth_token == null ? 1 : 0
  length  = 64
  special = false  # Redis auth token ne supporte pas les caractères spéciaux
  upper   = true
  lower   = true
  numeric = true

  # Éviter les caractères ambigus
  override_special = ""
}

# =============================================================================
# Subnet Group - Déploiement Multi-AZ dans les subnets privés
# =============================================================================
# Le subnet group définit où Redis peut être déployé
# Utilise uniquement les subnets privés pour la sécurité
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids

  description = "Subnet group for AccessWeaver Redis cluster - private subnets only"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis-subnet-group"
  })
}

# =============================================================================
# Security Group - Accès Redis sécurisé
# =============================================================================
# Security group restrictif permettant uniquement l'accès depuis les services ECS
# Port 6379 (Redis) accessible uniquement depuis les security groups autorisés
resource "aws_security_group" "redis" {
  name_prefix = "${var.project_name}-${var.environment}-redis-"
  vpc_id      = var.vpc_id
  description = "Security group for AccessWeaver Redis cluster"

  # Accès Redis depuis les services ECS uniquement
  ingress {
    description     = "Redis access from ECS services"
    from_port       = local.current_config.port
    to_port         = local.current_config.port
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  # Pas d'accès sortant nécessaire pour ElastiCache
  # (AWS gère les updates et la maintenance)

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Parameter Group - Configuration Redis optimisée pour AccessWeaver
# =============================================================================
# Parameter group personnalisé pour optimiser Redis pour les patterns AccessWeaver
# - Cache de permissions avec TTL adapté
# - Optimisations mémoire pour les clés multi-tenant
# - Configuration Pub/Sub pour invalidation de cache
resource "aws_elasticache_parameter_group" "main" {
  family      = local.current_config.parameter_group_family
  name        = "${var.project_name}-${var.environment}-redis-params"
  description = "Redis parameter group optimized for AccessWeaver authorization cache"

  # Optimisations mémoire pour AccessWeaver

  # Politique d'éviction: LRU sur les clés avec expiration uniquement
  # Parfait pour un cache d'autorisation où on veut garder les permissions actives
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  # Échantillonnage LRU amélioré pour de meilleures décisions d'éviction
  parameter {
    name  = "maxmemory-samples"
    value = "10"
  }

  # Optimisation pour les hash tables (utilisées pour les permissions par tenant)
  parameter {
    name  = "hash-max-ziplist-entries"
    value = "512"  # Optimisé pour les structures de permissions
  }

  parameter {
    name  = "hash-max-ziplist-value"
    value = "64"   # Taille typique d'un identifiant de permission
  }

  # Configuration timeout adaptée aux patterns AccessWeaver
  parameter {
    name  = "timeout"
    value = local.is_production ? "300" : "600"  # Plus strict en prod
  }

  # Logging pour debug (dev/staging uniquement)
  dynamic "parameter" {
    for_each = local.is_production ? [] : [1]
    content {
      name  = "slowlog-log-slower-than"
      value = "10000"  # Log les commandes > 10ms en dev/staging
    }
  }

  dynamic "parameter" {
    for_each = local.is_production ? [] : [1]
    content {
      name  = "slowlog-max-len"
      value = "128"    # Garder les 128 dernières requêtes lentes
    }
  }

  # Notification d'événements clés pour monitoring
  parameter {
    name  = "notify-keyspace-events"
    value = "Ex"  # Notifications d'expiration pour stats
  }

  # Optimisations pour les connexions simultanées (multi-tenant)
  parameter {
    name  = "tcp-keepalive"
    value = "300"
  }

  # Paramètres personnalisés additionnels (si fournis)
  dynamic "parameter" {
    for_each = var.custom_parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Replication Group - Configuration selon l'environnement
# =============================================================================
# Configuration adaptative:
# - DEV: Single node pour économiser
# - STAGING: Replication group (primary + replica)
# - PROD: Cluster mode avec sharding pour haute performance
resource "aws_elasticache_replication_group" "main" {
  replication_group_id         = "${var.project_name}-${var.environment}-redis"
  description                  = "AccessWeaver Redis cluster for ${var.environment} environment"

  # Configuration des nodes
  node_type                    = local.current_config.node_type
  port                        = local.current_config.port
  parameter_group_name        = aws_elasticache_parameter_group.main.name

  # Configuration cluster vs replication
  num_cache_clusters          = local.use_cluster_mode ? null : local.current_config.num_cache_clusters

  # Cluster mode (production uniquement)
  num_node_groups         = local.use_cluster_mode ? local.current_config.num_node_groups : null
  replicas_per_node_group = local.use_cluster_mode ? local.current_config.replicas_per_node_group : null

  # Engine configuration
  engine                      = "redis"
  engine_version              = local.current_config.engine_version

  # Network & Security
  subnet_group_name           = aws_elasticache_subnet_group.main.name
  security_group_ids          = [aws_security_group.redis.id]

  # Encryption & Authentication
  at_rest_encryption_enabled  = local.current_config.at_rest_encryption
  transit_encryption_enabled  = local.current_config.transit_encryption
  auth_token                  = local.current_config.auth_token_enabled ? (var.auth_token != null ? var.auth_token : random_password.auth_token[0].result) : null

  # High Availability (staging et prod)
  multi_az_enabled            = local.current_config.multi_az
  automatic_failover_enabled  = local.current_config.automatic_failover

  # Data durability
  snapshot_retention_limit    = local.current_config.snapshot_retention
  snapshot_window             = local.current_config.snapshot_window
  final_snapshot_identifier   = "${var.project_name}-${var.environment}-redis-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Maintenance
  maintenance_window          = local.current_config.maintenance_window
  auto_minor_version_upgrade  = true

  # Notifications (si SNS topic fourni)
  notification_topic_arn      = var.sns_topic_arn

  # Logging (CloudWatch Logs pour les requêtes lentes)
  dynamic "log_delivery_configuration" {
    for_each = var.enable_slow_log ? [1] : []
    content {
      destination      = aws_cloudwatch_log_group.redis_slow_log[0].name
      destination_type = "cloudwatch-logs"
      log_format       = "text"
      log_type         = "slow-log"
    }
  }

  tags = merge(local.common_tags, var.additional_tags)

  depends_on = [
    aws_elasticache_parameter_group.main,
    aws_elasticache_subnet_group.main
  ]

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      auth_token, # Token géré externellement après création
    ]
  }
}

# =============================================================================
# CloudWatch Log Group - Slow Log (optionnel)
# =============================================================================
# Log group pour capturer les requêtes lentes Redis
# Utile pour optimiser les performances en dev/staging
resource "aws_cloudwatch_log_group" "redis_slow_log" {
  count = var.enable_slow_log ? 1 : 0

  name              = "/aws/elasticache/redis/${var.project_name}-${var.environment}"
  retention_in_days = local.is_production ? 30 : 7

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${var.environment}-redis-slow-log"
    Purpose = "redis-slow-queries"
  })
}

# =============================================================================
# CloudWatch Alarms - Monitoring proactif
# =============================================================================
# Alarmes CloudWatch pour surveiller la santé du cluster Redis
# Couvre les métriques critiques : CPU, mémoire, connexions, cache hits

# Alarm: CPU Utilization
resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"  # 5 minutes
  statistic           = "Average"
  threshold           = "75"   # 75% CPU
  alarm_description   = "Redis CPU utilization is too high"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    CacheClusterId = local.use_cluster_mode ? null : "${aws_elasticache_replication_group.main.replication_group_id}-001"
    ReplicationGroupId = aws_elasticache_replication_group.main.replication_group_id
  }

  tags = local.common_tags
}

# Alarm: Memory Utilization
resource "aws_cloudwatch_metric_alarm" "memory_utilization" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"   # 80% memory
  alarm_description   = "Redis memory utilization is too high"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    CacheClusterId = local.use_cluster_mode ? null : "${aws_elasticache_replication_group.main.replication_group_id}-001"
    ReplicationGroupId = aws_elasticache_replication_group.main.replication_group_id
  }

  tags = local.common_tags
}

# Alarm: Cache Hit Ratio (critique pour les performances AccessWeaver)
resource "aws_cloudwatch_metric_alarm" "cache_hit_ratio" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-cache-hit-ratio"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CacheHitRate"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "0.8"  # 80% hit rate minimum
  alarm_description   = "Redis cache hit ratio is too low - check authorization cache strategy"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    CacheClusterId = local.use_cluster_mode ? null : "${aws_elasticache_replication_group.main.replication_group_id}-001"
    ReplicationGroupId = aws_elasticache_replication_group.main.replication_group_id
  }

  tags = local.common_tags
}

# Alarm: Current Connections
resource "aws_cloudwatch_metric_alarm" "current_connections" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CurrConnections"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  # Seuil adapté selon l'environnement et le type d'instance
  threshold           = local.is_production ? "500" : local.is_staging ? "200" : "100"
  alarm_description   = "Redis connection count is too high"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    CacheClusterId = local.use_cluster_mode ? null : "${aws_elasticache_replication_group.main.replication_group_id}-001"
    ReplicationGroupId = aws_elasticache_replication_group.main.replication_group_id
  }

  tags = local.common_tags
}

# =============================================================================
# Data Sources
# =============================================================================
# Récupération des informations sur les AZ disponibles
data "aws_availability_zones" "available" {
  state = "available"
}