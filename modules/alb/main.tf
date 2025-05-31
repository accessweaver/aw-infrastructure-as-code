# =============================================================================
# AccessWeaver ALB Module
# =============================================================================
# Module pour déployer Application Load Balancer avec SSL termination
#
# OBJECTIF:
# - Point d'entrée unique pour AccessWeaver avec haute disponibilité
# - SSL/TLS termination avec certificats AWS Certificate Manager
# - Routing intelligent vers les services ECS (API Gateway principalement)
# - Protection WAF intégrée contre attaques communes
# - Health checks avancés avec retry logic et circuit breaker
#
# ARCHITECTURE:
# - ALB Internet-facing dans subnets publics Multi-AZ
# - Target Groups pour services ECS publics (aw-api-gateway)
# - Listeners HTTP (redirect HTTPS) et HTTPS (terminaison SSL)
# - Security Groups restrictifs (HTTPS from internet, HTTP to ECS)
# - Integration avec Route 53 pour domaine custom
#
# INTÉGRATION ACCESSWEAVER:
# - Point d'entrée principal : https://api.accessweaver.com
# - Routing par path : /api/v1/* → aw-api-gateway
# - Health checks : /actuator/health sur chaque service
# - Sticky sessions désactivées (stateless JWT)
# =============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

  # Configuration ALB selon environnement
  alb_config = {
    dev = {
      # Dev : Configuration simple et économique
      enable_deletion_protection = false
      enable_cross_zone_load_balancing = false
      enable_http2 = true
      idle_timeout = 60

      # Target group health checks plus permissifs
      health_check_interval = 30
      health_check_timeout = 10
      health_check_threshold = 2
      unhealthy_threshold = 3
      health_check_path = "/actuator/health"
      health_check_matcher = "200"

      # Security : HTTP autorisé pour debug
      force_https_redirect = false
      enable_waf = false

      # Logging basique
      enable_access_logs = false
    }
    staging = {
      # Staging : Configuration intermédiaire pour test
      enable_deletion_protection = false
      enable_cross_zone_load_balancing = true
      enable_http2 = true
      idle_timeout = 60

      # Target group health checks équilibrés
      health_check_interval = 30
      health_check_timeout = 5
      health_check_threshold = 2
      unhealthy_threshold = 3
      health_check_path = "/actuator/health"
      health_check_matcher = "200"

      # Security : HTTPS recommandé
      force_https_redirect = true
      enable_waf = true

      # Logging pour debug
      enable_access_logs = true
    }
    prod = {
      # Production : Configuration robuste et sécurisée
      enable_deletion_protection = true
      enable_cross_zone_load_balancing = true
      enable_http2 = true
      idle_timeout = 60

      # Target group health checks stricts
      health_check_interval = 15
      health_check_timeout = 5
      health_check_threshold = 2
      unhealthy_threshold = 2
      health_check_path = "/actuator/health"
      health_check_matcher = "200"

      # Security : HTTPS obligatoire
      force_https_redirect = true
      enable_waf = true

      # Logging complet pour audit
      enable_access_logs = true
    }
  }

  current_config = local.alb_config[var.environment]

  # Services publics AccessWeaver exposés via ALB
  # Seuls ces services auront des target groups
  public_services = {
    api-gateway = {
      name = "aw-api-gateway"
      port = 8080
      protocol = "HTTP"
      health_check_path = "/actuator/health"
      priority = 100  # Priorité listener rule

      # Patterns de routing
      path_patterns = [
        "/api/*",           # API REST principal
        "/actuator/*",      # Endpoints management Spring Boot
        "/swagger-ui/*",    # Documentation API
        "/v3/api-docs/*"    # OpenAPI specification
      ]

      # Health check spécifique
      health_check_grace_period = 120  # Spring Boot startup time
      deregistration_delay = 30

      # Sticky sessions désactivées (JWT stateless)
      stickiness_enabled = false
    }
  }

  # Domaine par environnement
  domain_config = {
    dev     = var.custom_domain != null ? "dev.${var.custom_domain}" : null
    staging = var.custom_domain != null ? "staging.${var.custom_domain}" : null
    prod    = var.custom_domain != null ? var.custom_domain : null
  }

  current_domain = local.domain_config[var.environment]

  # Tags communs pour toutes les ressources ALB
  common_tags = {
    Name        = "${var.project_name}-${var.environment}-alb"
    Project     = var.project_name
    Environment = var.environment
    Component   = "load-balancer"
    ManagedBy   = "terraform"
    Service     = "accessweaver-alb"
    Purpose     = "public-api-gateway"
  }
}

# =============================================================================
# S3 Bucket pour Access Logs (si activé)
# =============================================================================
resource "aws_s3_bucket" "alb_logs" {
  count = local.current_config.enable_access_logs ? 1 : 0

  bucket = "${var.project_name}-${var.environment}-alb-access-logs-${random_string.bucket_suffix[0].result}"

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${var.environment}-alb-logs"
    Purpose = "alb-access-logging"
  })
}

resource "aws_s3_bucket_policy" "alb_logs" {
  count = local.current_config.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_elb_service_account.main.id}:root"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs[0].arn
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  count = local.current_config.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    id     = "alb_logs_lifecycle"
    status = "Enabled"

    # Filtre vide requis par le provider AWS (pour tous les objets)
    filter {}

    # Transition vers IA après 30 jours
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Transition vers Glacier après 90 jours
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Suppression après rétention configurée
    expiration {
      days = var.access_logs_retention_days
    }
  }
}

resource "random_string" "bucket_suffix" {
  count = local.current_config.enable_access_logs ? 1 : 0

  length  = 8
  special = false
  upper   = false
}

# =============================================================================
# Security Group ALB - Accès public sécurisé
# =============================================================================
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  vpc_id      = var.vpc_id
  description = "Security group for AccessWeaver Application Load Balancer"

  # Trafic entrant HTTPS depuis internet
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Trafic entrant HTTP depuis internet (pour redirect HTTPS)
  dynamic "ingress" {
    for_each = local.current_config.force_https_redirect || !local.is_production ? [1] : []
    content {
      description = "HTTP from internet (redirect to HTTPS)"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  # Trafic sortant vers ECS services
  egress {
    description     = "HTTP to ECS services"
    from_port       = 8080
    to_port         = 8090  # Range pour tous les services AccessWeaver
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Application Load Balancer
# =============================================================================
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false  # Internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = var.public_subnet_ids

  # Protection et performance selon environnement
  enable_deletion_protection       = local.current_config.enable_deletion_protection
  enable_cross_zone_load_balancing = local.current_config.enable_cross_zone_load_balancing
  enable_http2                    = local.current_config.enable_http2
  idle_timeout                    = local.current_config.idle_timeout

  # Access logs vers S3 (si activé)
  dynamic "access_logs" {
    for_each = local.current_config.enable_access_logs ? [1] : []
    content {
      bucket  = aws_s3_bucket.alb_logs[0].bucket
      prefix  = "alb-access-logs"
      enabled = true
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-alb"
  })
}

# =============================================================================
# Target Groups - Un par service public AccessWeaver
# =============================================================================
resource "aws_lb_target_group" "services" {
  for_each = local.public_services

  name     = "${var.project_name}-${var.environment}-${each.key}-tg"
  port     = each.value.port
  protocol = each.value.protocol
  vpc_id   = var.vpc_id

  # Configuration pour ECS Fargate (target type IP)
  target_type = "ip"

  # Health check configuration optimisée pour Spring Boot
  health_check {
    enabled             = true
    healthy_threshold   = local.current_config.health_check_threshold
    unhealthy_threshold = local.current_config.unhealthy_threshold
    timeout             = local.current_config.health_check_timeout
    interval            = local.current_config.health_check_interval
    path                = each.value.health_check_path
    matcher             = local.current_config.health_check_matcher
    protocol            = each.value.protocol
    port                = "traffic-port"
  }

  # Configuration de déregistration
  deregistration_delay = each.value.deregistration_delay

  # Sticky sessions (désactivées pour JWT stateless)
  dynamic "stickiness" {
    for_each = each.value.stickiness_enabled ? [1] : []
    content {
      type            = "lb_cookie"
      cookie_duration = 86400  # 24 heures
      enabled         = true
    }
  }

  # Load balancing algorithm
  load_balancing_algorithm_type = "round_robin"

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${var.environment}-${each.key}-tg"
    Service = each.value.name
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# SSL Certificate - AWS Certificate Manager
# =============================================================================
resource "aws_acm_certificate" "main" {
  count = local.current_domain != null ? 1 : 0

  domain_name       = local.current_domain
  validation_method = "DNS"

  # SAN pour wildcard et domaines additionnels
  subject_alternative_names = var.certificate_alternative_names

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ssl-cert"
  })
}

# =============================================================================
# HTTPS Listener - Listener principal avec SSL termination
# =============================================================================
resource "aws_lb_listener" "https" {
  count = local.current_domain != null ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"  # TLS 1.2+ uniquement
  certificate_arn   = aws_acm_certificate.main[0].arn

  # Action par défaut : forward vers API Gateway
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services["api-gateway"].arn
  }

  tags = local.common_tags
}

# =============================================================================
# HTTP Listener - Redirect vers HTTPS ou forward direct
# =============================================================================
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Action par défaut selon configuration
  default_action {
    type = local.current_config.force_https_redirect ? "redirect" : "forward"

    # Redirect HTTPS si configuré
    dynamic "redirect" {
      for_each = local.current_config.force_https_redirect ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"  # Permanent redirect
      }
    }

    # Forward direct si pas de HTTPS redirect
    target_group_arn = local.current_config.force_https_redirect ? null : aws_lb_target_group.services["api-gateway"].arn
  }

  tags = local.common_tags
}

# =============================================================================
# Listener Rules - Routing avancé par path
# =============================================================================
resource "aws_lb_listener_rule" "api_routes" {
  for_each = local.current_domain != null ? local.public_services : {}

  listener_arn = aws_lb_listener.https[0].arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.path_patterns
    }
  }

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${var.environment}-${each.key}-rule"
    Service = each.value.name
  })
}

# =============================================================================
# WAF Web ACL - Protection contre attaques (staging/prod)
# =============================================================================
resource "aws_wafv2_web_acl" "main" {
  count = local.current_config.enable_waf ? 1 : 0

  name  = "${var.project_name}-${var.environment}-waf"
  scope = "REGIONAL"  # Pour ALB (CLOUDFRONT pour CloudFront)

  default_action {
    allow {}
  }

  # Règle 1 : Protection contre attaques communes
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Règle 2 : Protection contre bots malveillants
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "IpReputationListMetric"
      sampled_requests_enabled   = true
    }
  }

  # Règle 3 : Rate limiting par IP
  rule {
    name     = "RateLimitRule"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitMetric"
      sampled_requests_enabled   = true
    }
  }

  # Règle 4 : Whitelist d'IPs (optionnelle)
  dynamic "rule" {
    for_each = length(var.waf_whitelist_ips) > 0 ? [1] : []
    content {
      name     = "WhitelistRule"
      priority = 0  # Priorité maximale

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.whitelist[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "WhitelistMetric"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "AccessWeaverWAF"
    sampled_requests_enabled   = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-waf"
  })
}

# IP Set pour whitelist WAF
resource "aws_wafv2_ip_set" "whitelist" {
  count = local.current_config.enable_waf && length(var.waf_whitelist_ips) > 0 ? 1 : 0

  name               = "${var.project_name}-${var.environment}-whitelist"
  description        = "Whitelist IPs for AccessWeaver"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.waf_whitelist_ips

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ip-whitelist"
  })
}

# Association WAF avec ALB
resource "aws_wafv2_web_acl_association" "main" {
  count = local.current_config.enable_waf ? 1 : 0

  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn
}

# =============================================================================
# Route 53 Record - DNS pour domaine custom
# =============================================================================
resource "aws_route53_record" "main" {
  count = local.current_domain != null && var.route53_zone_id != null ? 1 : 0

  zone_id = var.route53_zone_id
  name    = local.current_domain
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# =============================================================================
# CloudWatch Alarms - Monitoring ALB
# =============================================================================
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"  # 5 minutes
  statistic           = "Average"
  threshold           = local.is_production ? "1.0" : "2.0"  # Plus strict en prod
  alarm_description   = "ALB response time is too high"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "alb_error_rate" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"  # Plus de 10 erreurs 5xx en 5 minutes
  alarm_description   = "ALB 5xx error rate is too high"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = local.common_tags
}

# =============================================================================
# Data Sources
# =============================================================================
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_elb_service_account" "main" {}