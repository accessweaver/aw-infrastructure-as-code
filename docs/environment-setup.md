# 🏗 Environment Setup - AccessWeaver Infrastructure

Guide détaillé pour configurer et gérer les environnements AccessWeaver (dev, staging, production).

---

## 📋 Table des Matières

- [Stratégie Multi-Environnements](#stratégie-multi-environnements)
- [Configuration par Environnement](#configuration-par-environnement)
- [Variables et Secrets](#variables-et-secrets)
- [Networking et Sécurité](#networking-et-sécurité)
- [Workflow de Déploiement](#workflow-de-déploiement)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Stratégie Multi-Environnements

### **Architecture des Environnements**

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS Organization                         │
├─────────────────────────────────────────────────────────────┤
│  Dev Environment          │  Staging Environment           │
│  ├── Single AZ            │  ├── Multi-AZ                  │
│  ├── Micro instances      │  ├── Small instances           │
│  ├── Basic monitoring     │  ├── Full monitoring           │
│  └── Cost optimized      │  └── Performance testing       │
├─────────────────────────────────────────────────────────────┤
│               Production Environment                        │
│               ├── Multi-AZ + Multi-Region                  │
│               ├── Optimized instances                      │
│               ├── Enhanced monitoring                      │
│               └── High availability                        │
└─────────────────────────────────────────────────────────────┘
```

### **Matrice des Environnements**

| Caractéristique | Development | Staging | Production |
|-----------------|-------------|---------|------------|
| **🎯 Objectif** | Dev quotidien | Tests pré-prod | Clients réels |
| **👥 Utilisateurs** | Équipe dev | QA + Product | End users |
| **📊 Données** | Fake/Anonymisées | Similaires prod | Production |
| **🔐 Sécurité** | Standard | Prod-like | Maximum |
| **💰 Budget** | Minimal | Modéré | Optimisé |
| **📈 Performance** | Basique | Évaluée | Critique |
| **🔄 Déploiements** | Multiples/jour | 1-2/semaine | Planifiés |
| **📝 Logs** | Debug | Info | Warn+Error |

---

## ⚙️ Configuration par Environnement

### **1. Development Environment**

#### **Objectifs**
- **Coût minimal** (~$95/mois)
- **Déploiement rapide** (< 5 minutes)
- **Debugging facile** avec logs verbeux

#### **Configuration Terraform (environments/dev/terraform.tfvars)**
```hcl
# ============================================================================
# DEVELOPMENT ENVIRONMENT - OPTIMISÉ POUR LE COÛT ET LA RAPIDITÉ
# ============================================================================

# Identité
project_name = "accessweaver"
environment  = "dev"
region      = "eu-west-1"

# Réseau - Configuration simple
vpc_cidr = "10.0.0.0/16"
availability_zones = ["eu-west-1a"]  # Single AZ pour économies

# Base de données - Configuration économique
db_instance_class           = "db.t3.micro"      # 2 vCPU, 1 GB RAM
db_allocated_storage       = 20                  # 20 GB minimum
db_max_allocated_storage   = 50                  # Auto-scaling limité
db_backup_retention_period = 1                   # 1 jour seulement
db_multi_az               = false                # Single AZ
db_enable_performance_insights = false           # Pas de PI
db_skip_final_snapshot    = true                 # Dev = pas de snapshot final

# Redis - Single node
redis_node_type                = "cache.t3.micro"  # 2 vCPU, 0.5 GB
redis_num_cache_clusters       = 1                # Single node
redis_at_rest_encryption      = false             # Pas de chiffrement
redis_transit_encryption      = false
redis_automatic_failover      = false

# ECS - Configuration minimale
ecs_services = {
  api-gateway = {
    cpu           = 256                           # 0.25 vCPU
    memory        = 512                           # 0.5 GB
    desired_count = 1                             # Single instance
    max_capacity  = 2                             # Scale minimal
    min_capacity  = 1
  }
  pdp-service = {
    cpu           = 256
    memory        = 512
    desired_count = 1
    max_capacity  = 2
    min_capacity  = 1
  }
  pap-service = {
    cpu           = 256
    memory        = 512
    desired_count = 1
    max_capacity  = 1
    min_capacity  = 1
  }
  tenant-service = {
    cpu           = 256
    memory        = 512
    desired_count = 1
    max_capacity  = 1
    min_capacity  = 1
  }
  audit-service = {
    cpu           = 256
    memory        = 512
    desired_count = 1
    max_capacity  = 1
    min_capacity  = 1
  }
}

# Load Balancer - Basique
enable_deletion_protection = false               # Faciliter suppression
idle_timeout              = 60
health_check_interval     = 30                   # Moins fréquent
health_check_timeout      = 10
deregistration_delay      = 30                   # Plus rapide

# Domaine - Sous-domaine dev
custom_domain = "dev.accessweaver.com"
route53_zone_id = "Z1234567890ABCDEF012345"

# WAF - Désactivé pour dev
enable_waf = false

# Monitoring - Basique
enable_container_insights    = false             # Économies
enable_access_logs          = false
access_logs_retention_days  = 7                  # Court
enable_xray_tracing         = false              # Debug local

# Container images
container_registry = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/accessweaver"
image_tag         = "latest"                     # Toujours la dernière

# Debug & Development
log_level = "DEBUG"                              # Logs verbeux
enable_debug_endpoints = true                   # Endpoints debug
cors_allowed_origins = ["*"]                    # CORS permissif

# Tags
additional_tags = {
  Environment   = "development"
  Project      = "accessweaver"
  Owner        = "dev-team"
  CostCenter   = "engineering"
  AutoShutdown = "true"                          # Arrêt automatique possible
  Temporary    = "true"
}
```

### **2. Staging Environment**

#### **Objectifs**
- **Test prod-like** avec données similaires
- **Validation performance** et intégration
- **Security testing** complet

#### **Configuration Terraform (environments/staging/terraform.tfvars)**
```hcl
# ============================================================================
# STAGING ENVIRONMENT - PRODUCTION-LIKE POUR VALIDATION
# ============================================================================

# Identité
project_name = "accessweaver"
environment  = "staging"
region      = "eu-west-1"

# Réseau - Multi-AZ comme prod
vpc_cidr = "10.1.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b"]

# Base de données - Configuration prod-like
db_instance_class           = "db.t3.small"       # 2 vCPU, 2 GB RAM
db_allocated_storage       = 50
db_max_allocated_storage   = 200
db_backup_retention_period = 7                    # 1 semaine
db_multi_az               = true                  # HA testing
db_enable_performance_insights = true
db_monitoring_interval    = 60
db_skip_final_snapshot    = false

# Redis - Cluster simple
redis_node_type                = "cache.t3.small"
redis_num_cache_clusters       = 2               # Basic HA
redis_at_rest_encryption      = true             # Sécurité comme prod
redis_transit_encryption      = true
redis_automatic_failover      = true

# ECS - Configuration intermédiaire
ecs_services = {
  api-gateway = {
    cpu           = 512                           # 0.5 vCPU
    memory        = 1024                          # 1 GB
    desired_count = 2                             # HA basic
    max_capacity  = 4
    min_capacity  = 1
  }
  pdp-service = {
    cpu           = 1024                          # Plus de ressources
    memory        = 2048
    desired_count = 2
    max_capacity  = 6
    min_capacity  = 1
  }
  pap-service = {
    cpu           = 512
    memory        = 1024
    desired_count = 1
    max_capacity  = 3
    min_capacity  = 1
  }
  tenant-service = {
    cpu           = 512
    memory        = 1024
    desired_count = 1
    max_capacity  = 2
    min_capacity  = 1
  }
  audit-service = {
    cpu           = 512
    memory        = 1024
    desired_count = 1
    max_capacity  = 2
    min_capacity  = 1
  }
}

# Load Balancer - Configuration sécurisée
enable_deletion_protection = true
idle_timeout              = 60
health_check_interval     = 15                   # Plus strict
health_check_timeout      = 5
deregistration_delay      = 60

# Domaine
custom_domain = "staging.accessweaver.com"
route53_zone_id = "Z1234567890ABCDEF012345"

# WAF - Activé pour test sécurité
enable_waf       = true
waf_rate_limit  = 500                           # Plus strict que prod
waf_whitelist_ips = [
  "203.0.113.100/32",  # QA team
  "198.51.100.50/32"   # Monitoring
]

# Monitoring - Complet
enable_container_insights    = true
enable_access_logs          = true
access_logs_retention_days  = 30
enable_xray_tracing         = true
sns_topic_arn              = "arn:aws:sns:eu-west-1:123456789012:accessweaver-staging-alerts"

# Container images - Version stable
container_registry = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/accessweaver"
image_tag         = "v1.2.0-rc1"               # Release candidate

# Configuration application
log_level = "INFO"
enable_debug_endpoints = false                 # Pas de debug en staging
cors_allowed_origins = ["https://staging.accessweaver.com"]

# Tags
additional_tags = {
  Environment = "staging"
  Project     = "accessweaver"
  Owner       = "qa-team"
  CostCenter  = "engineering"
  Testing     = "true"
  DataClass   = "sensitive"
}
```

### **3. Production Environment**

#### **Objectifs**
- **Haute disponibilité** (99.95% SLA)
- **Performance optimale** (< 10ms latency)
- **Sécurité maximale** et compliance

#### **Configuration Terraform (environments/prod/terraform.tfvars)**
```hcl
# ============================================================================
# PRODUCTION ENVIRONMENT - HAUTE DISPONIBILITÉ ET PERFORMANCE
# ============================================================================

# Identité
project_name = "accessweaver"
environment  = "prod"
region      = "eu-west-1"

# Réseau - Multi-AZ complet
vpc_cidr = "10.2.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

# Base de données - Configuration optimisée
db_instance_class           = "db.r6g.xlarge"    # Memory optimized
db_allocated_storage       = 200
db_max_allocated_storage   = 1000
db_backup_retention_period = 30                  # Compliance
db_multi_az               = true
db_enable_performance_insights = true
db_monitoring_interval    = 60
db_deletion_protection    = true                 # Protection suppression
db_skip_final_snapshot    = false
db_final_snapshot_identifier = "accessweaver-prod-final-snapshot"

# Read replicas pour performance
db_read_replicas = {
  replica1 = {
    instance_class    = "db.r6g.large"
    availability_zone = "eu-west-1b"
  }
  replica2 = {
    instance_class    = "db.r6g.large"
    availability_zone = "eu-west-1c"
  }
}

# Redis - Cluster haute performance
redis_node_type                = "cache.r6g.large"  # Memory optimized
redis_num_node_groups         = 3                   # 3 shards
redis_replicas_per_node_group = 2                   # 2 replicas per shard
redis_at_rest_encryption      = true
redis_transit_encryption      = true
redis_auth_token_enabled      = true
redis_automatic_failover      = true
redis_multi_az               = true

# ECS - Configuration haute performance
ecs_services = {
  api-gateway = {
    cpu           = 1024                          # 1 vCPU
    memory        = 2048                          # 2 GB
    desired_count = 3                             # HA
    max_capacity  = 10                            # Scale important
    min_capacity  = 3
    target_cpu    = 70                            # CPU target for scaling
    target_memory = 80
  }
  pdp-service = {
    cpu           = 2048                          # 2 vCPU (critical)
    memory        = 4096                          # 4 GB
    desired_count = 3
    max_capacity  = 15                            # Scale élevé
    min_capacity  = 3
    target_cpu    = 60                            # Plus agressif
    target_memory = 70
  }
  pap-service = {
    cpu           = 1024
    memory        = 2048
    desired_count = 2
    max_capacity  = 8
    min_capacity  = 2
    target_cpu    = 70
    target_memory = 80
  }
  tenant-service = {
    cpu           = 512
    memory        = 1024
    desired_count = 2
    max_capacity  = 6
    min_capacity  = 2
    target_cpu    = 70
    target_memory = 80
  }
  audit-service = {
    cpu           = 512
    memory        = 1024
    desired_count = 2
    max_capacity  = 6
    min_capacity  = 2
    target_cpu    = 70
    target_memory = 80
  }
}

# Load Balancer - Configuration maximale
enable_deletion_protection = true
idle_timeout              = 60
health_check_interval     = 15
health_check_timeout      = 5
deregistration_delay      = 60
enable_cross_zone_load_balancing = true

# SSL/TLS - Configuration sécurisée
ssl_policy = "ELBSecurityPolicy-TLS-1-3-2021-06"
certificate_alternative_names = [
  "*.accessweaver.com",
  "api.accessweaver.com",
  "admin.accessweaver.com"
]

# Domaine principal
custom_domain = "accessweaver.com"
route53_zone_id = "Z1234567890ABCDEF012345"

# WAF - Protection complète
enable_waf               = true
waf_rate_limit          = 1000
waf_whitelist_ips       = [
  "203.0.113.100/32",    # Monitoring Pingdom
  "198.51.100.50/32",    # Office IP
  "10.0.0.0/8"           # VPN corporate
]
waf_blocked_countries = ["CN", "RU", "KP"]     # Geo-blocking

# Monitoring - Enhanced
enable_container_insights    = true
enable_access_logs          = true
access_logs_retention_days  = 90              # Compliance
enable_xray_tracing         = true
enable_detailed_monitoring  = true
sns_topic_arn              = "arn:aws:sns:eu-west-1:123456789012:accessweaver-prod-alerts"

# Container images - Version stable taguée
container_registry = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/accessweaver"
image_tag         = "v1.2.0"                 # Version stable

# Configuration application production
log_level = "WARN"                           # Logs optimisés
enable_debug_endpoints = false
cors_allowed_origins = [
  "https://accessweaver.com",
  "https://admin.accessweaver.com"
]

# Sécurité avancée
secrets_kms_key_id = "arn:aws:kms:eu-west-1:123456789012:key/12345678-1234-1234-1234-123456789012"
enable_encryption_at_rest = true
enable_encryption_in_transit = true

# Tags production
additional_tags = {
  Environment     = "production"
  Project         = "accessweaver"
  Owner          = "platform-team"
  CostCenter     = "product"
  BusinessUnit   = "saas"
  Compliance     = "GDPR,SOC2,ISO27001"
  Backup         = "required"
  Monitoring     = "enhanced"
  Support        = "24x7"
  SLA            = "99.95%"
  DataClass      = "confidential"
}
```

---

## 🔐 Variables et Secrets

### **1. Structure des Variables**

#### **Variables Publiques (terraform.tfvars)**
```bash
# Variables non sensibles, versionnées dans Git
- Configuration infrastructure
- Tailles d'instances
- Paramètres réseau
- Tags et métadata
```

#### **Variables Sensibles (AWS Secrets Manager)**
```bash
# Secrets jamais en clair
- Mots de passe database
- Tokens d'authentification
- Clés API externes
- Certificats privés
```

### **2. Gestion des Secrets par Environnement**

#### **Development Secrets**
```bash
# Secrets simples pour dev
aws secretsmanager create-secret \
  --name "accessweaver/dev/database" \
  --description "Dev database password" \
  --secret-string '{"password":"dev_password_123"}'

aws secretsmanager create-secret \
  --name "accessweaver/dev/redis" \
  --secret-string '{"auth_token":"dev_redis_token"}'

aws secretsmanager create-secret \
  --name "accessweaver/dev/jwt" \
  --secret-string '{"signing_key":"dev_jwt_secret_key"}'
```

#### **Production Secrets**
```bash
# Secrets complexes avec rotation
aws secretsmanager create-secret \
  --name "accessweaver/prod/database" \
  --description "Production database credentials" \
  --generate-secret-string '{
    "SecretStringTemplate": "{\"username\": \"postgres\"}",
    "GenerateStringKey": "password",
    "PasswordLength": 32,
    "ExcludeCharacters": "\"/\\'\""
  }' \
  --kms-key-id arn:aws:kms:eu-west-1:123456789012:key/12345678...

# Rotation automatique (optionnel)
aws secretsmanager update-secret \
  --secret-id "accessweaver/prod/database" \
  --description "Production database with auto-rotation" \
  --secret-string '{
    "lambda_arn": "arn:aws:lambda:eu-west-1:123456789012:function:SecretsManagerRDSPostgreSQLRotationSingleUser"
  }'
```

### **3. Configuration par Environnement**

#### **Script de Configuration Secrets**
```bash
#!/bin/bash
# scripts/setup-secrets.sh

ENV=${1:-dev}
REGION=${2:-eu-west-1}

echo "🔐 Setting up secrets for $ENV environment"

case $ENV in
  "dev")
    # Secrets simples pour développement
    aws secretsmanager create-secret \
      --name "accessweaver/dev/database" \
      --secret-string '{"password":"dev_simple_password"}' \
      --region $REGION
    
    aws secretsmanager create-secret \
      --name "accessweaver/dev/redis" \
      --secret-string '{"auth_token":"dev_redis_token"}' \
      --region $REGION
    ;;
    
  "staging")
    # Secrets prod-like mais régénérables
    aws secretsmanager create-secret \
      --name "accessweaver/staging/database" \
      --generate-secret-string '{
        "SecretStringTemplate": "{\"username\": \"postgres\"}",
        "GenerateStringKey": "password",
        "PasswordLength": 24
      }' \
      --region $REGION
    ;;
    
  "prod")
    # Secrets production avec toutes les protections
    aws secretsmanager create-secret \
      --name "accessweaver/prod/database" \
      --generate-secret-string '{
        "SecretStringTemplate": "{\"username\": \"postgres\"}",
        "GenerateStringKey": "password",
        "PasswordLength": 32,
        "ExcludeCharacters": "\"/\\'\""
      }' \
      --kms-key-id arn:aws:kms:eu-west-1:123456789012:key/12345678... \
      --region $REGION
    ;;
esac

echo "✅ Secrets created for $ENV"
```

---

## 🌐 Networking et Sécurité

### **1. Configuration Réseau par Environnement**

#### **Isolation Réseau**
```hcl
# CIDR blocks par environnement
environments = {
  dev     = "10.0.0.0/16"   # 65k IPs
  staging = "10.1.0.0/16"   # 65k IPs  
  prod    = "10.2.0.0/16"   # 65k IPs
}

# Subnets structure
subnets = {
  public  = "x.x.1.0/24"    # ALB, NAT Gateway
  private = "x.x.10.0/24"   # ECS Tasks
  data    = "x.x.20.0/24"   # RDS, Redis
}
```

#### **Security Groups**
```hcl
# Security groups par environnement
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.environment == "dev" ? ["0.0.0.0/0"] : var.allowed_cidr_blocks
  }
  
  # Dev = plus permissif, Prod = restrictif
  dynamic "ingress" {
    for_each = var.environment == "dev" ? [1] : []
    content {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]  # HTTP autorisé en dev seulement
    }
  }
}

# ECS Security Group - Configuration adaptative
resource "aws_security_group" "ecs" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-"
  
  ingress {
    from_port       = 8080
    to_port         = 8090
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  
  # Debug ports pour dev uniquement
  dynamic "ingress" {
    for_each = var.environment == "dev" ? [1] : []
    content {
      from_port   = 8080
      to_port     = 8090
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]  # Accès interne VPC pour debug
    }
  }
}
```

### **2. Configuration SSL/TLS par Environnement**

#### **Certificats ACM**
```bash
# Development - Wildcard certificate
aws acm request-certificate \
  --domain-name "*.dev.accessweaver.com" \
  --subject-alternative-names "dev.accessweaver.com" \
  --validation-method DNS \
  --region eu-west-1

# Staging - Wildcard certificate  
aws acm request-certificate \
  --domain-name "*.staging.accessweaver.com" \
  --subject-alternative-names "staging.accessweaver.com" \
  --validation-method DNS \
  --region eu-west-1

# Production - Multiple domains
aws acm request-certificate \
  --domain-name "accessweaver.com" \
  --subject-alternative-names "*.accessweaver.com,api.accessweaver.com,admin.accessweaver.com" \
  --validation-method DNS \
  --region eu-west-1
```

#### **SSL Policies par Environnement**
```hcl
# SSL policy configuration
ssl_policies = {
  dev     = "ELBSecurityPolicy-TLS-1-2-2017-01"  # Moins strict
  staging = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06" 
  prod    = "ELBSecurityPolicy-TLS-1-3-2021-06"  # Plus sécurisé
}
```

---

## 🔄 Workflow de Déploiement

### **1. Stratégie de Déploiement par Environnement**

#### **Development Workflow**
```bash
# 1. Développement local
git checkout feature/new-feature
# Modifications code...

# 2. Tests locaux
docker-compose up -d
make test-local

# 3. Push et déploiement auto dev
git push origin feature/new-feature
# → GitHub Actions déploie automatiquement sur dev

# 4. Tests dev
curl -f https://dev.accessweaver.com/actuator/health
make test-integration ENV=dev
```

#### **Staging Workflow**
```bash
# 1. Merge vers staging branch
git checkout staging
git merge feature/new-feature

# 2. Déploiement staging (semi-automatique)
git push origin staging
# → GitHub Actions : build + tests + deploy staging

# 3. Tests complets
make test-e2e ENV=staging
make test-performance ENV=staging
make test-security ENV=staging

# 4. Validation QA
# Tests manuels + validation product
```

#### **Production Workflow**
```bash
# 1. Create release
git tag v1.2.0
git push origin v1.2.0

# 2. Déploiement production (manuel avec approbation)
# GitHub Actions : build + attente approbation
# → Déploiement après validation

# 3. Monitoring post-déploiement
make monitor-deployment ENV=prod VERSION=v1.2.0

# 4. Rollback si nécessaire
make rollback ENV=prod VERSION=v1.1.9
```

### **2. Pipeline CI/CD Configuration**

#### **GitHub Actions per Environment**
```yaml
# .github/workflows/deploy-dev.yml
name: Deploy to Development
on:
  push:
    branches: [develop, feature/*]

jobs:
  deploy-dev:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID_DEV }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY_DEV }}
          aws-region: eu-west-1
      
      - name: Terraform Plan Dev
        run: |
          cd environments/dev
          terraform init
          terraform plan -out=tfplan
      
      - name: Terraform Apply Dev
        run: |
          cd environments/dev
          terraform apply tfplan
```

#### **Secrets GitHub par Environnement**
```bash
# Development secrets
AWS_ACCESS_KEY_ID_DEV
AWS_SECRET_ACCESS_KEY_DEV
DOCKER_REGISTRY_DEV

# Staging secrets  
AWS_ACCESS_KEY_ID_STAGING
AWS_SECRET_ACCESS_KEY_STAGING
DOCKER_REGISTRY_STAGING

# Production secrets
AWS_ACCESS_KEY_ID_PROD
AWS_SECRET_ACCESS_KEY_PROD
DOCKER_REGISTRY_PROD
SLACK_WEBHOOK_URL         # Notifications prod
PAGER_DUTY_KEY           # Alertes critiques
```

### **3. Configuration Makefile Multi-Environnements**

```makefile
# Makefile avec support multi-environnements
.PHONY: help deploy plan destroy test

ENV ?= dev
REGION ?= eu-west-1

help: ## Afficher l'aide
	@echo "Commandes disponibles pour AccessWeaver:"
	@echo ""
	@echo "📦 Déploiement:"
	@echo "  make deploy ENV=dev|staging|prod    # Déployer un environnement"
	@echo "  make plan ENV=dev|staging|prod      # Planifier les changements"
	@echo "  make destroy ENV=dev|staging|prod   # Détruire un environnement"
	@echo ""
	@echo "🧪 Tests:"
	@echo "  make test ENV=dev|staging|prod      # Lancer les tests"
	@echo "  make test-integration ENV=dev       # Tests d'intégration"
	@echo "  make test-e2e ENV=staging           # Tests end-to-end"
	@echo ""
	@echo "🔧 Maintenance:"
	@echo "  make status ENV=prod                # Status des services"
	@echo "  make logs SERVICE=api-gateway       # Voir les logs"
	@echo "  make scale SERVICE=pdp INSTANCES=5  # Scaler un service"

init: ## Initialiser Terraform pour un environnement
	@echo "🔧 Initializing Terraform for $(ENV)"
	cd environments/$(ENV) && terraform init

plan: init ## Planifier les changements
	@echo "📋 Planning changes for $(ENV)"
	cd environments/$(ENV) && terraform plan -out=terraform.tfplan

deploy: plan ## Déployer l'infrastructure
	@echo "🚀 Deploying $(ENV) environment"
	cd environments/$(ENV) && terraform apply terraform.tfplan
	@echo "✅ Deployment completed for $(ENV)"
	@$(MAKE) validate ENV=$(ENV)

validate: ## Valider le déploiement
	@echo "✅ Validating $(ENV) deployment"
	@cd environments/$(ENV) && terraform output -json > outputs.json
	@./scripts/validate-deployment.sh $(ENV)

destroy: ## Détruire l'infrastructure
	@echo "💥 Destroying $(ENV) infrastructure"
	@echo "⚠️  This will DELETE all resources in $(ENV)!"
	@read -p "Are you sure? Type 'yes' to confirm: " confirm; \
	if [ "$confirm" = "yes" ]; then \
		cd environments/$(ENV) && terraform destroy -auto-approve; \
	else \
		echo "Operation cancelled."; \
	fi

# Tests par environnement
test: ## Lancer les tests appropriés selon l'environnement
ifeq ($(ENV),dev)
	@$(MAKE) test-unit
	@$(MAKE) test-integration ENV=$(ENV)
else ifeq ($(ENV),staging)
	@$(MAKE) test-integration ENV=$(ENV)
	@$(MAKE) test-e2e ENV=$(ENV)
	@$(MAKE) test-performance ENV=$(ENV)
else ifeq ($(ENV),prod)
	@$(MAKE) test-smoke ENV=$(ENV)
	@$(MAKE) monitor-health ENV=$(ENV)
endif

test-unit: ## Tests unitaires
	@echo "🧪 Running unit tests"
	@./scripts/test-unit.sh

test-integration: ## Tests d'intégration
	@echo "🔗 Running integration tests for $(ENV)"
	@./scripts/test-integration.sh $(ENV)

test-e2e: ## Tests end-to-end
	@echo "🎭 Running E2E tests for $(ENV)"
	@./scripts/test-e2e.sh $(ENV)

test-performance: ## Tests de performance
	@echo "⚡ Running performance tests for $(ENV)"
	@./scripts/test-performance.sh $(ENV)

test-smoke: ## Tests smoke en production
	@echo "💨 Running smoke tests for $(ENV)"
	@./scripts/test-smoke.sh $(ENV)

# Opérations
status: ## Status des services
	@echo "📊 Checking $(ENV) environment status"
	@./scripts/check-status.sh $(ENV)

logs: ## Voir les logs d'un service
	@echo "📜 Showing logs for $(SERVICE) in $(ENV)"
	@aws logs tail /ecs/accessweaver-$(ENV)/$(SERVICE) --follow

scale: ## Scaler un service
	@echo "📈 Scaling $(SERVICE) to $(INSTANCES) instances in $(ENV)"
	@./scripts/scale-service.sh $(ENV) $(SERVICE) $(INSTANCES)

rollback: ## Rollback vers une version précédente
	@echo "🔄 Rolling back $(ENV) to version $(VERSION)"
	@./scripts/rollback.sh $(ENV) $(VERSION)
```

---

## 🚨 Troubleshooting

### **1. Problèmes Fréquents par Environnement**

#### **Development Issues**
```bash
# Problème : Services ne démarrent pas
# Solution : Vérifier les ressources allouées
aws ecs describe-services --cluster accessweaver-dev-cluster
aws ecs describe-tasks --cluster accessweaver-dev-cluster

# Problème : Base de données inaccessible
# Solution : Vérifier security groups
aws ec2 describe-security-groups --filters "Name=tag:Environment,Values=dev"

# Problème : Images Docker introuvables
# Solution : Vérifier ECR et permissions
aws ecr describe-repositories --repository-names accessweaver
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.eu-west-1.amazonaws.com
```

#### **Staging Issues**
```bash
# Problème : Tests de performance échouent
# Solution : Vérifier auto-scaling et métriques
aws application-autoscaling describe-scalable-targets --service-namespace ecs
aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name CPUUtilization

# Problème : WAF bloque le trafic légitime
# Solution : Analyser les logs WAF
aws wafv2 get-sampled-requests --web-acl-arn "arn:aws:wafv2:..." --rule-metric-name "..."
```

#### **Production Issues**
```bash
# Problème : Latence élevée
# Solution : Analyser les métriques de performance
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name TargetResponseTime
aws xray get-trace-summaries --time-range-type TimeRangeByStartTime --start-time 2025-01-01T00:00:00 --end-time 2025-01-01T23:59:59

# Problème : Indisponibilité base de données
# Solution : Vérifier Multi-AZ et read replicas
aws rds describe-db-instances --db-instance-identifier accessweaver-prod-postgres
aws rds describe-events --source-identifier accessweaver-prod-postgres --source-type db-instance
```

### **2. Scripts de Diagnostic**

#### **Health Check Script**
```bash
#!/bin/bash
# scripts/health-check.sh

ENV=${1:-dev}

echo "🔍 Health check for $ENV environment"

# 1. Infrastructure status
echo "📊 Infrastructure Status:"
aws ecs describe-clusters --clusters accessweaver-$ENV-cluster --query 'clusters[0].status'
aws rds describe-db-instances --db-instance-identifier accessweaver-$ENV-postgres --query 'DBInstances[0].DBInstanceStatus'
aws elasticache describe-replication-groups --replication-group-id accessweaver-$ENV-redis --query 'ReplicationGroups[0].Status'

# 2. Service health
echo "🏥 Service Health:"
ALB_DNS=$(aws elbv2 describe-load-balancers --names accessweaver-$ENV-alb --query 'LoadBalancers[0].DNSName' --output text)
curl -f -s "https://$ALB_DNS/actuator/health" | jq '.'

# 3. Performance metrics
echo "⚡ Performance Metrics:"
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=$(aws elbv2 describe-load-balancers --names accessweaver-$ENV-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text | cut -d'/' -f2-) \
  --start-time $(date -d '1 hour ago' --iso-8601) \
  --end-time $(date --iso-8601) \
  --period 300 \
  --statistics Average \
  --query 'Datapoints[0].Average'
```

### **3. Monitoring et Alerting par Environnement**

#### **CloudWatch Alarms par Environment**
```bash
# Development - Alertes basiques
aws cloudwatch put-metric-alarm \
  --alarm-name "AccessWeaver-Dev-HighLatency" \
  --alarm-description "High latency in dev environment" \
  --metric-name TargetResponseTime \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 300 \
  --threshold 1.0 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2

# Production - Alertes strictes  
aws cloudwatch put-metric-alarm \
  --alarm-name "AccessWeaver-Prod-HighLatency" \
  --alarm-description "High latency in production - CRITICAL" \
  --metric-name TargetResponseTime \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 60 \
  --threshold 0.01 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:eu-west-1:123456789012:accessweaver-prod-critical
```

---

## 📚 Commandes Utiles par Environnement

### **Development Commands**
```bash
# Déploiement rapide
make deploy ENV=dev

# Debug d'un service
make logs SERVICE=api-gateway ENV=dev
aws ecs execute-command --cluster accessweaver-dev-cluster --task TASK_ID --container api-gateway --interactive --command "/bin/bash"

# Reset complet environnement
make destroy ENV=dev
make deploy ENV=dev
```

### **Staging Commands**
```bash
# Déploiement avec tests
make deploy ENV=staging
make test ENV=staging

# Validation performance
make test-performance ENV=staging

# Comparaison avec production
./scripts/compare-environments.sh staging prod
```

### **Production Commands**
```bash
# Déploiement sécurisé
make plan ENV=prod
# Review manuel du plan
make deploy ENV=prod

# Monitoring post-déploiement
make monitor-deployment ENV=prod VERSION=v1.2.0

# Rollback d'urgence
make rollback ENV=prod VERSION=v1.1.9

# Health check critique
make test-smoke ENV=prod
```

---

**✅ Environment Setup Complété !**

Vous avez maintenant une configuration complète pour gérer vos trois environnements AccessWeaver avec:
- Configurations Terraform adaptées par environnement
- Gestion des secrets sécurisée
- Networking et sécurité progressive
- Workflows de déploiement automatisés
- Troubleshooting et monitoring appropriés

**Prochaine étape :** [First Deployment Guide](./first-deployment.md) pour votre premier déploiement complet.