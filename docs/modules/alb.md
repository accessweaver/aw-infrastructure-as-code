# 🚀 Module Application Load Balancer - AccessWeaver

Module Terraform pour déployer un Application Load Balancer haute disponibilité pour AccessWeaver avec SSL/TLS termination, routing intelligent, et protection WAF intégrée.

## 🎯 Objectifs

### ✅ Point d'Entrée Unique et Sécurisé
- **Point d'entrée unique** pour l'ensemble des services AccessWeaver
- **SSL/TLS termination** avec certificats AWS Certificate Manager
- **HTTPS par défaut** avec redirection automatique depuis HTTP
- **Protection WAF intégrée** contre les attaques web courantes
- **Logging d'accès complet** pour audit et sécurité

### ✅ Haute Disponibilité et Performance
- **Déploiement Multi-AZ** pour éliminer les points de défaillance
- **Health checks avancés** avec retry logic et circuit breaker
- **HTTP/2 support** pour améliorer les performances
- **Cross-zone load balancing** pour équilibrer la charge
- **TLS 1.2+ support** avec cipher suites modernes

### ✅ Routing Intelligent
- **Routing par path/host** vers les bons services
- **Priorités configurables** pour les règles de routing
- **Target groups** pour les services AccessWeaver
- **Sticky sessions** configurables (désactivées par défaut)
- **Connexion aux services privés** via security groups

### ✅ Integration Complète
- **Route 53 DNS** avec domaine personnalisé
- **CloudWatch monitoring** avec métriques détaillées
- **Access logs** dans S3 pour audit
- **Compatibilité WAFv2** pour protection avancée
- **Configuration Spring Boot** générée automatiquement

## 🏗 Architecture par Environnement

### 🔧 Développement
```
┌─────────────────────────────────────────────────────────┐
│                       Internet                           │
│                          │                              │
│            HTTP (80)       │      HTTPS (443)           │
│                │             │                        │
│ ┌─────────────┴──────────┴───────────────────────┐ │
│ │                  ALB                               │ │
│ │          (Subnets Publics, Multi-AZ)                │ │
│ │          - HTTP autorisé (pour dev)                 │ │
│ │          - Health checks permissifs                  │ │
│ │          - WAF désactivé                           │ │
│ │          - Access logs désactivés                   │ │
│ └────────────────────────────────────────────────┘ │
│                          │                              │
│ ┌───────────────────┴──────────────────────────┐ │
│ │           Target Group: API Gateway                 │ │
│ │         - Health check: /actuator/health            │ │
│ │         - Routing: /api/*, /actuator/*, etc.         │ │
│ └────────────────────────────────────────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 🔧 Staging (Pré-production)
```
┌─────────────────────────────────────────────────────────┐
│                       Internet                           │
│                          │                              │
│            HTTP (80)       │      HTTPS (443)           │
│               ↓              │                        │
│         [Redirection HTTPS]     │                        │
│                                 │                        │
│ ┌───────────────────────────┴───────────────────┐ │
│ │                 ALB + WAF                           │ │
│ │          (Subnets Publics, Multi-AZ)                │ │
│ │          - Redirection HTTPS forcée                  │ │
│ │          - Health checks optimisés                   │ │
│ │          - WAF activé                               │ │
│ │          - Access logs dans S3                       │ │
│ └────────────────────────────────────────────────┘ │
│                          │                              │
│ ┌───────────────────┴──────────────────────────┐ │
│ │           Target Group: API Gateway                 │ │
│ │         - Health check: /actuator/health            │ │
│ │         - Routing: /api/*, /actuator/*, etc.         │ │
│ │         - Cross-zone load balancing                  │ │
│ └────────────────────────────────────────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 🔧 Production
```
┌─────────────────────────────────────────────────────────┐
│                       Internet                           │
│                          │                              │
│            HTTP (80)       │      HTTPS (443)           │
│               ↓              │                        │
│         [Redirection HTTPS]     │                        │
│                                 │                        │
│ ┌───────────────────────────┴───────────────────┐ │
│ │             ALB + WAF (Protection complète)          │ │
│ │          (Subnets Publics, Multi-AZ)                │ │
│ │          - Redirection HTTPS stricte                  │ │
│ │          - Health checks stricts                      │ │
│ │          - WAF avec règles avancées                  │ │
│ │          - Access logs complets dans S3               │ │
│ │          - Protection suppression activée             │ │
│ └────────────────────────────────────────────────┘ │
│                          │                              │
│ ┌───────────────────┴──────────────────────────┐ │
│ │           Target Group: API Gateway                 │ │
│ │         - Health check: /actuator/health            │ │
│ │         - Routing: /api/*, /actuator/*, etc.         │ │
│ │         - Cross-zone load balancing                  │ │
│ └────────────────────────────────────────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## 🔐 Configurations de Sécurité

### 📊 Matrice de Sécurité

| Feature | Dev | Staging | Prod |
|---------|-----|---------|------|
| **Redirection HTTPS** | ❌ | ✅ | ✅ |
| **SSL/TLS Moderne** | ✅ | ✅ | ✅ |
| **WAF de Base** | ❌ | ✅ | ✅ |
| **WAF Avancé** | ❌ | ❌ | ✅ |
| **Access Logs** | ❌ | ✅ | ✅ |
| **Protection Suppression** | ❌ | ❌ | ✅ |
| **Health Checks Stricts** | ❌ | ✅ | ✅ |
| **Cross-Zone Load Balancing** | ❌ | ✅ | ✅ |

### 🔒 Règles WAF Implémentées

| Règle WAF | Description | Environnements |
|------------|-------------|---------------|
| **Core Rule Set** | Protège contre OWASP Top 10 | Staging, Prod |
| **Rate Limiting** | Limite le nombre de requêtes par IP | Staging, Prod |
| **Geo Blocking** | Bloque les pays à risque | Prod |
| **Bad Bot Blocking** | Détection et blocage des bots malveillants | Prod |
| **SQL Injection** | Protection avancée contre les injections SQL | Staging, Prod |
| **XSS Protection** | Filtrage des attaques Cross-Site Scripting | Staging, Prod |
| **Log4j Protection** | Filtre les attaques Log4Shell | Staging, Prod |
| **Sensitive Data** | Protection des données sensibles | Prod |

## 📝 Configuration et Utilisation

### 📋 Variables Requises

| Variable | Description | Type | Validation |
|----------|-------------|------|------------|
| `project_name` | Nom du projet (accessweaver) | `string` | Lettres minuscules, chiffres, tirets |
| `environment` | Environnement (`dev`, `staging`, `prod`) | `string` | Valeurs strictes |
| `vpc_id` | ID du VPC où déployer l'ALB | `string` | Format AWS vpc-* |
| `public_subnet_ids` | Liste des IDs des subnets publics | `list(string)` | Min 2 subnets |
| `target_group_arns` | ARNs des target groups ECS | `list(string)` | Format AWS ARN |

### 📋 Variables SSL/TLS et Domaine

| Variable | Description | Type | Default |
|----------|-------------|------|----------|
| `acm_certificate_arn` | ARN du certificat ACM pour HTTPS | `string` | `null` (HTTP uniquement) |
| `custom_domain` | Domaine personnalisé (ex: accessweaver.com) | `string` | `null` (DNS AWS par défaut) |
| `ssl_policy` | Politique SSL/TLS | `string` | `ELBSecurityPolicy-TLS-1-2-2017-01` |
| `force_https` | Forcer la redirection HTTP vers HTTPS | `bool` | Basé sur l'environnement |

### 📋 Variables WAF et Sécurité

| Variable | Description | Type | Default |
|----------|-------------|------|----------|
| `enable_waf` | Activer la protection WAF | `bool` | Basé sur l'environnement |
| `waf_rules` | Liste des règles WAF à activer | `list(string)` | Basé sur l'environnement |
| `blocked_countries` | Liste des pays à bloquer (production) | `list(string)` | `[]` |
| `rate_limit` | Nombre max de requêtes par IP/5min | `number` | `2000` (prod), `5000` (staging) |

### 📋 Variables Health Checks et Target Groups

| Variable | Description | Type | Default |
|----------|-------------|------|----------|
| `health_check_path` | Path pour les health checks | `string` | `/actuator/health` |
| `health_check_interval` | Intervalle entre checks (secondes) | `number` | Basé sur l'environnement |
| `health_check_timeout` | Timeout des health checks | `number` | Basé sur l'environnement |
| `health_check_threshold` | Nombre de succès avant healthy | `number` | Basé sur l'environnement |
| `health_check_matcher` | Codes HTTP considérés healthy | `string` | `200` |

### 📋 Variables Logging et Monitoring

| Variable | Description | Type | Default |
|----------|-------------|------|----------|
| `enable_access_logs` | Activer les logs d'accès dans S3 | `bool` | Basé sur l'environnement |
| `log_retention_days` | Durée de rétention des logs | `number` | `90` (prod), `30` (staging), `7` (dev) |
| `create_cloudwatch_alarms` | Créer des alertes CloudWatch | `bool` | `true` en prod, `false` en dev |
| `notification_topic_arn` | ARN du topic SNS pour alertes | `string` | `null` |

### 📤 Outputs Principaux

| Output | Description | Exemple |
|--------|-------------|----------|
| `alb_id` | ID de l'ALB créé | `arn:aws:elasticloadbalancing:...` |
| `alb_dns_name` | Nom DNS par défaut de l'ALB | `accessweaver-prod-alb-123456789.region.elb.amazonaws.com` |
| `alb_zone_id` | Zone ID Route 53 de l'ALB | `Z35SXDOTRQ7X7K` |
| `custom_domain_url` | URL avec domaine personnalisé | `https://api.accessweaver.com` |
| `security_group_id` | ID du security group de l'ALB | `sg-0123456789abcdef0` |
| `target_group_ids` | Map des IDs des target groups | `{"api-gateway" = "arn:aws:elasticloadbalancing:..."}` |

## 🧩 Exemples d'Utilisation

### 📦 Module de Base (Environnement de Dev)

```hcl
module "alb" {
  source = "./modules/alb"

  project_name      = "accessweaver"
  environment       = "dev"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  
  # En dev, on se connecte aux services ECS mais sans exigences strictes
  target_group_arns = [module.ecs.api_gateway_target_group_arn]
}
```

### 📦 Staging avec HTTPS et WAF

```hcl
module "alb" {
  source = "./modules/alb"

  project_name        = "accessweaver"
  environment         = "staging"
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  target_group_arns   = [module.ecs.api_gateway_target_group_arn]
  
  # Configuration SSL/TLS
  custom_domain       = "accessweaver.com"
  acm_certificate_arn = "arn:aws:acm:eu-west-1:123456789012:certificate/abcdef-1234-5678-abcd-12345678abcd"
  
  # Configuration WAF basique
  waf_rules = [
    "AWSManagedRulesCommonRuleSet",
    "AWSManagedRulesKnownBadInputsRuleSet",
    "AWSManagedRulesSQLiRuleSet"
  ]
  
  # Configuration des logs
  enable_access_logs = true
  log_retention_days = 30
}
```

### 📦 Production Complète avec Toutes les Protections

```hcl
module "alb" {
  source = "./modules/alb"

  project_name        = "accessweaver"
  environment         = "prod"
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  target_group_arns   = [module.ecs.api_gateway_target_group_arn]
  
  # Configuration domaine et SSL
  custom_domain       = "accessweaver.com"
  acm_certificate_arn = "arn:aws:acm:eu-west-1:123456789012:certificate/abcdef-1234-5678-abcd-12345678abcd"
  ssl_policy          = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
  
  # Configuration WAF avancée
  waf_rules = [
    "AWSManagedRulesCommonRuleSet",
    "AWSManagedRulesKnownBadInputsRuleSet",
    "AWSManagedRulesSQLiRuleSet",
    "AWSManagedRulesLinuxRuleSet",
    "AWSManagedRulesAmazonIpReputationList"
  ]
  blocked_countries = ["CN", "RU", "KP", "IR"]
  rate_limit        = 1500
  
  # Monitoring avancé
  enable_access_logs    = true
  log_retention_days    = 90
  create_cloudwatch_alarms = true
  notification_topic_arn = aws_sns_topic.alerts.arn
}
```

## 🔄 Intégration avec AccessWeaver

### 🔧 Intégration avec Module ECS

L'ALB est généralement utilisé en combinaison avec le module ECS pour exposer l'API Gateway et d'autres services publics :

```hcl
# Infrastructure complète AccessWeaver
module "vpc" {
  source = "./modules/vpc"
  # ...
}

module "alb" {
  source = "./modules/alb"
  
  project_name      = "accessweaver"
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  target_group_arns = [module.ecs.api_gateway_target_group_arn]
  # ...
}

module "ecs" {
  source = "./modules/ecs"
  
  project_name = "accessweaver"
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  # Utilisation de l'ALB pour exposer les services
  lb_security_group_id = module.alb.security_group_id
  # ...
}
```

### 🔧 Route 53 et DNS Personnalisé

Configuration d'un domaine personnalisé avec Route 53 :

```hcl
resource "aws_route53_zone" "main" {
  name = "accessweaver.com"
}

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.environment == "prod" ? "api" : "${var.environment}-api"
  type    = "A"
  
  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}
```

### 🔧 Configuration Spring Boot

Voici comment configurer une application Spring Boot pour utiliser l'URL générée par l'ALB :

```yaml
# application.yml
server:
  forward-headers-strategy: native
  servlet:
    context-path: /

spring:
  application:
    name: aw-api-gateway
    
management:
  endpoints:
    web:
      base-path: /actuator
      exposure:
        include: health,info,metrics
  endpoint:
    health:
      show-details: always
      probes:
        enabled: true
```

### 🔑 TLS/SSL et Sécurité

Configuration supplémentaire des en-têtes de sécurité dans les responses HTTP :

```hcl
resource "aws_lb_listener_rule" "security_headers" {
  listener_arn = module.alb.https_listener_arn
  priority     = 1

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }

  condition {
    http_header {
      http_header_name = "User-Agent"
      values           = ["BadBot", "Scraper", "*Vulnerability*Scanner*"]
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "${var.project_name}-${var.environment}-security-headers"

  security_headers_config {
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "same-origin"
      override        = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
  }
}
```

## 📈 Monitoring et Alertes

### 📊 Métriques CloudWatch

Le module ALB configure plusieurs métriques CloudWatch importantes pour surveiller la santé et les performances de l'ALB :

| Métrique | Description | Seuil d'Alerte (Prod) |
|-----------|-------------|------------------------|
| `HTTPCode_ELB_5XX_Count` | Nombre d'erreurs 5XX générées par l'ALB | > 10 en 5min |
| `HTTPCode_Target_5XX_Count` | Nombre d'erreurs 5XX retournées par les cibles | > 50 en 5min |
| `TargetResponseTime` | Temps de réponse des cibles (p95) | > 2s |
| `RequestCount` | Nombre total de requêtes | N/A (information) |
| `ActiveConnectionCount` | Connexions actives | > 5000 (warning) |
| `RejectedConnectionCount` | Connexions rejetées | > 100 en 5min |
| `HealthyHostCount` | Nombre d'hôtes sains | < config.min |
| `UnHealthyHostCount` | Nombre d'hôtes malsains | > 0 pendant 5min |

### 📊 Tableau de Bord CloudWatch

Le module crée également un tableau de bord CloudWatch pour visualiser les métriques importantes :

```hcl
resource "aws_cloudwatch_dashboard" "alb_dashboard" {
  dashboard_name = "${var.project_name}-${var.environment}-alb"

  dashboard_body = <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "${aws_lb.main.arn_suffix}" ],
          [ ".", "HTTPCode_ELB_5XX_Count", ".", "." ],
          [ ".", "HTTPCode_ELB_4XX_Count", ".", "." ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${data.aws_region.current.name}",
        "title": "Requests and Errors",
        "period": 300
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "${aws_lb.main.arn_suffix}", { "stat": "p50" } ],
          [ "...", { "stat": "p90" } ],
          [ "...", { "stat": "p95" } ],
          [ "...", { "stat": "p99" } ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${data.aws_region.current.name}",
        "title": "Response Time Percentiles",
        "period": 300
      }
    }
  ]
}
EOF
}
```

### 🔔 Alertes SNS

Le module peut également configurer des alertes SNS pour notifier en cas de problèmes :

```hcl
resource "aws_sns_topic" "alb_alerts" {
  count = var.create_cloudwatch_alarms ? 1 : 0
  name  = "${var.project_name}-${var.environment}-alb-alerts"
}

resource "aws_cloudwatch_metric_alarm" "http_5xx_errors" {
  count               = var.create_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = var.environment == "prod" ? 10 : 50
  alarm_description   = "This alarm monitors ALB 5XX errors"
  alarm_actions       = [aws_sns_topic.alb_alerts[0].arn]
  ok_actions          = [aws_sns_topic.alb_alerts[0].arn]
  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
}
```

## 📝 Notes d'Implémentation et Considérations Avancées

### ⚠️ Limitations Connues

1. **Multi-région** : Le module ne gère pas nativement le déploiement multi-région. Pour un déploiement DR (Disaster Recovery), combinez avec CloudFront ou Route 53 pour la redirection entre régions.

2. **Sticky Sessions** : Les sticky sessions sont supportées mais désactivées par défaut car elles peuvent compliquer le scaling et la maintenance. À activer uniquement si nécessaire pour la logique métier.

3. **Rate Limiting** : La protection contre les DDoS via WAF a des limites. Pour des applications critiques, envisagez d'ajouter CloudFront ou AWS Shield Advanced.

### 📗 Bonnes Pratiques

1. **Gestion des Certificats** : Utilisez AWS Certificate Manager pour gérer les certificats SSL/TLS. Le renouvellement est automatique.

2. **Logs d'Accès** : Activez toujours les logs d'accès en production et staging pour l'audit de sécurité et la résolution des problèmes.

3. **Sécurité des Groupes** : Restreignez l'accès à l'ALB uniquement aux ports nécessaires (80/443) et limitez l'accès aux services backend via les security groups.

4. **Health Checks** : Configurez des health checks détaillés qui vérifient la santé réelle de l'application, pas seulement l'accessibilité du serveur.

5. **Monitoring Proactif** : Configurez des alertes CloudWatch pour détecter les problèmes avant qu'ils n'affectent les utilisateurs.

### 🔍 Diagnostics Courants

| Problème | Cause Possible | Solution |
|-----------|----------------|----------|
| Erreurs 504 (Gateway Timeout) | Timeout des cibles | Augmenter `idle_timeout` et vérifier la performance des cibles |
| Erreurs 503 (Service Unavailable) | Aucune cible saine | Vérifier les health checks et l'accessibilité des services |
| Erreurs 403 (Forbidden) | Blocage WAF | Vérifier les règles WAF et les logs |
| Latence élevée | Saturation des cibles ou problèmes réseau | Vérifier les métriques CloudWatch pour identifier le goulot d'étranglement |

### 🚀 Évolutions Futures

1. **Intégration avec AWS Shield Advanced** pour une protection DDoS complète.

2. **Support pour AWS WAF WebACL personnalisés** permettant des règles plus flexibles.

3. **Blue/Green Deployment** via des target groups multiples pour des déploiements sans temps d'arrêt.

4. **Intégration avec X-Ray** pour un traçage de bout en bout des requêtes.

5. **Configuration automatique des certificats ACM** à partir de domaines fournis.