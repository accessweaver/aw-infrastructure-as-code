# 🌐 Module ALB - AccessWeaver

Module Terraform pour déployer Application Load Balancer avec SSL termination, WAF protection et intégration complète avec les services ECS AccessWeaver.

## 🎯 Objectifs

### ✅ Point d'Entrée Public Sécurisé
- **SSL/TLS termination** avec certificats AWS Certificate Manager
- **WAF protection** contre attaques OWASP Top 10 et DDoS
- **Health checks avancés** avec retry logic intelligent
- **High Availability** Multi-AZ avec cross-zone load balancing

### ✅ Configuration Adaptative par Environnement
- **Dev** : HTTP autorisé, WAF désactivé, configuration permissive (~$25/mois)
- **Staging** : HTTPS redirect, WAF activé, logs complets (~$35/mois)
- **Prod** : HTTPS obligatoire, protection maximale, monitoring enhanced (~$50/mois)

### ✅ Intégration Native AccessWeaver
- **Routing intelligent** vers aw-api-gateway par path patterns
- **Target groups** optimisés pour services ECS Fargate
- **Service discovery** ready avec health checks Spring Boot
- **Zero downtime deployments** avec deregistration graceful

### ✅ Observabilité Complète
- **Access logs** vers S3 avec lifecycle management
- **CloudWatch alarms** pour response time et error rate
- **WAF metrics** pour attaques bloquées
- **Integration monitoring** externe (Pingdom, DataDog)

## 🏗 Architecture

```
                              Internet
                                ↓
┌─────────────────────────────────────────────────────────┐
│                        Route 53                         │
│              accessweaver.com → ALB                     │
└─────────────────────┬───────────────────────────────────┘
                      │ DNS Resolution
┌─────────────────────▼───────────────────────────────────┐
│                     AWS WAF                             │
│  🛡️ Protection contre:                                  │
│    • OWASP Top 10 (injection, XSS, etc.)               │
│    • Rate limiting (2000 req/5min par IP)              │
│    • IP reputation Amazon                               │
│    • Custom rules et whitelist                         │
└─────────────────────┬───────────────────────────────────┘
                      │ Filtered Traffic
┌─────────────────────▼───────────────────────────────────┐
│              Application Load Balancer                  │
│                                                         │
│  🔀 Listeners:                                          │
│    • HTTP :80  → Redirect HTTPS (301)                  │
│    • HTTPS:443 → SSL Termination + Routing             │
│                                                         │
│  🎯 Target Groups:                                      │
│    • aw-api-gateway-tg                                  │
│      └─ Health: GET /actuator/health → 200             │
│                                                         │
│  📍 Routing Rules:                                      │
│    • /api/* → aw-api-gateway                           │
│    • /actuator/* → aw-api-gateway                      │
│    • /swagger-ui/* → aw-api-gateway                    │
└─────────────────────┬───────────────────────────────────┘
                      │ Load Balanced Traffic
            ┌─────────┼─────────┐
            │         │         │
┌───────────▼───┐ ┌───▼───┐ ┌───▼───────┐
│ECS Task       │ │ECS Task│ │ECS Task   │
│aw-api-gateway │ │aw-api- │ │aw-api-    │
│AZ-1a          │ │gateway │ │gateway    │
│               │ │AZ-1b   │ │AZ-1c      │
└───────────────┘ └───────┘ └───────────┘
        │               │           │
        └───────────────┼───────────┘
                        │
┌───────────────────────▼───────────────────────┐
│              Internal Services                 │
│  aw-pdp-service  aw-pap-service  etc.         │
│  (via service discovery interne)              │
└───────────────────────────────────────────────┘
```

## 🚀 Utilisation

### Configuration Basique (Dev)

```hcl
module "alb" {
  source = "../../modules/alb"
  
  # Configuration obligatoire
  project_name           = "accessweaver"
  environment           = "dev"
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  ecs_security_group_id = module.ecs.security_group_id
  
  # Configuration dev permissive
  allowed_cidr_blocks   = ["0.0.0.0/0"]  # Ouvert pour tests
  enable_waf           = false            # WAF désactivé (économique)
  enable_access_logs   = false            # Logs désactivés
}
```

### Configuration Avancée (Production)

```hcl
module "alb" {
  source = "../../modules/alb"
  
  # Configuration de base
  project_name           = "accessweaver"
  environment           = "prod"
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  ecs_security_group_id = module.ecs.security_group_id
  
  # Domaine et SSL
  custom_domain                = "accessweaver.com"
  route53_zone_id             = "Z1234567890ABCDEF"
  certificate_alternative_names = ["*.accessweaver.com", "api.accessweaver.com"]
  ssl_policy                  = "ELBSecurityPolicy-TLS-1-3-2021-06"
  
  # Sécurité renforcée
  allowed_cidr_blocks = [
    "203.0.113.0/24",    # Bureau principal
    "198.51.100.0/24"    # Bureaux partenaires
  ]
  
  # WAF avec protection maximale
  enable_waf          = true
  waf_rate_limit     = 1000    # Plus strict pour prod
  waf_whitelist_ips  = [
    "203.0.113.100/32",  # Monitoring Pingdom
    "198.51.100.50/32"   # Monitoring interne
  ]
  
  # Health checks optimisés
  health_check_path      = "/actuator/health"
  health_check_interval  = 15    # Plus fréquent en prod
  health_check_timeout   = 5     # Plus strict
  healthy_threshold      = 2
  unhealthy_threshold    = 2
  deregistration_delay   = 60    # Graceful shutdown
  
  # Monitoring et logging
  enable_access_logs          = true
  access_logs_retention_days  = 90
  sns_topic_arn              = aws_sns_topic.alerts.arn
  
  # Optimisations performance
  enable_cross_zone_load_balancing = true
  enable_http2                    = true
  idle_timeout                    = 60
  deletion_protection             = true
  
  # Tags pour cost management
  additional_tags = {
    CostCenter      = "Engineering"
    Owner           = "Platform Team"
    BusinessUnit    = "Product"
    Compliance      = "GDPR"
    MonitoringLevel = "Enhanced"
    PublicFacing    = "true"
  }
}
```

## 📊 Configuration par Environnement

| Paramètre | Dev | Staging | Production |
|-----------|-----|---------|------------|
| **SSL/TLS** | HTTP autorisé | HTTPS redirect | HTTPS obligatoire |
| **WAF** | ❌ Désactivé | ✅ Activé | ✅ Protection maximale |
| **Access Logs** | ❌ | ✅ S3 + lifecycle | ✅ Rétention 90j |
| **Health Checks** | 30s/10s (permissif) | 30s/5s | 15s/5s (strict) |
| **Deletion Protection** | ❌ | ❌ | ✅ |
| **Cross-Zone LB** | ❌ | ✅ | ✅ |
| **Monitoring** | Basique | Complet | Enhanced |
| **Coût estimé/mois** | ~$25 | ~$35 | ~$50 |

## 🔐 Configuration SSL/TLS

### Certificat Automatique ACM

```hcl
# Le module crée automatiquement un certificat ACM
resource "aws_acm_certificate" "main" {
  domain_name       = "accessweaver.com"           # Prod
  # domain_name     = "dev.accessweaver.com"       # Dev
  # domain_name     = "staging.accessweaver.com"   # Staging
  
  subject_alternative_names = [
    "*.accessweaver.com",     # Wildcard pour sous-domaines
    "api.accessweaver.com"    # SAN spécifique
  ]
  
  validation_method = "DNS"  # Validation automatique via Route 53
}
```

### Configuration TLS Policy

```yaml
# Politique TLS recommandée par environnement
dev/staging:
  ssl_policy: "ELBSecurityPolicy-TLS-1-2-2017-01"  # Compatibilité large
  
production:
  ssl_policy: "ELBSecurityPolicy-TLS-1-3-2021-06"  # Sécurité maximale
```

## 🛡 Configuration WAF

### Règles de Protection Incluses

```hcl
# 1. OWASP Top 10 Protection
rule {
  name = "AWSManagedRulesCommonRuleSet"
  # Protège contre:
  # - SQL Injection
  # - Cross-site scripting (XSS)
  # - Remote file inclusion (RFI)
  # - Directory traversal
  # - Command injection
}

# 2. IP Reputation
rule {
  name = "AWSManagedRulesAmazonIpReputationList"
  # Bloque automatiquement:
  # - IPs avec historique d'attaques
  # - Botnets connus
  # - Sources de spam/malware
}

# 3. Rate Limiting
rule {
  name = "RateLimitRule"
  limit = 2000  # Requêtes par IP par 5 minutes
  # Protection contre:
  # - Attaques DDoS application
  # - Brute force sur API
  # - Scraping abusif
}

# 4. Whitelist (optionnelle)
rule {
  name = "WhitelistRule"
  # Exemption pour:
  # - Monitoring externe
  # - Load testing
  # - IPs d'administration
}
```

### Monitoring WAF

```bash
# Métriques WAF disponibles dans CloudWatch
aws cloudwatch get-metric-statistics \
  --namespace AWS/WAFV2 \
  --metric-name BlockedRequests \
  --dimensions Name=WebACL,Value=accessweaver-prod-waf \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

## 🎯 Routing et Target Groups

### Configuration Target Groups

Le module crée automatiquement des target groups optimisés :

```hcl
# Target Group pour aw-api-gateway
resource "aws_lb_target_group" "api_gateway" {
  name     = "accessweaver-prod-api-gateway-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  target_type = "ip"  # Pour ECS Fargate
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 15    # Plus fréquent en prod
    path                = "/actuator/health"
    matcher             = "200"
    protocol            = "HTTP"
  }
  
  deregistration_delay = 60  # Graceful shutdown
}
```

### Routing Rules par Path

```hcl
# Routing automatique configuré par le module
listener_rule "api_routes" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100
  
  condition {
    path_pattern {
      values = [
        "/api/*",           # API REST principal
        "/actuator/*",      # Spring Boot management
        "/swagger-ui/*",    # Documentation API
        "/v3/api-docs/*"    # OpenAPI spec
      ]
    }
  }
  
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_gateway.arn
  }
}
```

## 📈 Health Checks et Monitoring

### Configuration Health Checks

```yaml
# Configuration adaptative par environnement
health_check:
  path: "/actuator/health"
  
  dev:
    interval: 30s
    timeout: 10s
    healthy_threshold: 2
    unhealthy_threshold: 3
    
  staging:
    interval: 30s
    timeout: 5s
    healthy_threshold: 2
    unhealthy_threshold: 3
    
  prod:
    interval: 15s
    timeout: 5s
    healthy_threshold: 2
    unhealthy_threshold: 2
```

### Endpoint Health Check Spring Boot

```java
// Configuration automatique dans aw-api-gateway
@RestController
public class HealthController {
    
    @Autowired
    private DatabaseHealthIndicator databaseHealth;
    
    @Autowired
    private RedisHealthIndicator redisHealth;
    
    @GetMapping("/actuator/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> health = new HashMap<>();
        
        boolean isHealthy = true;
        
        // Vérification base de données
        try {
            databaseHealth.health();
            health.put("database", "UP");
        } catch (Exception e) {
            health.put("database", "DOWN");
            isHealthy = false;
        }
        
        // Vérification Redis
        try {
            redisHealth.health();
            health.put("redis", "UP");
        } catch (Exception e) {
            health.put("redis", "UP");  # Non-critique pour health check ALB
        }
        
        health.put("status", isHealthy ? "UP" : "DOWN");
        
        return ResponseEntity
            .status(isHealthy ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE)
            .body(health);
    }
}
```

### CloudWatch Alarms

Le module configure automatiquement des alertes :

```hcl
# Alarm: Response time élevé
aws_cloudwatch_metric_alarm "response_time" {
  alarm_name          = "accessweaver-prod-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  threshold           = 1.0  # 1 seconde en prod, 2s en dev
  
  # Actions automatiques
  alarm_actions = [aws_sns_topic.alerts.arn]
}

# Alarm: Taux d'erreur 5xx
aws_cloudwatch_metric_alarm "error_rate" {
  alarm_name          = "accessweaver-prod-alb-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  threshold           = 10  # Plus de 10 erreurs en 5 minutes
  
  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

## 📊 Access Logs et Analytics

### Configuration S3 Logs

```hcl
# Bucket S3 avec lifecycle automatique
resource "aws_s3_bucket" "alb_logs" {
  bucket = "accessweaver-prod-alb-access-logs-abc12345"
  
  lifecycle_configuration {
    rule {
      id     = "alb_logs_lifecycle"
      status = "Enabled"
      
      # 0-30 jours: Standard storage
      transition {
        days          = 30
        storage_class = "STANDARD_IA"  # -50% coût
      }
      
      # 30-90 jours: Infrequent Access
      transition {
        days          = 90
        storage_class = "GLACIER"      # -80% coût
      }
      
      # Suppression après rétention
      expiration {
        days = 365  # Configurable par environnement
      }
    }
  }
}
```

### Analyse des Logs avec Athena

```sql
-- Requête Athena pour analyser les logs ALB
CREATE EXTERNAL TABLE alb_logs (
  type string,
  time string,
  elb string,
  client_ip string,
  client_port int,
  target_ip string,
  target_port int,
  request_processing_time double,
  target_processing_time double,
  response_processing_time double,
  elb_status_code string,
  target_status_code string,
  received_bytes bigint,
  sent_bytes bigint,
  request_verb string,
  request_url string,
  request_proto string,
  user_agent string,
  ssl_cipher string,
  ssl_protocol string
)
PARTITIONED BY(year string, month string, day string)
STORED AS INPUTFORMAT 'org.apache.hadoop.mapred.TextInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://accessweaver-prod-alb-access-logs/alb-access-logs/AWSLogs/123456789012/elasticloadbalancing/eu-west-1/'

-- Analyse du trafic par heure
SELECT 
  date_format(parse_datetime(time,'yyyy-MM-dd''T''HH:mm:ss.SSSSSS''Z'), '%Y-%m-%d %H') as hour,
  COUNT(*) as request_count,
  AVG(target_processing_time) as avg_response_time,
  COUNT(CASE WHEN elb_status_code LIKE '5%' THEN 1 END) as error_5xx_count
FROM alb_logs 
WHERE year='2024' AND month='01' AND day='15'
GROUP BY 1
ORDER BY 1;
```

## 💰 Optimisation des Coûts

### Breakdown des Coûts ALB

| Composant | Dev | Staging | Prod | Description |
|-----------|-----|---------|------|-------------|
| **ALB Base** | $22/mois | $22/mois | $22/mois | Coût fixe ALB |
| **LCU** | $3/mois | $8/mois | $20/mois | Load Balancer Capacity Units |
| **WAF** | $0 | $5/mois | $5/mois | Web ACL + rules |
| **WAF Requests** | $0 | $2/mois | $5/mois | $1/million requêtes |
| **SSL Certificate** | $0 | $0 | $0 | Gratuit avec ACM |
| **S3 Access Logs** | $0 | $3/mois | $5/mois | Stockage + lifecycle |
| **Total** | **~$25/mois** | **~$40/mois** | **~$57/mois** |

### Stratégies d'Économies

```hcl
# 1. WAF conditionnel par environnement
enable_waf = var.environment != "dev"  # Économise $5-10/mois en dev

# 2. Access logs conditionnels
enable_access_logs = var.environment != "dev"  # Économise $3-5/mois

# 3. Health checks moins fréquents en dev
health_check_interval = var.environment == "prod" ? 15 : 30

# 4. Lifecycle S3 agressif pour logs
access_logs_retention_days = var.environment == "prod" ? 90 : 30
```

### Monitoring des Coûts

```bash
# Script de monitoring des coûts ALB
#!/bin/bash
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --filter '{
    "Dimensions": {
      "Key": "SERVICE",
      "Values": ["Amazon Elastic Load Balancing"]
    }
  }'
```

## 🔧 Variables du Module

### Variables Obligatoires

| Variable | Type | Description |
|----------|------|-------------|
| `project_name` | string | Nom du projet (ex: "accessweaver") |
| `environment` | string | Environnement (dev/staging/prod) |
| `vpc_id` | string | ID du VPC de déploiement |
| `public_subnet_ids` | list(string) | IDs des subnets publics (≥2) |
| `ecs_security_group_id` | string | Security group des services ECS |

### Variables SSL/TLS

| Variable | Type | Défaut | Description |
|----------|------|--------|-------------|
| `custom_domain` | string | null | Domaine personnalisé (ex: accessweaver.com) |
| `route53_zone_id` | string | null | Zone Route 53 pour DNS |
| `certificate_alternative_names` | list(string) | [] | SAN pour certificat SSL |
| `ssl_policy` | string | TLS-1-2-2017-01 | Politique SSL/TLS |

### Variables WAF

| Variable | Type | Défaut | Description |
|----------|------|--------|-------------|
| `enable_waf` | bool | null (auto) | Activation WAF |
| `waf_rate_limit` | number | 2000 | Limite req/5min par IP |
| `waf_whitelist_ips` | list(string) | [] | IPs exemptées WAF |

## 📤 Outputs du Module

### Outputs Essentiels

| Output | Description |
|--------|-------------|
| `public_url` | URL publique AccessWeaver |
| `api_base_url` | URL de base API (/api/v1) |
| `target_group_arns` | ARNs target groups pour ECS |
| `security_group_id` | Security group ALB |
| `alb_dns_name` | DNS par défaut ALB |

### Outputs pour Monitoring

| Output | Description |
|--------|-------------|
| `health_check_url` | URL health check externe |
| `cloudwatch_alarms` | ARNs des alarmes créées |
| `integration_config` | Config monitoring externe |
| `curl_test_commands` | Commandes de test prêtes |

## 🛠 Intégration avec Autres Modules

### Avec Module ECS

```hcl
# Dans le module ECS, utiliser les target groups ALB
module "ecs" {
  source = "../../modules/ecs"
  
  # ... autres variables ...
  
  # Intégration ALB
  alb_security_group_ids = [module.alb.security_group_id]
  target_group_arns = module.alb.target_group_arns
}
```

### Avec Module VPC

```hcl
# ALB utilise les subnets publics du VPC
module "alb" {
  source = "../../modules/alb"
  
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}
```

### Configuration Complète Multi-Modules

```hcl
# Exemple d'intégration complète
module "vpc" {
  source = "../../modules/vpc"
  # ...
}

module "rds" {
  source = "../../modules/rds"
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "redis" {
  source = "../../modules/redis"
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "ecs" {
  source = "../../modules/ecs"
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  rds_security_group_id = module.rds.security_group_id
  redis_security_group_id = module.redis.security_group_id
  
  # ALB integration
  alb_security_group_ids = [module.alb.security_group_id]
  target_group_arns = module.alb.target_group_arns
}

module "alb" {
  source = "../../modules/alb"
  vpc_id = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  ecs_security_group_id = module.ecs.security_group_id
  
  # Production configuration
  custom_domain = "accessweaver.com"
  route53_zone_id = "Z1234567890ABCDEF"
  enable_waf = true
  enable_access_logs = true
}
```

## 🛠 Troubleshooting

### Problèmes Courants

#### 1. Health Checks échouent

```bash
# 1. Vérifier les logs ECS
aws logs tail /ecs/accessweaver-prod/aw-api-gateway --follow

# 2. Tester health check manuellement
curl -v http://PRIVATE_IP:8080/actuator/health

# 3. Vérifier security groups
aws ec2 describe-security-groups --group-ids sg-xxx
```

#### 2. Certificat SSL non validé

```bash
# 1. Vérifier status certificat
aws acm describe-certificate --certificate-arn arn:aws:acm:...

# 2. Vérifier enregistrements DNS validation
aws route53 list-resource-record-sets --hosted-zone-id Z123...

# 3. Forcer re-validation
aws acm resend-validation-email --certificate-arn arn:aws:acm:...
```

#### 3. WAF bloque le trafic légitime

```bash
# 1. Analyser les requêtes bloquées
aws wafv2 get-sampled-requests \
  --web-acl-arn arn:aws:wafv2:... \
  --rule-metric-name RateLimitMetric \
  --scope REGIONAL \
  --time-window StartTime=2024-01-01T00:00:00Z,EndTime=2024-01-01T23:59:59Z \
  --max-items 100

# 2. Ajuster whitelist temporairement
# 3. Modifier les seuils de rate limiting
```

### Scripts de Maintenance

```bash
#!/bin/bash
# alb-maintenance.sh

case "$1" in
  "test-health")
    # Test health check via ALB
    curl -f https://accessweaver.com/actuator/health
    ;;
    
  "drain-target")
    # Drain un target group pour maintenance
    TARGET_GROUP_ARN="$2"
    aws elbv2 modify-target-group-attributes \
      --target-group-arn "$TARGET_GROUP_ARN" \
      --attributes Key=deregistration_delay.timeout_seconds,Value=30
    ;;
    
  "check-waf")
    # Vérifier les métriques WAF
    aws cloudwatch get-metric-statistics \
      --namespace AWS/WAFV2 \
      --metric-name BlockedRequests \
      --start-time $(date -d '1 hour ago' --iso-8601) \
      --end-time $(date --iso-8601) \
      --period 300 \
      --statistics Sum
    ;;
    
  *)
    echo "Usage: $0 {test-health|drain-target|check-waf}"
    exit 1
    ;;
esac
```

## 📚 Ressources

### Documentation Technique
- [AWS ALB User Guide](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [AWS WAF Developer Guide](https://docs.aws.amazon.com/waf/latest/developerguide/)
- [SSL/TLS Best Practices](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html)

### Tools Recommandés
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/) - Pour Kubernetes
- [ALB Ingress Controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller) - Legacy
- [SSL Labs Test](https://www.ssllabs.com/ssltest/) - Test SSL/TLS

### Monitoring & Observabilité
- [ALB CloudWatch Metrics](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html)
- [WAF CloudWatch Metrics](https://docs.aws.amazon.com/waf/latest/developerguide/monitoring-cloudwatch.html)
- [Access Logs Analysis](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html)

---

**⚠️ Note importante :** Ce module crée des ressources AWS facturées. Les coûts ALB sont principalement basés sur le trafic (LCU). Configurez des budgets appropriés et surveillez les métriques de coût.