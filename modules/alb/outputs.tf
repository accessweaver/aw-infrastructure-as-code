# =============================================================================
# AccessWeaver ALB Module - Outputs
# =============================================================================
# Outputs complets pour l'intégration ALB dans AccessWeaver
#
# ORGANISATION:
# 1. Informations ALB principales
# 2. Configuration réseau et sécurité
# 3. Target Groups et intégration ECS
# 4. SSL/TLS et domaines
# 5. WAF et protection
# 6. Monitoring et logging
# 7. URLs et endpoints
# 8. Configuration pour services externes
#
# USAGE:
# Ces outputs sont conçus pour être utilisés par:
# - Documentation automatique
# - Configuration de monitoring externe
# - Scripts de test et validation
# - Intégration avec d'autres modules
# =============================================================================

# =============================================================================
# 1. INFORMATIONS ALB PRINCIPALES
# =============================================================================

output "alb_id" {
  description = <<-EOT
    ID de l'Application Load Balancer créé.

    Format: arn:aws:elasticloadbalancing:region:account:loadbalancer/app/name/id

    Utilisé pour:
    - Références dans d'autres ressources Terraform
    - Commandes AWS CLI pour administration
    - Configuration de monitoring CloudWatch
    - Association avec WAF et autres services AWS
  EOT
  value = aws_lb.main.id
}

output "alb_arn" {
  description = <<-EOT
    ARN complet de l'Application Load Balancer.

    Utilisé pour:
    - Policies IAM cross-account
    - EventBridge rules et automation
    - Association WAF
    - Resource-based policies
  EOT
  value = aws_lb.main.arn
}

output "alb_name" {
  description = <<-EOT
    Nom de l'Application Load Balancer.

    Format: {project_name}-{environment}-alb
    Exemple: "accessweaver-prod-alb"

    Utilisé dans:
    - Scripts d'administration
    - Documentation
    - Commandes AWS CLI
  EOT
  value = aws_lb.main.name
}

output "alb_dns_name" {
  description = <<-EOT
    Nom DNS par défaut de l'ALB fourni par AWS.

    Format: name-1234567890.region.elb.amazonaws.com

    Utilisé quand:
    - Pas de domaine custom configuré
    - Tests et développement
    - Fallback si DNS custom indisponible

    Note: Toujours disponible même avec domaine custom.
  EOT
  value = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = <<-EOT
    Zone ID Route 53 de l'ALB pour configuration d'alias.

    Utilisé pour:
    - Création d'enregistrements Route 53 alias
    - Configuration DNS automatique
    - Health checks Route 53
  EOT
  value = aws_lb.main.zone_id
}

# =============================================================================
# 2. CONFIGURATION RÉSEAU ET SÉCURITÉ
# =============================================================================

output "security_group_id" {
  description = <<-EOT
    ID du security group de l'ALB.

    Ce security group permet:
    - Accès HTTPS (443) depuis les CIDR autorisés
    - Accès HTTP (80) si redirect configuré
    - Accès sortant vers services ECS (8080-8090)

    Utilisé par:
    - Module ECS pour autoriser le trafic entrant
    - Autres services nécessitant l'accès ALB
    - Configuration de monitoring et health checks
  EOT
  value = aws_security_group.alb.id
}

output "security_group_arn" {
  description = <<-EOT
    ARN du security group de l'ALB.

    Utilisé pour:
    - Policies IAM cross-account
    - References dans d'autres modules Terraform
    - Audit de sécurité
  EOT
  value = aws_security_group.alb.arn
}

# =============================================================================
# 3. TARGET GROUPS ET INTÉGRATION ECS
# =============================================================================

output "target_group_arns" {
  description = <<-EOT
    ARNs des target groups créés pour les services publics.

    Map service_name → target_group_arn

    Utilisé par le module ECS pour:
    - Configuration des services ECS avec load_balancer block
    - Health checks et monitoring
    - Auto-scaling basé sur métriques ALB

    Exemple:
    {
      "api-gateway" = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:targetgroup/accessweaver-prod-api-gateway-tg/1234567890123456"
    }
  EOT
  value = {
    for service_name, tg in aws_lb_target_group.services :
    service_name => tg.arn
  }
}

output "target_group_names" {
  description = <<-EOT
    Noms des target groups créés.

    Format: {project_name}-{environment}-{service}-tg

    Utilisé pour:
    - Configuration de monitoring CloudWatch
    - Scripts d'administration
    - Debugging et troubleshooting
  EOT
  value = {
    for service_name, tg in aws_lb_target_group.services :
    service_name => tg.name
  }
}

output "target_group_health_check_config" {
  description = <<-EOT
    Configuration des health checks pour chaque target group.

    Inclut tous les paramètres de health check configurés:
    - Path, interval, timeout
    - Seuils healthy/unhealthy
    - Matcher (codes de réponse acceptés)

    Utilisé pour:
    - Documentation de la configuration
    - Debugging des problèmes de health check
    - Synchronisation avec monitoring externe
  EOT
  value = {
    for service_name, tg in aws_lb_target_group.services :
    service_name => {
      path                = tg.health_check[0].path
      interval            = tg.health_check[0].interval
      timeout             = tg.health_check[0].timeout
      healthy_threshold   = tg.health_check[0].healthy_threshold
      unhealthy_threshold = tg.health_check[0].unhealthy_threshold
      matcher             = tg.health_check[0].matcher
      protocol            = tg.health_check[0].protocol
      port                = tg.health_check[0].port
    }
  }
}

# =============================================================================
# 4. SSL/TLS ET DOMAINES
# =============================================================================

output "ssl_certificate_arn" {
  description = <<-EOT
    ARN du certificat SSL/TLS créé via AWS Certificate Manager.

    null si aucun domaine custom configuré.

    Le certificat inclut:
    - Domaine principal selon l'environnement
    - Subject Alternative Names (SAN) si configurés
    - Validation DNS automatique

    Utilisé pour:
    - Configuration d'autres ALB/CloudFront
    - Monitoring de l'expiration du certificat
    - Audit de sécurité
  EOT
  value = length(aws_acm_certificate.main) > 0 ? aws_acm_certificate.main[0].arn : null
}

output "domain_name" {
  description = <<-EOT
    Nom de domaine configuré pour AccessWeaver.

    Format selon l'environnement:
    - dev: dev.{custom_domain}
    - staging: staging.{custom_domain}
    - prod: {custom_domain}

    null si aucun domaine custom configuré.

    Utilisé pour:
    - Configuration des clients AccessWeaver
    - Documentation d'intégration
    - Tests automatisés
  EOT
  value = local.current_domain
}

output "https_listener_arn" {
  description = <<-EOT
    ARN du listener HTTPS de l'ALB.

    null si aucun certificat SSL configuré.

    Utilisé pour:
    - Ajout de règles de routing supplémentaires
    - Configuration de monitoring
    - Policies IAM
  EOT
  value = length(aws_lb_listener.https) > 0 ? aws_lb_listener.https[0].arn : null
}

output "http_listener_arn" {
  description = <<-EOT
    ARN du listener HTTP de l'ALB.

    Configuration selon l'environnement:
    - Force HTTPS redirect: Redirige vers HTTPS
    - Dev mode: Forward direct vers services

    Utilisé pour:
    - Configuration de règles de routing
    - Monitoring des redirections
  EOT
  value = aws_lb_listener.http.arn
}

# =============================================================================
# 5. WAF ET PROTECTION
# =============================================================================

output "waf_web_acl_arn" {
  description = <<-EOT
    ARN du Web ACL WAF associé à l'ALB.

    null si WAF désactivé.

    Le WAF inclut:
    - Protection contre attaques OWASP Top 10
    - Rate limiting par IP
    - Réputation IP Amazon
    - Whitelist IP (si configurée)

    Utilisé pour:
    - Monitoring des attaques bloquées
    - Configuration d'alertes WAF
    - Audit de sécurité
  EOT
  value = length(aws_wafv2_web_acl.main) > 0 ? aws_wafv2_web_acl.main[0].arn : null
}

output "waf_web_acl_id" {
  description = <<-EOT
    ID du Web ACL WAF pour configuration et monitoring.

    null si WAF désactivé.

    Utilisé pour:
    - Commandes AWS CLI WAF
    - Configuration de règles supplémentaires
    - Monitoring CloudWatch WAF
  EOT
  value = length(aws_wafv2_web_acl.main) > 0 ? aws_wafv2_web_acl.main[0].id : null
}

output "waf_rate_limit_configured" {
  description = <<-EOT
    Limite de taux configurée dans WAF (requêtes par 5 minutes).

    Utilisé pour:
    - Documentation de la configuration
    - Ajustement selon les patterns d'usage
    - Communication avec les équipes client
  EOT
  value = local.current_config.enable_waf ? var.waf_rate_limit : null
}

# =============================================================================
# 6. MONITORING ET LOGGING
# =============================================================================

output "cloudwatch_alarms" {
  description = <<-EOT
    ARNs des alarmes CloudWatch créées pour l'ALB.

    Alarmes configurées:
    - Response time élevé
    - Taux d'erreur 5xx élevé

    Utilisé pour:
    - Integration avec SNS et alerting
    - Dashboard de monitoring
    - Automation de scaling
  EOT
  value = {
    response_time = aws_cloudwatch_metric_alarm.alb_response_time.arn
    error_rate    = aws_cloudwatch_metric_alarm.alb_error_rate.arn
  }
}

output "access_logs_bucket" {
  description = <<-EOT
    Nom du bucket S3 pour les logs d'accès ALB.

    null si logs d'accès désactivés.

    Le bucket inclut:
    - Lifecycle policy pour archivage automatique
    - Retention selon configuration
    - Permissions pour ALB service account

    Utilisé pour:
    - Analyse des logs avec Athena/ELK
    - Export vers outils de monitoring
    - Compliance et audit
  EOT
  value = length(aws_s3_bucket.alb_logs) > 0 ? aws_s3_bucket.alb_logs[0].bucket : null
}

output "access_logs_s3_prefix" {
  description = <<-EOT
    Préfixe S3 pour l'organisation des logs d'accès.

    Structure des logs:
    s3://bucket/alb-access-logs/AWSLogs/account-id/elasticloadbalancing/region/year/month/day/

    Utilisé pour:
    - Requêtes Athena avec partitioning
    - Scripts de traitement des logs
    - Lifecycle policies S3
  EOT
  value = length(aws_s3_bucket.alb_logs) > 0 ? "alb-access-logs" : null
}

# =============================================================================
# 7. URLS ET ENDPOINTS
# =============================================================================

output "public_url" {
  description = <<-EOT
    URL publique principale pour accéder à AccessWeaver.

    Format:
    - Avec domaine custom: https://{domain}
    - Sans domaine custom: https://{alb_dns_name}

    Utilisé pour:
    - Configuration des clients AccessWeaver
    - Tests d'intégration
    - Documentation API
    - Health checks externes
  EOT
  value = local.current_domain != null ? "https://${local.current_domain}" : "https://${aws_lb.main.dns_name}"
}

output "api_base_url" {
  description = <<-EOT
    URL de base pour l'API AccessWeaver.

    Format: {public_url}/api/v1

    Tous les endpoints AccessWeaver sont disponibles sous cette base:
    - POST {api_base_url}/check - Vérification d'autorisation
    - GET {api_base_url}/policies - Liste des policies
    - POST {api_base_url}/users/{id}/roles - Attribution de rôles

    Utilisé pour:
    - Configuration des SDKs AccessWeaver
    - Documentation API
    - Tests automatisés
  EOT
  value = "${local.current_domain != null ? "https://${local.current_domain}" : "https://${aws_lb.main.dns_name}"}/api/v1"
}

output "health_check_url" {
  description = <<-EOT
    URL de health check principal pour monitoring externe.

    Format: {public_url}/actuator/health

    Utilisé pour:
    - Monitoring synthétique (Pingdom, StatusCake)
    - Health checks de CI/CD
    - Monitoring uptime interne

    Réponse attendue: 200 OK avec JSON status
  EOT
  value = "${local.current_domain != null ? "https://${local.current_domain}" : "https://${aws_lb.main.dns_name}"}/actuator/health"
}

output "swagger_ui_url" {
  description = <<-EOT
    URL de l'interface Swagger UI pour la documentation API.

    Format: {public_url}/swagger-ui/index.html

    Utilisé pour:
    - Documentation interactive de l'API
    - Tests manuels des endpoints
    - Onboarding des développeurs

    Note: Peut être désactivé en production selon la politique de sécurité.
  EOT
  value = "${local.current_domain != null ? "https://${local.current_domain}" : "https://${aws_lb.main.dns_name}"}/swagger-ui/index.html"
}

# =============================================================================
# 8. CONFIGURATION POUR SERVICES EXTERNES
# =============================================================================

output "integration_config" {
  description = <<-EOT
    Configuration prête pour l'intégration avec services externes.

    Inclut:
    - URLs principales et endpoints
    - Configuration de health checks
    - Informations SSL/TLS
    - Configuration WAF

    Utilisé pour:
    - Configuration de monitoring (Pingdom, DataDog)
    - Setup de CDN (CloudFront)
    - Integration avec API Gateways
    - Documentation d'architecture
  EOT
  value = {
    # URLs principales
    public_url      = local.current_domain != null ? "https://${local.current_domain}" : "https://${aws_lb.main.dns_name}"
    api_base_url    = "${local.current_domain != null ? "https://${local.current_domain}" : "https://${aws_lb.main.dns_name}"}/api/v1"
    health_check_url = "${local.current_domain != null ? "https://${local.current_domain}" : "https://${aws_lb.main.dns_name}"}/actuator/health"

    # Configuration SSL/TLS
    ssl_enabled     = local.current_domain != null
    ssl_certificate = length(aws_acm_certificate.main) > 0 ? aws_acm_certificate.main[0].arn : null
    ssl_policy      = var.ssl_policy

    # Configuration Health Check
    health_check = {
      path                = var.health_check_path
      expected_status     = "200"
      timeout_seconds     = local.current_config.health_check_timeout
      interval_seconds    = local.current_config.health_check_interval
      healthy_threshold   = var.healthy_threshold
      unhealthy_threshold = local.current_config.unhealthy_threshold
    }

    # Configuration WAF
    waf_enabled     = local.current_config.enable_waf
    waf_rate_limit  = local.current_config.enable_waf ? var.waf_rate_limit : null

    # Configuration réseau
    security_group_id = aws_security_group.alb.id
    vpc_id           = var.vpc_id
    public_subnets   = var.public_subnet_ids

    # Métriques et monitoring
    cloudwatch_metrics = {
      namespace = "AWS/ApplicationELB"
      dimensions = {
        LoadBalancer = aws_lb.main.arn_suffix
      }
    }
  }
}

output "curl_test_commands" {
  description = <<-EOT
    Commandes curl pour tester l'ALB et les services.

    Utilisé pour:
    - Tests manuels après déploiement
    - Validation de la configuration
    - Debugging de connectivité
    - Scripts de CI/CD
  EOT
  value = {
    health_check = "curl -f ${local.current_domain != null ? "https://${local.current_domain}" : "https://${aws_lb.main.dns_name}"}/actuator/health"

    api_info = "curl -f ${local.current_domain != null ? "https://${local.current_domain}" : "https://${aws_lb.main.dns_name}"}/actuator/info"

    api_docs = "curl -f ${local.current_domain != null ? "https://${local.current_domain}" : "https://${aws_lb.main.dns_name}"}/v3/api-docs"

    # Test de base de l'API (nécessite authentification)
    api_test = "curl -H 'Authorization: Bearer YOUR_JWT_TOKEN' ${local.current_domain != null ? "https://${local.current_domain}" : "https://${aws_lb.main.dns_name}"}/api/v1/health"

    # Test redirect HTTP vers HTTPS (si configuré)
    redirect_test = local.current_config.force_https_redirect ? "curl -I http://${aws_lb.main.dns_name}" : "# HTTP redirect not configured"
  }
}

output "monitoring_dashboard_config" {
  description = <<-EOT
    Configuration pour créer des dashboards de monitoring.

    Inclut les métriques principales ALB:
    - RequestCount, TargetResponseTime
    - HTTPCode_Target_2XX_Count, HTTPCode_ELB_5XX_Count
    - TargetConnectionErrorCount
    - NewConnectionCount, ActiveConnectionCount

    Utilisé pour:
    - Configuration de dashboards Grafana/CloudWatch
    - Alerting proactif
    - Capacity planning
  EOT
  value = {
    cloudwatch_metrics = [
      {
        metric_name = "RequestCount"
        namespace   = "AWS/ApplicationELB"
        dimensions = {
          LoadBalancer = aws_lb.main.arn_suffix
        }
        statistic = "Sum"
        description = "Total requests per minute"
      },
      {
        metric_name = "TargetResponseTime"
        namespace   = "AWS/ApplicationELB"
        dimensions = {
          LoadBalancer = aws_lb.main.arn_suffix
        }
        statistic = "Average"
        description = "Average response time"
      },
      {
        metric_name = "HTTPCode_Target_2XX_Count"
        namespace   = "AWS/ApplicationELB"
        dimensions = {
          LoadBalancer = aws_lb.main.arn_suffix
        }
        statistic = "Sum"
        description = "Successful requests"
      },
      {
        metric_name = "HTTPCode_ELB_5XX_Count"
        namespace   = "AWS/ApplicationELB"
        dimensions = {
          LoadBalancer = aws_lb.main.arn_suffix
        }
        statistic = "Sum"
        description = "Server errors"
      }
    ]

    recommended_alarms = [
      {
        name = "HighResponseTime"
        threshold = local.is_production ? 1.0 : 2.0
        comparison = "GreaterThanThreshold"
        description = "ALB response time too high"
      },
      {
        name = "HighErrorRate"
        threshold = 10
        comparison = "GreaterThanThreshold"
        description = "ALB 5xx errors too high"
      }
    ]
  }
}

# =============================================================================
# 9. INFORMATIONS ENVIRONNEMENT ET MÉTADONNÉES
# =============================================================================

output "environment" {
  description = "Environnement de déploiement configuré"
  value       = var.environment
}

output "region" {
  description = "Région AWS où l'ALB est déployé"
  value       = data.aws_region.current.name
}

output "waf_enabled" {
  description = "Status d'activation du WAF"
  value       = local.current_config.enable_waf
}

output "https_redirect_enabled" {
  description = "Status de redirection HTTPS forcée"
  value       = local.current_config.force_https_redirect
}

output "access_logs_enabled" {
  description = "Status d'activation des logs d'accès"
  value       = local.current_config.enable_access_logs
}