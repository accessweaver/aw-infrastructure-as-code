# 🔉 Configuration WAF - AccessWeaver Infrastructure

**Version :** 1.0  
**Date :** Juin 2025  
**Module :** security/waf  
**Responsable :** Équipe Platform AccessWeaver

---

## 🎯 Vue d'Ensemble

### Objectif Principal
Ce document détaille la **stratégie de protection WAF (Web Application Firewall)** implémentée dans l'infrastructure AWS d'AccessWeaver. Le WAF constitue la première ligne de défense contre les attaques applicatives ciblant les APIs et interfaces web de la plateforme.

### Composants Principaux

```
┌────────────────────────────────────────────────────────┐
│            AWS WAF - Architecture de Protection            │
│                                                           │
│    Internet                                               │
│        |                                                  │
│        ↓                                                  │
│  ┌─────────────────────────────────────────────┐   │
│  │                  AWS WAF WebACL                     │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐  │   │
│  │  │ Règles   │ │ Règles   │ │ Règles   │ │ Filtres │  │   │
│  │  │ AWS      │ │ OWASP    │ │ Custom   │ │ IP     │  │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └────────┘  │   │
│  │                                                    │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐             │   │
│  │  │ Controle │ │ Rate     │ │ Geo      │             │   │
│  │  │ Bots     │ │ Limiting │ │ Blocking │             │   │
│  │  └──────────┘ └──────────┘ └──────────┘             │   │
│  └─────────────────────────────────────────────┘   │
│        |                                                  │
│        ↓                                                  │
│  ┌─────────────────┐                                   │
│  │ Application Load │                                   │
│  │    Balancer     │                                   │
│  └─────────────────┘                                   │
│        |                                                  │
│        ↓                                                  │
│  ┌─────────────────┐                                   │
│  │  Microservices   │                                   │
│  │    ECS/Fargate   │                                   │
│  └─────────────────┘                                   │
│                                                           │
└────────────────────────────────────────────────────────┘
```

### Types de Protection

AccessWeaver implémente une stratégie de protection multicouche pour défendre ses APIs contre un large éventail de menaces, notamment:

- **Attaques d'injection** (SQL, NoSQL, LDAP)
- **Cross-Site Scripting (XSS)**
- **Falsification de requête intersites (CSRF)**
- **Attaques par force brute**
- **Déni de service (DoS/DDoS)**
- **Scan et reconnaissance d'API**
- **Exécution de code malveillant**
- **Exploitation de vulnérabilités spécifiques aux frameworks**

---

## 🔐 Règles WAF par Catégorie

### Règles AWS Managées

| Nom du Groupe | Description | Développement | Staging | Production |
|--------------|-------------|----------------|---------|------------|
| **AWSManagedRulesCommonRuleSet** | Protection contre les vulnérabilités web communes | ✅ | ✅ | ✅ |
| **AWSManagedRulesKnownBadInputsRuleSet** | Blocage des modèles d'attaque connus | ✅ | ✅ | ✅ |
| **AWSManagedRulesSQLiRuleSet** | Protection contre les injections SQL | ✅ | ✅ | ✅ |
| **AWSManagedRulesLinuxRuleSet** | Protection systèmes Linux | ❌ | ✅ | ✅ |
| **AWSManagedRulesAmazonIpReputationList** | Blocage d'IPs malveillantes | ❌ | ✅ | ✅ |
| **AWSManagedRulesAnonymousIpList** | Détection proxy/VPN/Tor | ❌ | ❌ | ✅ |
| **AWSManagedRulesBotControlRuleSet** | Contrôle avancé des bots | ❌ | ❌ | ✅ |

### Règles Personnalisées AccessWeaver

| Nom de la Règle | Description | Type | Environnements |
|-----------------|-------------|------|----------------|
| **RateLimiting-Global** | Limite de requêtes par IP | Rate-based | Tous |
| **RateLimiting-Auth** | Protection endpoints d'authentification | Rate-based | Tous |
| **GeoBlocking** | Restriction par pays | Geo Match | Staging, Production |
| **APIKeyValidation** | Vérification API Key valide | String Match | Tous |
| **JWTValidation** | Vérification format JWT | Regex Pattern | Tous |
| **PermissionAPIProtection** | Protection API d'autorisations | Custom | Production |
| **AdminAPIProtection** | Protection API admin | Custom | Tous |

---

## 💻 Configuration par Environnement

### Configuration WAF Development

| Paramètre | Valeur | Description |
|-----------|-------|-------------|
| **Niveau WAF** | Standard | Protection de base |
| **Mode** | Count+Block | Alertes + blocage minimal |
| **Limite requêtes** | 5000/5min | Par IP |
| **Groupes de règles** | 3 | Core uniquement |
| **Règles personnalisées** | 3 | Basiques uniquement |
| **Blocage géographique** | Non | Aucune restriction |
| **Protection DDoS** | Basique | Shield Standard |
| **Journalisation** | Partielle | Échantillonnage 20% |
| **Alertes** | Basiques | E-mail uniquement |

### Configuration WAF Staging

| Paramètre | Valeur | Description |
|-----------|-------|-------------|
| **Niveau WAF** | Standard | Protection complète |
| **Mode** | Block | Blocage actif |
| **Limite requêtes** | 2000/5min | Par IP |
| **Groupes de règles** | 5 | Ensemble complet |
| **Règles personnalisées** | 5 | Adaptées à l'application |
| **Blocage géographique** | Oui | Pays non desservis |
| **Protection DDoS** | Avancée | Shield Standard |
| **Journalisation** | Complète | Toutes les requêtes |
| **Alertes** | Avancées | E-mail + SNS |

### Configuration WAF Production

| Paramètre | Valeur | Description |
|-----------|-------|-------------|
| **Niveau WAF** | Premium | Protection maximale |
| **Mode** | Block | Blocage strict |
| **Limite requêtes** | 1000/5min | Par IP, avec burst |
| **Groupes de règles** | 7 | Tous actifs |
| **Règles personnalisées** | 7 | Complètes et optimisées |
| **Blocage géographique** | Oui | Restriction par pays |
| **Protection DDoS** | Premium | Shield Advanced |
| **Journalisation** | Complète | 100% des requêtes |
| **Alertes** | Complètes | E-mail + SNS + Dashboards |

---

## 💱 Implémentation Terraform

### AWS WAF WebACL Principal

```hcl
resource "aws_wafv2_web_acl" "main" {
  name        = "accessweaver-${var.environment}-protection"
  description = "WAF protection for AccessWeaver ${var.environment}"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Règle 1: AWS Managed - Core Rule Set
  rule {
    name     = "AWS-CommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Exclure certaines règles trop restrictives en dev
        dynamic "excluded_rule" {
          for_each = var.environment == "development" ? [
            "SizeRestrictions_BODY",
            "EC2MetaDataSSRF_BODY"
          ] : []
          content {
            name = excluded_rule.value
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Règle 2: AWS Managed - Protection Injection SQL
  rule {
    name     = "AWS-SQLiRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-SQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }
  
  # Règle 3: Limitation de débit global
  rule {
    name     = "RateLimiting-Global"
    priority = 100

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.environment == "production" ? 1000 : (var.environment == "staging" ? 2000 : 5000)
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimiting-Global"
      sampled_requests_enabled   = true
    }
  }
  
  # Règle 4: Protection API Auth - Limitation plus stricte
  rule {
    name     = "RateLimiting-Auth"
    priority = 110

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.environment == "production" ? 100 : (var.environment == "staging" ? 200 : 500)
        aggregate_key_type = "IP"
        
        scope_down_statement {
          byte_match_statement {
            field_to_match {
              uri_path {}
            }
            positional_constraint = "STARTS_WITH"
            search_string         = "/auth"
            text_transformations {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimiting-Auth"
      sampled_requests_enabled   = true
    }
  }
  
  # Règle 5: Blocage géographique (staging et production uniquement)
  dynamic "rule" {
    for_each = var.environment != "development" ? [1] : []
    content {
      name     = "GeoBlocking"
      priority = 200

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "GeoBlocking"
        sampled_requests_enabled   = true
      }
    }
  }

  # Configuration de journalisation
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "accessweaver-${var.environment}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "accessweaver-${var.environment}-waf"
    Environment = var.environment
    Service     = "security"
    Terraform   = "true"
  }
}
```

### Association avec Application Load Balancer

```hcl
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}
```

### Configuration Logging

```hcl
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_kinesis_firehose_delivery_stream.waf_logs.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  logging_filter {
    default_behavior = "KEEP"

    filter {
      behavior = "DROP"
      condition {
        action_condition {
          action = "COUNT"
        }
      }
      requirement = "MEETS_ANY"
    }
  }
}
```

---

## 📈 Monitoring et Analyse

### Métriques Clés

| Métrique | Description | Seuil d'Alerte |
|-----------|-------------|----------------|
| **AllowedRequests** | Requêtes autorisées | Baisse soudaine > 30% |
| **BlockedRequests** | Requêtes bloquées | Augmentation > 200% |
| **CountedRequests** | Requêtes matchées non bloquées | Augmentation > 300% |
| **RateLimitedIP** | IPs limitées par taux | > 100 IPs distinctes |
| **SQLiRequests** | Tentatives d'injection SQL | > 50 en 5 minutes |
| **XSSRequests** | Tentatives XSS | > 50 en 5 minutes |
| **GeoBlocked** | Requêtes bloquées par pays | Surveillance uniquement |

### Dashboard CloudWatch (Exemple)

```hcl
resource "aws_cloudwatch_dashboard" "waf_monitoring" {
  dashboard_name = "accessweaver-${var.environment}-waf-monitoring"
  
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
            ["AWS/WAFV2", "AllowedRequests", "WebACL", aws_wafv2_web_acl.main.name, "Region", data.aws_region.current.name, { "stat": "Sum", "period": 300 }],
            ["AWS/WAFV2", "BlockedRequests", "WebACL", aws_wafv2_web_acl.main.name, "Region", data.aws_region.current.name, { "stat": "Sum", "period": 300 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "WAF Allowed vs Blocked Requests"
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
            ["AWS/WAFV2", "CountedRequests", "Rule", "AWS-SQLiRuleSet", "WebACL", aws_wafv2_web_acl.main.name, "Region", data.aws_region.current.name, { "stat": "Sum", "period": 300 }],
            ["AWS/WAFV2", "CountedRequests", "Rule", "AWS-CommonRuleSet", "WebACL", aws_wafv2_web_acl.main.name, "Region", data.aws_region.current.name, { "stat": "Sum", "period": 300 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "WAF Rules Matched Requests"
        }
      }
    ]
  })
}
```

---

## 📝 Références

- [AWS WAF Documentation](https://docs.aws.amazon.com/waf/latest/developerguide/what-is-aws-waf.html)
- [OWASP Top 10 API Security Risks](https://owasp.org/www-project-api-security/)
- [AWS Best Practices for DDoS Resiliency](https://d1.awsstatic.com/whitepapers/Security/DDoS_White_Paper.pdf)
- [WAF Rule Groups Reference](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-list.html)
- [AWS Shield Documentation](https://docs.aws.amazon.com/waf/latest/developerguide/shield-chapter.html)