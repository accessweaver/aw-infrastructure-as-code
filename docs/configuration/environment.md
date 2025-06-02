# 🌍 Environment Variables - AccessWeaver

Configuration détaillée des variables d'environnement pour les différents environnements AccessWeaver (dev/staging/prod).

---

## 🎯 Vue d'Ensemble

Ce document détaille la configuration spécifique de chaque environnement AccessWeaver, optimisée pour les besoins particuliers de chaque phase du développement et de la production.

### 🏗 Philosophie par Environnement

| Environnement | Objectif Principal | Priorités |
|---------------|-------------------|-----------|
| **🔧 Development** | Développement rapide et debugging | Coût minimal, simplicité, debug facilité |
| **🎭 Staging** | Tests d'intégration et validation | HA réelle, tests réalistes, validation |
| **🚀 Production** | Performance et fiabilité | Sécurité maximale, performance, monitoring |

---

## 🔧 Environnement Development

### Objectifs
- **Coût minimal** : < $100/mois
- **Simplicité** : Configuration la plus simple possible
- **Debug** : Logs détaillés et outils de debug activés
- **Rapidité** : Déploiement et tests rapides

### Configuration Complète

```hcl
# environments/dev/terraform.tfvars

# =============================================================================
# CONFIGURATION DE BASE
# =============================================================================
project_name = "accessweaver"
environment  = "dev"
aws_region   = "eu-west-1"

# =============================================================================
# RÉSEAU - Configuration économique
# =============================================================================
vpc_cidr = "10.0.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b"]

# NAT Gateway - 1 seul pour économiser (~$45/mois vs $90/mois)
enable_nat_gateway = true
single_nat_gateway = true
enable_vpc_flow_logs = false  # Économise les coûts CloudWatch

# =============================================================================
# BASE DE DONNÉES - Configuration minimale
# =============================================================================
# RDS PostgreSQL
db_instance_class = "db.t3.micro"          # 1 vCPU, 1 GB RAM (~$13/mois)
db_allocated_storage = 20                   # 20 GB minimum
db_max_allocated_storage = 50               # Auto-scaling jusqu'à 50 GB
db_multi_az = false                         # Single AZ pour économiser
db_backup_retention_period = 1              # 1 jour minimum
db_backup_window = "03:00-04:00"
db_maintenance_window = "sun:04:00-sun:05:00"
db_deletion_protection = false              # Permet suppression facile
db_skip_final_snapshot = true               # Pas de snapshot final
enable_db_read_replica = false              # Pas de replica en dev
enable_db_performance_insights = false      # Économise les coûts
enable_db_enhanced_monitoring = false       # Pas de monitoring avancé

# =============================================================================
# CACHE REDIS - Single node
# =============================================================================
redis_node_type = "cache.t3.micro"          # 0.5 GB RAM (~$13/mois)
redis_num_cache_nodes = 1                   # Single node
redis_enable_cluster_mode = false           # Pas de cluster
redis_multi_az = false                      # Single AZ
redis_automatic_failover = false            # Pas de failover
redis_snapshot_retention_limit = 1          # 1 jour de rétention
redis_snapshot_window = "03:00-05:00"
redis_maintenance_window = "sun:05:00-sun:06:00"
redis_at_rest_encryption = true             # Sécurité de base
redis_transit_encryption = true             # TLS activé
redis_auth_token_enabled = true             # Authentification requise

# Paramètres Redis optimisés pour dev
redis_custom_parameters = [
  {
    name  = "timeout"
    value = "600"  # Plus permissif en dev
  },
  {
    name  = "slowlog-log-slower-than"
    value = "1000"  # Log queries > 1ms pour debugging
  }
]

# =============================================================================
# ECS FARGATE - Ressources minimales
# =============================================================================
# Configuration des services
ecs_cpu_default = 256                       # 0.25 vCPU
ecs_memory_default = 512                    # 512 MB
ecs_min_capacity = 1                        # 1 instance minimum
ecs_max_capacity = 2                        # 2 instances maximum
ecs_desired_count_default = 1               # 1 instance par service

# Auto-scaling moins agressif
ecs_scaling_cpu_target = 80                 # 80% CPU avant scale
ecs_scaling_memory_target = 85              # 85% Memory avant scale
ecs_enable_container_insights = false       # Économise les coûts CloudWatch
ecs_enable_execute_command = true           # Debug avec ECS Exec
ecs_enable_fargate_spot = false             # Spot peut interrompre le debug

# Configuration spécifique par service
ecs_service_overrides = {
  "aw-api-gateway" = {
    cpu           = 256
    memory        = 512
    desired_count = 1
    public        = true
  }
  "aw-pdp-service" = {
    cpu           = 512   # Plus de CPU pour OPA
    memory        = 1024  # Plus de mémoire pour cache
    desired_count = 1
    public        = false
  }
  "aw-pap-service" = {
    cpu           = 256
    memory        = 512
    desired_count = 1
    public        = false
  }
  "aw-tenant-service" = {
    cpu           = 256
    memory        = 512
    desired_count = 1
    public        = false
  }
  "aw-audit-service" = {
    cpu           = 256
    memory        = 512
    desired_count = 1
    public        = false
  }
}

# Variables d'environnement communes pour dev
ecs_common_environment_variables = {
  "SPRING_PROFILES_ACTIVE"                        = "dev"
  "LOGGING_LEVEL_ROOT"                            = "DEBUG"
  "LOGGING_LEVEL_COM_ACCESSWEAVER"                = "DEBUG"
  "MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE"     = "health,info,metrics,env,configprops"
  "MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS"       = "always"
  "SPRING_JPA_SHOW_SQL"                           = "true"
  "SPRING_JPA_PROPERTIES_HIBERNATE_FORMAT_SQL"    = "true"
  "JAVA_OPTS"                                     = "-Xmx384m -XX:+UseG1GC -XX:+PrintGCDetails"
}

# =============================================================================
# LOAD BALANCER ALB - Configuration permissive
# =============================================================================
# Sécurité simplifiée pour dev
alb_allowed_cidr_blocks = ["0.0.0.0/0"]     # Accès global pour tests
alb_enable_waf = false                       # WAF désactivé (économique)
alb_enable_access_logs = false               # Logs désactivés
alb_force_https_redirect = false             # HTTP autorisé en dev
alb_enable_ddos_protection = false           # Standard uniquement

# Health checks plus permissifs
alb_health_check_interval = 30               # 30 secondes
alb_health_check_timeout = 10                # 10 secondes timeout
alb_health_check_healthy_threshold = 2       # 2 checks OK
alb_health_check_unhealthy_threshold = 3     # 3 checks KO
alb_deregistration_delay = 30                # 30s deregistration

# Pas de domaine custom en dev (utilise DNS ALB)
alb_custom_domain = null
alb_route53_zone_id = null
alb_certificate_alternative_names = []

# =============================================================================
# MONITORING ET LOGGING - Configuration basique
# =============================================================================
# CloudWatch
cloudwatch_log_retention_days = 7            # 7 jours seulement
enable_cloudwatch_alarms = true              # Alertes basiques
enable_enhanced_monitoring = false           # Pas de monitoring avancé
enable_xray_tracing = false                  # X-Ray désactivé

# SNS pour alertes (optionnel en dev)
sns_topic_arn = null                         # Pas d'alertes email

# =============================================================================
# SÉCURITÉ - Configuration de base
# =============================================================================
# KMS - Utilise les clés par défaut AWS
kms_key_id = null                            # Clé par défaut AWS

# Secrets - Générés automatiquement
database_master_password = null              # Auto-généré
redis_auth_token = null                      # Auto-généré

# =============================================================================
# TAGS - Classification pour cost tracking
# =============================================================================
additional_tags = {
  Team           = "Platform"
  Cost           = "Development"
  Purpose        = "Development-Testing"
  Owner          = "Platform-Team"
  DeleteAfter    = "Never"                   # Environnement permanent
  Backup         = "NotRequired"             # Pas de backup en dev
  Monitoring     = "Basic"
}
```

---

## 🎭 Environnement Staging

### Objectifs
- **Tests réalistes** : Configuration proche de la production
- **Haute disponibilité** : Multi-AZ pour tester la résilience
- **Validation** : Tests d'intégration et de performance
- **Coût contrôlé** : ~$300/mois

### Configuration Complète

```hcl
# environments/staging/terraform.tfvars

# =============================================================================
# CONFIGURATION DE BASE
# =============================================================================
project_name = "accessweaver"
environment  = "staging"
aws_region   = "eu-west-1"

# =============================================================================
# RÉSEAU - Configuration Multi-AZ
# =============================================================================
vpc_cidr = "10.1.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

# NAT Gateway - Un par AZ pour HA
enable_nat_gateway = true
single_nat_gateway = false                   # HA réelle
enable_vpc_flow_logs = true                  # Monitoring réseau
vpc_flow_log_retention_days = 14

# =============================================================================
# BASE DE DONNÉES - Configuration HA
# =============================================================================
# RDS PostgreSQL avec Multi-AZ
db_instance_class = "db.t3.small"            # 2 vCPU, 2 GB RAM (~$60/mois)
db_allocated_storage = 50                     # 50 GB
db_max_allocated_storage = 200                # Auto-scaling jusqu'à 200 GB
db_multi_az = true                           # Multi-AZ pour HA
db_backup_retention_period = 7               # 7 jours de backup
db_backup_window = "03:00-04:00"
db_maintenance_window = "sun:04:00-sun:06:00"
db_deletion_protection = false               # Permet destruction staging
db_skip_final_snapshot = false               # Snapshot final pour sécurité
enable_db_read_replica = true                # Read replica pour tests
enable_db_performance_insights = false       # Pas encore nécessaire
enable_db_enhanced_monitoring = false        # Monitoring basique

# Paramètres DB optimisés pour staging
db_custom_parameters = [
  {
    name  = "max_connections"
    value = "100"
  },
  {
    name  = "log_min_duration_statement"
    value = "1000"  # Log requêtes > 1s
  }
]

# =============================================================================
# CACHE REDIS - Replication Group
# =============================================================================
redis_node_type = "cache.t3.small"           # 1.37 GB RAM (~$50/mois)
redis_num_cache_nodes = 2                    # Master + Replica
redis_enable_cluster_mode = false            # Pas encore de cluster
redis_multi_az = true                        # Multi-AZ
redis_automatic_failover = true              # Failover automatique
redis_snapshot_retention_limit = 5           # 5 jours de rétention
redis_snapshot_window = "03:00-05:00"
redis_maintenance_window = "sun:05:00-sun:07:00"
redis_at_rest_encryption = true
redis_transit_encryption = true
redis_auth_token_enabled = true

# Paramètres Redis pour staging
redis_custom_parameters = [
  {
    name  = "timeout"
    value = "300"  # Plus strict qu'en dev
  },
  {
    name  = "maxmemory-policy"
    value = "allkeys-lru"  # Politique d'éviction
  }
]

# =============================================================================
# ECS FARGATE - Configuration équilibrée
# =============================================================================
# Ressources intermédiaires
ecs_cpu_default = 512                        # 0.5 vCPU
ecs_memory_default = 1024                    # 1 GB
ecs_min_capacity = 1                         # 1 instance minimum
ecs_max_capacity = 4                         # 4 instances maximum
ecs_desired_count_default = 2                # 2 instances par service pour HA

# Auto-scaling modéré
ecs_scaling_cpu_target = 70                  # 70% CPU
ecs_scaling_memory_target = 80               # 80% Memory
ecs_enable_container_insights = true         # Monitoring activé
ecs_enable_execute_command = true            # Debug disponible
ecs_enable_fargate_spot = true               # 30% Spot pour économiser

# Configuration par service
ecs_service_overrides = {
  "aw-api-gateway" = {
    cpu           = 512
    memory        = 1024
    desired_count = 2     # HA critique
    public        = true
  }
  "aw-pdp-service" = {
    cpu           = 1024  # Plus de ressources pour tests charge
    memory        = 2048
    desired_count = 2     # HA critique pour autorisation
    public        = false
  }
  "aw-pap-service" = {
    cpu           = 512
    memory        = 1024
    desired_count = 1
    public        = false
  }
  "aw-tenant-service" = {
    cpu           = 256
    memory        = 512
    desired_count = 1
    public        = false
  }
  "aw-audit-service" = {
    cpu           = 256
    memory        = 512
    desired_count = 1
    public        = false
  }
}

# Variables d'environnement pour staging
ecs_common_environment_variables = {
  "SPRING_PROFILES_ACTIVE"                        = "staging"
  "LOGGING_LEVEL_ROOT"                            = "INFO"
  "LOGGING_LEVEL_COM_ACCESSWEAVER"                = "DEBUG"
  "MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE"     = "health,info,metrics"
  "MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS"       = "when-authorized"
  "SPRING_JPA_SHOW_SQL"                           = "false"
  "JAVA_OPTS"                                     = "-Xmx768m -XX:+UseG1GC"
}

# =============================================================================
# LOAD BALANCER ALB - Configuration sécurisée
# =============================================================================
# Sécurité intermédiaire
alb_allowed_cidr_blocks = [
  "203.0.113.0/24",    # Bureau principal
  "198.51.100.0/24"    # Bureaux partenaires
]
alb_enable_waf = true                         # WAF activé
alb_waf_rate_limit = 5000                     # Plus permissif qu'en prod
alb_enable_access_logs = true                 # Logs pour analyse
alb_access_logs_retention_days = 30
alb_force_https_redirect = true               # HTTPS obligatoire

# Health checks équilibrés
alb_health_check_interval = 30
alb_health_check_timeout = 5
alb_health_check_healthy_threshold = 2
alb_health_check_unhealthy_threshold = 3
alb_deregistration_delay = 60

# Domaine staging
alb_custom_domain = "staging.accessweaver.com"
alb_route53_zone_id = "Z123456789ABCDEF012345"
alb_certificate_alternative_names = ["*.staging.accessweaver.com"]

# =============================================================================
# MONITORING ET LOGGING - Configuration complète
# =============================================================================
# CloudWatch
cloudwatch_log_retention_days = 14           # 14 jours
enable_cloudwatch_alarms = true
enable_enhanced_monitoring = false           # Pas encore nécessaire
enable_xray_tracing = true                   # Tracing activé

# SNS pour alertes
sns_topic_arn = "arn:aws:sns:eu-west-1:123456789012:accessweaver-staging-alerts"

# =============================================================================
# SÉCURITÉ - Configuration intermédiaire
# =============================================================================
# KMS - Clé dédiée pour staging
kms_key_id = "arn:aws:kms:eu-west-1:123456789012:key/staging-key-id"

# Secrets - Gestion manuelle pour tests
database_master_password = null              # Auto-généré mais stocké
redis_auth_token = null                      # Auto-généré mais stocké

# =============================================================================
# TAGS - Classification détaillée
# =============================================================================
additional_tags = {
  Team           = "Platform"
  Cost           = "Staging"
  Purpose        = "Integration-Testing"
  Owner          = "Platform-Team"
  DeleteAfter    = "Never"
  Backup         = "Required"
  Monitoring     = "Enhanced"
  TestingLevel   = "Integration"
  Compliance     = "GDPR-Ready"
}
```

---

## 🚀 Environnement Production

### Objectifs
- **Performance maximale** : Ressources optimisées pour la charge
- **Sécurité renforcée** : Chiffrement, monitoring, compliance
- **Haute disponibilité** : Résilience aux pannes
- **Monitoring complet** : Observabilité totale

### Configuration Complète

```hcl
# environments/prod/terraform.tfvars

# =============================================================================
# CONFIGURATION DE BASE
# =============================================================================
project_name = "accessweaver"
environment  = "prod"
aws_region   = "eu-west-1"

# =============================================================================
# RÉSEAU - Configuration robuste
# =============================================================================
vpc_cidr = "10.2.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

# NAT Gateway - Un par AZ + redondance
enable_nat_gateway = true
single_nat_gateway = false
enable_vpc_flow_logs = true
vpc_flow_log_retention_days = 90              # Compliance et audit

# =============================================================================
# BASE DE DONNÉES - Configuration haute performance
# =============================================================================
# RDS PostgreSQL optimisé
db_instance_class = "db.r6g.large"           # 2 vCPU, 16 GB RAM (~$200/mois)
db_allocated_storage = 100                    # 100 GB initial
db_max_allocated_storage = 1000               # Auto-scaling jusqu'à 1 TB
db_multi_az = true                           # Multi-AZ obligatoire
db_backup_retention_period = 30              # 30 jours de backup
db_backup_window = "03:00-04:00"
db_maintenance_window = "sun:04:00-sun:06:00"
db_deletion_protection = true                # Protection suppression
db_skip_final_snapshot = false
enable_db_read_replica = true                # Read replica pour scaling
enable_db_performance_insights = true        # Performance Insights
enable_db_enhanced_monitoring = true         # Monitoring 60s

# Paramètres DB optimisés pour production
db_custom_parameters = [
  {
    name  = "max_connections"
    value = "200"
  },
  {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements,auto_explain,pg_hint_plan"
  },
  {
    name  = "effective_cache_size"
    value = "12GB"
  },
  {
    name  = "log_min_duration_statement"
    value = "500"   # Log requêtes > 500ms
  },
  {
    name  = "auto_explain.log_min_duration"
    value = "1000"  # Explain automatique > 1s
  }
]

# =============================================================================
# CACHE REDIS - Cluster Mode avec sharding
# =============================================================================
redis_node_type = "cache.r6g.large"          # 2 vCPU, 12.32 GB RAM
redis_enable_cluster_mode = true             # Cluster mode pour performance
redis_num_node_groups = 3                    # 3 shards
redis_replicas_per_node_group = 2            # 2 replicas par shard
redis_multi_az = true
redis_automatic_failover = true
redis_snapshot_retention_limit = 7           # 7 jours
redis_snapshot_window = "03:00-05:00"
redis_maintenance_window = "sun:05:00-sun:08:00"
redis_at_rest_encryption = true
redis_transit_encryption = true
redis_auth_token_enabled = true

# Paramètres Redis optimisés pour production
redis_custom_parameters = [
  {
    name  = "timeout"
    value = "300"
  },
  {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  },
  {
    name  = "maxmemory-samples"
    value = "10"    # Meilleure précision LRU
  },
  {
    name  = "tcp-keepalive"
    value = "300"   # Détection connexions mortes
  }
]

# =============================================================================
# ECS FARGATE - Configuration haute performance
# =============================================================================
# Ressources robustes
ecs_cpu_default = 1024                       # 1 vCPU
ecs_memory_default = 2048                    # 2 GB
ecs_min_capacity = 2                         # 2 instances minimum pour HA
ecs_max_capacity = 10                        # 10 instances maximum
ecs_desired_count_default = 3                # 3 instances par défaut

# Auto-scaling agressif
ecs_scaling_cpu_target = 60                  # 60% CPU (plus réactif)
ecs_scaling_memory_target = 75               # 75% Memory
ecs_enable_container_insights = true
ecs_enable_execute_command = false           # Sécurité : pas d'exec en prod
ecs_enable_fargate_spot = false              # Stabilité maximale

# Configuration optimisée par service
ecs_service_overrides = {
  "aw-api-gateway" = {
    cpu           = 1024
    memory        = 2048
    desired_count = 3     # Point d'entrée critique
    public        = true
  }
  "aw-pdp-service" = {
    cpu           = 2048  # Service le plus critique
    memory        = 4096  # Cache OPA + données
    desired_count = 3     # HA maximale
    public        = false
  }
  "aw-pap-service" = {
    cpu           = 1024
    memory        = 2048
    desired_count = 2     # HA modérée
    public        = false
  }
  "aw-tenant-service" = {
    cpu           = 512
    memory        = 1024
    desired_count = 2     # Multi-tenancy critique
    public        = false
  }
  "aw-audit-service" = {
    cpu           = 512
    memory        = 1024
    desired_count = 2     # Compliance critique
    public        = false
  }
}

# Variables d'environnement pour production
ecs_common_environment_variables = {
  "SPRING_PROFILES_ACTIVE"                        = "prod"
  "LOGGING_LEVEL_ROOT"                            = "INFO"
  "LOGGING_LEVEL_COM_ACCESSWEAVER"                = "INFO"
  "MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE"     = "health,info,metrics"
  "MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS"       = "never"
  "SPRING_JPA_SHOW_SQL"                           = "false"
  "JAVA_OPTS"                                     = "-Xmx1536m -XX:+UseG1GC -XX:+UseStringDeduplication -XX:G1HeapRegionSize=16m"
  "SERVER_TOMCAT_MAX_THREADS"                     = "200"
  "SERVER_TOMCAT_MIN_SPARE_THREADS"               = "10"
}

# =============================================================================
# LOAD BALANCER ALB - Configuration sécurisée maximale
# =============================================================================
# Sécurité stricte
alb_allowed_cidr_blocks = ["0.0.0.0/0"]      # API publique mais WAF protégé
alb_enable_waf = true
alb_waf_rate_limit = 2000                     # Limite stricte
alb_waf_whitelist_ips = [
  "203.0.113.100/32",  # Monitoring Pingdom
  "198.51.100.50/32"   # Monitoring interne
]
alb_enable_access_logs = true
alb_access_logs_retention_days = 90
alb_force_https_redirect = true
alb_enable_ddos_protection = false           # Évaluer selon budget

# Health checks stricts
alb_health_check_interval = 15                # Plus fréquent
alb_health_check_timeout = 5                 # Plus strict
alb_health_check_healthy_threshold = 2
alb_health_check_unhealthy_threshold = 2     # Détection rapide
alb_deregistration_delay = 300               # Graceful shutdown

# SSL/TLS renforcé
alb_ssl_policy = "ELBSecurityPolicy-TLS-1-3-2021-06"  # TLS 1.3

# Domaine production
alb_custom_domain = "accessweaver.com"
alb_route53_zone_id = "Z123456789ABCDEF012345"
alb_certificate_alternative_names = [
  "*.accessweaver.com",
  "api.accessweaver.com"
]

# =============================================================================
# MONITORING ET LOGGING - Configuration complète
# =============================================================================
# CloudWatch
cloudwatch_log_retention_days = 30
enable_cloudwatch_alarms = true
enable_enhanced_monitoring = true
enable_xray_tracing = true

# SNS avec escalade
sns_topic_arn = "arn:aws:sns:eu-west-1:123456789012:accessweaver-prod-alerts"

# =============================================================================
# SÉCURITÉ - Configuration maximale
# =============================================================================
# KMS - Clé dédiée avec rotation
kms_key_id = "arn:aws:kms:eu-west-1:123456789012:key/prod-key-id"

# Secrets - Gestion stricte
database_master_password = null              # Généré et géré par Terraform
redis_auth_token = null                      # Généré et géré par Terraform

# =============================================================================
# COMPLIANCE ET AUDIT
# =============================================================================
# Tags pour compliance GDPR
additional_tags = {
  Team             = "Platform"
  Cost             = "Production"
  Purpose          = "Production-Service"
  Owner            = "Platform-Team"
  DeleteAfter      = "Never"
  Backup           = "Required"
  Monitoring       = "Enhanced"
  Compliance       = "GDPR"
  DataClassification = "Confidential"
  SecurityLevel    = "High"
  DisasterRecovery = "Required"
  ChangeManagement = "Strict"
  BusinessCriticality = "High"
}
```

---

## 📊 Comparaison des Environnements

### Matrice de Configuration

| Aspect | Dev | Staging | Production |
|--------|-----|---------|------------|
| **💰 Coût/mois** | ~$95 | ~$300 | ~$900 |
| **🏗 Instances DB** | t3.micro | t3.small | r6g.large |
| **📊 Multi-AZ** | ❌ | ✅ | ✅ |
| **🔄 Read Replica** | ❌ | ✅ | ✅ |
| **⚡ Redis** | Single node | Replication | Cluster mode |
| **🚀 ECS Min/Max** | 1/2 | 1/4 | 2/10 |
| **🛡 WAF** | ❌ | ✅ | ✅ Enhanced |
| **📝 Logs** | 7 jours | 14 jours | 30 jours |
| **🔍 Monitoring** | Basique | Complet | Enhanced |
| **🔒 Sécurité** | Standard | Élevée | Maximale |

### Ressources Allouées

#### CPU/Memory par Service

| Service | Dev | Staging | Production |
|---------|-----|---------|------------|
| **API Gateway** | 256/512MB | 512/1GB | 1024/2GB |
| **PDP Service** | 512/1GB | 1024/2GB | 2048/4GB |
| **PAP Service** | 256/512MB | 512/1GB | 1024/2GB |
| **Tenant Service** | 256/512MB | 256/512MB | 512/1GB |
| **Audit Service** | 256/512MB | 256/512MB | 512/1GB |

#### Instances par Service

| Service | Dev | Staging | Production |
|---------|-----|---------|------------|
| **API Gateway** | 1 | 2 | 3 |
| **PDP Service** | 1 | 2 | 3 |
| **PAP Service** | 1 | 1 | 2 |
| **Tenant Service** | 1 | 1 | 2 |
| **Audit Service** | 1 | 1 | 2 |

---

## 🔧 Variables d'Application Spring Boot

### Configuration par Environnement

#### Development
```yaml
# application-dev.yml
spring:
  profiles:
    active: dev
  
  jpa:
    show-sql: true
    hibernate:
      ddl-auto: update
    properties:
      hibernate:
        format_sql: true
        
  redis:
    timeout: 10000ms
    lettuce:
      pool:
        max-active: 5
        
logging:
  level:
    com.accessweaver: DEBUG
    org.springframework.security: DEBUG
    
management:
  endpoints:
    web:
      exposure:
        include: "*"
  endpoint:
    health:
      show-details: always
```

#### Staging
```yaml
# application-staging.yml
spring:
  profiles:
    active: staging
    
  jpa:
    show-sql: false
    hibernate:
      ddl-auto: validate
      
  redis:
    timeout: 5000ms
    lettuce:
      pool:
        max-active: 10
        
logging:
  level:
    com.accessweaver: DEBUG
    root: INFO
    
management:
  endpoints:
    web:
      exposure:
        include: "health,info,metrics"
  endpoint:
    health:
      show-details: when-authorized
```

#### Production
```yaml
# application-prod.yml
spring:
  profiles:
    active: prod
    
  jpa:
    show-sql: false
    hibernate:
      ddl-auto: validate
      
  redis:
    timeout: 3000ms
    lettuce:
      pool:
        max-active: 20
        
logging:
  level:
    root: INFO
    com.accessweaver: INFO
    
management:
  endpoints:
    web:
      exposure:
        include: "health,info,metrics"
  endpoint:
    health:
      show-details: never
```

---

## 🎯 Prochaines Étapes

Après avoir configuré les variables d'environnement, consultez :

1. **[State Management](./state.md)** - Gestion du state Terraform
2. **[Secrets Management](./secrets.md)** - Configuration des secrets par environnement
3. **[Terraform Best Practices](./terraform-best-practices.md)** - Optimisations avancées

---

**📝 Note :** Les configurations présentées sont optimisées pour AccessWeaver. Adaptez les valeurs selon vos besoins spécifiques et votre budget. Les coûts sont estimatifs et peuvent varier selon l'utilisation réelle.