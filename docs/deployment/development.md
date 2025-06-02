# 🛠 Development Environment - AccessWeaver

Guide pour configurer rapidement un environnement de développement AccessWeaver sur AWS avec un focus sur l'économie et la simplicité.

## 🎯 Vue d'Ensemble Développement

### Architecture Simplifiée Dev
```
┌─────────────────────────────────────────────────────────┐
│                    Internet                             │
└─────────────────────┬───────────────────────────────────┘
                      │ HTTP/HTTPS
┌─────────────────────▼───────────────────────────────────┐
│              ALB (Single AZ)                            │
│           dev.accessweaver.com                          │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│            ECS Fargate (Minimal)                        │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐        │
│  │API Gateway  │ │PDP Service  │ │PAP Service  │        │
│  │   (1 inst)  │ │   (1 inst)  │ │   (1 inst)  │        │
│  │256/512MB    │ │512/1GB      │ │256/512MB    │        │
│  └─────────────┘ └─────────────┘ └─────────────┘        │
│                                                         │
│  ┌─────────────┐ ┌─────────────┐                        │
│  │Tenant Svc   │ │Audit Service│                        │
│  │   (1 inst)  │ │   (1 inst)  │                        │
│  │256/512MB    │ │256/512MB    │                        │
│  └─────────────┘ └─────────────┘                        │
└─────────────────────┬───────────────────────────────────┘
                      │
    ┌─────────────────┼─────────────────┐
    │                 │                 │
┌───▼───┐      ┌─────▼─────┐      ┌────▼────┐
│RDS    │      │Redis      │      │CloudWatch│
│PG15   │      │Single Node│      │Logs     │
│t3.micro│      │t3.micro   │      │Basic    │
│Single-AZ│     │512MB      │      │         │
└───────┘      └───────────┘      └─────────┘
```

### Caractéristiques Dev

| Aspect | Configuration |
|--------|---------------|
| **💰 Coût estimé/mois** | ~$95-120 |
| **👥 Utilisateurs supportés** | 10-50 développeurs |
| **⚡ Performance** | <100ms (acceptable) |
| **🔄 Disponibilité** | 95%+ (non critique) |
| **🔒 Sécurité** | Basique + HTTPS |
| **📊 Monitoring** | Logs de base |
| **💾 Backup** | 1 jour (économique) |
| **🌍 Multi-AZ** | Single AZ |

## 🚀 Quick Start (30 minutes)

### Étape 1 : Prérequis

```bash
# 1. AWS CLI configuré
aws configure
aws sts get-caller-identity

# 2. Terraform installé
terraform version  # >= 1.0

# 3. Clone du repository
git clone https://github.com/accessweaver/aw-infrastructure-as-code.git
cd aw-infrastructure-as-code
```

### Étape 2 : Setup Backend

```bash
# Setup du backend Terraform pour dev
./scripts/setup-backend.sh dev eu-west-1

# Vérification
aws s3 ls s3://accessweaver-terraform-state-dev-*
```

### Étape 3 : Configuration Minimale

```bash
# Copier et éditer les variables
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars

# Configuration minimale requise pour démarrer
cat > environments/dev/terraform.tfvars << 'EOF'
# Configuration minimale AccessWeaver Dev
project_name = "accessweaver"
environment  = "dev"
aws_region   = "eu-west-1"

# Network
vpc_cidr = "10.0.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b"]

# Économique - single NAT Gateway
enable_nat_gateway = true
single_nat_gateway = true

# Database - minimal
database_name = "accessweaver"
master_username = "postgres"
# password généré automatiquement

# Redis - minimal  
redis_port = 6379

# ECS - minimal
container_registry = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/accessweaver"
image_tag = "latest"

# Monitoring basique
enable_monitoring = true
log_retention_days = 7

# Tags
default_tags = {
  Project     = "AccessWeaver"
  Environment = "dev"
  ManagedBy   = "Terraform"
  CostCenter  = "Engineering"
  Purpose     = "Development"
}
EOF
```

### Étape 4 : Déploiement Rapide

```bash
# 1. Initialisation
make init ENV=dev

# 2. Plan et vérification
make plan ENV=dev

# 3. Déploiement complet
make apply ENV=dev

# Durée estimée : 15-20 minutes
```

### Étape 5 : Vérification

```bash
# 1. Vérifier les services
terraform output health_check_urls

# 2. Tester l'API
API_URL=$(terraform output public_url)
curl -f "$API_URL/actuator/health"

# 3. Vérifier les logs
aws logs tail /ecs/accessweaver-dev/aw-api-gateway --since 10m
```

## 🛠 Développement Local + AWS

### Configuration Hybride

Pour un développement optimal, combinez local + AWS :

```yaml
# docker-compose.dev.yml - Services locaux
version: '3.8'
services:
  # Base de données locale pour développement rapide
  postgres-local:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: accessweaver_local
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: dev_password
    ports:
      - "5432:5432"
    
  # Redis local pour tests
  redis-local:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes

  # Services AccessWeaver pointant vers AWS
  aw-api-gateway:
    build: ./services/aw-api-gateway
    ports:
      - "8080:8080"
    environment:
      # Local DB + AWS services
      DATABASE_URL: jdbc:postgresql://postgres-local:5432/accessweaver_local
      REDIS_URL: redis://redis-local:6379
      
      # AWS services pour intégration
      AWS_REGION: eu-west-1
      SPRING_PROFILES_ACTIVE: dev-local
```

### Configuration Spring Profiles

```yaml
# application-dev-local.yml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/accessweaver_local
    username: postgres
    password: dev_password
  
  redis:
    host: localhost
    port: 6379
    
  # AWS services pour tests d'intégration
accessweaver:
  aws:
    region: eu-west-1
    # Utilise les services AWS dev pour tests end-to-end
    secrets-manager:
      enabled: false  # Secrets locaux
    cloudwatch:
      enabled: false  # Pas de metrics en local
```

## 🔧 Configuration par Cas d'Usage

### 1. Développement Backend uniquement

```bash
# Configuration minimale - Backend seulement
cat > environments/dev/backend-only.tfvars << 'EOF'
# Désactiver ALB et services non-essentiels
enable_alb = false
enable_monitoring = false

# Services ECS minimaux
service_overrides = {
  "aw-api-gateway" = {
    desired_count = 1
    cpu           = 256
    memory        = 512
  }
  "aw-pdp-service" = {
    desired_count = 1
    cpu           = 512
    memory        = 1024
  }
}

# Désactiver les services non-critiques
enable_audit_service = false
EOF

# Déploiement
terraform apply -var-file="backend-only.tfvars" environments/dev/
```

### 2. Tests d'Intégration

```bash
# Configuration pour tests automatisés
cat > environments/dev/testing.tfvars << 'EOF'
# Auto-scaling désactivé pour stabilité des tests
auto_scaling_enabled = false

# Logs verbeux pour debugging
common_environment_variables = {
  "SPRING_PROFILES_ACTIVE" = "dev,test"
  "LOGGING_LEVEL_ROOT" = "DEBUG"
  "LOGGING_LEVEL_COM_ACCESSWEAVER" = "TRACE"
}

# Health checks plus fréquents
health_check_interval = 10
health_check_timeout = 5
EOF
```

### 3. Démonstration Client

```bash
# Configuration pour démo client
cat > environments/dev/demo.tfvars << 'EOF'
# Domaine personnalisé pour démo
custom_domain = "demo.accessweaver.com"

# Interface admin activée
enable_admin_ui = true

# Données de démonstration
load_demo_data = true

# Monitoring visible
enable_monitoring_dashboard = true
EOF
```

## 📊 Monitoring Développement

### Logs Essentiels

```bash
# 1. Logs applicatifs temps réel
aws logs tail /ecs/accessweaver-dev/aw-api-gateway --follow

# 2. Logs d'erreurs seulement
aws logs filter-log-events \
  --log-group-name "/ecs/accessweaver-dev/aw-api-gateway" \
  --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s)000

# 3. Logs de performance
aws logs filter-log-events \
  --log-group-name "/ecs/accessweaver-dev/aw-pdp-service" \
  --filter-pattern "[timestamp, requestId, ..., duration > 1000]" \
  --start-time $(date -d '1 hour ago' +%s)000
```

### Métriques de Base

```bash
# Dashboard simple pour développement
aws cloudwatch get-metric-widget-image \
  --metric-widget '{
    "metrics": [
      ["AWS/ECS", "CPUUtilization", "ServiceName", "accessweaver-dev-aw-api-gateway"],
      [".", "MemoryUtilization", ".", "."],
      ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "app/accessweaver-dev-alb/xxx"]
    ],
    "period": 300,
    "stat": "Average",
    "region": "eu-west-1",
    "title": "AccessWeaver Dev - Overview"
  }' \
  --output-format png > dev-metrics.png
```

### Health Checks

```bash
#!/bin/bash
# scripts/health-check-dev.sh

echo "🔍 AccessWeaver Dev Health Check"

# 1. Services ECS
echo "📋 ECS Services:"
aws ecs describe-services \
  --cluster accessweaver-dev-cluster \
  --services \
    accessweaver-dev-aw-api-gateway \
    accessweaver-dev-aw-pdp-service \
    accessweaver-dev-aw-pap-service \
  --query 'services[*].[serviceName,status,runningCount,desiredCount]' \
  --output table

# 2. Health endpoints
echo "🌐 Health Endpoints:"
API_URL=$(terraform output -raw public_url)
curl -s "$API_URL/actuator/health" | jq .

# 3. Base de données
echo "🗄️ Database:"
DB_ENDPOINT=$(terraform output -raw db_instance_endpoint)
echo "Database endpoint: $DB_ENDPOINT"

# 4. Cache Redis
echo "⚡ Redis:"
REDIS_ENDPOINT=$(terraform output -raw redis_primary_endpoint)
echo "Redis endpoint: $REDIS_ENDPOINT"

echo "✅ Health check completed"
```

## 🔄 Cycles de Développement

### 1. Développement Feature

```bash
# 1. Créer une branche feature
git checkout -b feature/new-authorization-endpoint

# 2. Développement local avec hot reload
cd services/aw-api-gateway
./mvnw spring-boot:run -Dspring.profiles.active=dev-local

# 3. Tests unitaires
./mvnw test

# 4. Tests d'intégration contre AWS dev
./mvnw test -Dspring.profiles.active=dev-integration

# 5. Build et push vers ECR dev
docker build -t accessweaver/aw-api-gateway:feature-auth .
docker tag accessweaver/aw-api-gateway:feature-auth \
  123456789012.dkr.ecr.eu-west-1.amazonaws.com/accessweaver/aw-api-gateway:latest
docker push 123456789012.dkr.ecr.eu-west-1.amazonaws.com/accessweaver/aw-api-gateway:latest

# 6. Déploiement sur dev AWS
aws ecs update-service \
  --cluster accessweaver-dev-cluster \
  --service accessweaver-dev-aw-api-gateway \
  --force-new-deployment
```

### 2. Tests End-to-End

```bash
# Tests automatisés contre environnement dev
cd tests/e2e

# Configuration pour pointer vers dev AWS
export API_BASE_URL="https://$(terraform output -raw public_url)/api/v1"
export ADMIN_USERNAME="admin@accessweaver.dev"
export ADMIN_PASSWORD="dev_password"

# Exécution des tests
npm test -- --environment=dev

# Tests de charge légers
artillery run load-test-dev.yml
```

### 3. Debugging

```bash
# 1. Accès direct au container pour debugging
aws ecs execute-command \
  --cluster accessweaver-dev-cluster \
  --task $(aws ecs list-tasks \
    --cluster accessweaver-dev-cluster \
    --service-name accessweaver-dev-aw-api-gateway \
    --query 'taskArns[0]' --output text) \
  --container aw-api-gateway \
  --interactive \
  --command "/bin/bash"

# 2. Port forward pour debugging local
aws ecs execute-command \
  --cluster accessweaver-dev-cluster \
  --task TASK_ID \
  --container aw-api-gateway \
  --interactive \
  --command "curl localhost:8080/actuator/env"
```

## 💰 Optimisation des Coûts Dev

### 1. Arrêt Automatique

```bash
# Script d'arrêt automatique le soir
#!/bin/bash
# scripts/stop-dev-environment.sh

echo "⏸️ Stopping AccessWeaver Dev Environment"

# 1. Scaler tous les services à 0
aws ecs update-service \
  --cluster accessweaver-dev-cluster \
  --service accessweaver-dev-aw-api-gateway \
  --desired-count 0

aws ecs update-service \
  --cluster accessweaver-dev-cluster \
  --service accessweaver-dev-aw-pdp-service \
  --desired-count 0

# 2. Arrêter RDS (sauf si multi-AZ)
aws rds stop-db-instance \
  --db-instance-identifier accessweaver-dev-postgres

echo "💰 Environment stopped - Costs reduced by ~80%"
```

### 2. Redémarrage Automatique

```bash
# Script de redémarrage le matin
#!/bin/bash
# scripts/start-dev-environment.sh

echo "▶️ Starting AccessWeaver Dev Environment"

# 1. Redémarrer RDS
aws rds start-db-instance \
  --db-instance-identifier accessweaver-dev-postgres

# 2. Attendre que RDS soit disponible
aws rds wait db-instance-available \
  --db-instance-identifier accessweaver-dev-postgres

# 3. Scaler les services
aws ecs update-service \
  --cluster accessweaver-dev-cluster \
  --service accessweaver-dev-aw-api-gateway \
  --desired-count 1

# 4. Health check
sleep 60
curl -f "$(terraform output -raw public_url)/actuator/health"

echo "✅ Environment started and healthy"
```

### 3. Automation avec CRON

```bash
# Ajouter dans crontab pour automation
crontab -e

# Arrêt automatique à 20h en semaine
0 20 * * 1-5 /path/to/scripts/stop-dev-environment.sh

# Redémarrage automatique à 8h en semaine
0 8 * * 1-5 /path/to/scripts/start-dev-environment.sh

# Arrêt weekend
0 18 * * 5 /path/to/scripts/stop-dev-environment.sh
0 9 * * 1 /path/to/scripts/start-dev-environment.sh
```

## 🛠 Outils de Développement

### 1. CLI AccessWeaver

```bash
# Installation du CLI de développement
npm install -g @accessweaver/cli

# Configuration pour dev
aw config set api-url "$(terraform output -raw public_url)/api/v1"
aw config set environment dev

# Commandes utiles
aw health                    # Status des services
aw logs api-gateway --tail   # Logs en temps réel
aw scale pdp-service 2       # Scaling manuel
aw restart all               # Redémarrage des services
```

### 2. VS Code Integration

```json
// .vscode/settings.json
{
  "accessweaver.devEnvironment": {
    "apiUrl": "https://dev.accessweaver.com/api/v1",
    "awsRegion": "eu-west-1",
    "clusterName": "accessweaver-dev-cluster"
  },
  "rest-client.environmentVariables": {
    "dev": {
      "baseUrl": "https://dev.accessweaver.com/api/v1",
      "authToken": "dev_jwt_token_here"
    }
  }
}
```

### 3. Postman Collection

```json
{
  "info": {
    "name": "AccessWeaver Dev API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "variable": [
    {
      "key": "baseUrl",
      "value": "{{dev_api_url}}/api/v1"
    }
  ],
  "item": [
    {
      "name": "Health Check",
      "request": {
        "method": "GET",
        "url": "{{baseUrl}}/actuator/health"
      }
    }
  ]
}
```

## 🚨 Troubleshooting Dev

### Problèmes Courants

#### 1. Service qui ne démarre pas

```bash
# 1. Vérifier les logs
aws logs tail /ecs/accessweaver-dev/aw-api-gateway --since 10m

# 2. Vérifier la task definition
aws ecs describe-task-definition \
  --task-definition accessweaver-dev-aw-api-gateway

# 3. Redémarrer le service
aws ecs update-service \
  --cluster accessweaver-dev-cluster \
  --service accessweaver-dev-aw-api-gateway \
  --force-new-deployment
```

#### 2. Problème de connexion DB

```bash
# 1. Vérifier le status RDS
aws rds describe-db-instances \
  --db-instance-identifier accessweaver-dev-postgres \
  --query 'DBInstances[0].DBInstanceStatus'

# 2. Tester la connectivité
aws ecs execute-command \
  --cluster accessweaver-dev-cluster \
  --task TASK_ID \
  --container aw-api-gateway \
  --interactive \
  --command "pg_isready -h DB_ENDPOINT -p 5432"
```

#### 3. Problème de performance

```bash
# 1. Vérifier les ressources
aws ecs describe-services \
  --cluster accessweaver-dev-cluster \
  --services accessweaver-dev-aw-pdp-service \
  --query 'services[0].deployments[0].taskDefinition'

# 2. Scaler temporairement
aws ecs update-service \
  --cluster accessweaver-dev-cluster \
  --service accessweaver-dev-aw-pdp-service \
  --desired-count 2
```

---

## 📋 Checklist Setup Dev

### Initial Setup
- [ ] AWS CLI configuré et testé
- [ ] Terraform installé (>= 1.0)
- [ ] Repository cloné
- [ ] Backend S3/DynamoDB créé
- [ ] Variables configurées
- [ ] Déploiement initial réussi

### Tests de Base
- [ ] Health checks passent
- [ ] API répond correctement
- [ ] Logs visibles dans CloudWatch
- [ ] Base de données accessible
- [ ] Cache Redis fonctionnel

### Développement Ready
- [ ] IDE configuré avec endpoints dev
- [ ] CLI AccessWeaver installé
- [ ] Postman/Tests automatisés fonctionnels
- [ ] Scripts de stop/start configurés
- [ ] Documentation équipe mise à jour

### Sécurité Dev
- [ ] Secrets stockés dans AWS Secrets Manager
- [ ] Pas de credentials en dur dans le code
- [ ] HTTPS activé même en dev
- [ ] Accès limité aux développeurs autorisés

## 🔄 Workflows Équipe

### 1. Onboarding Nouveau Développeur

```bash
#!/bin/bash
# scripts/onboard-developer.sh

DEVELOPER_NAME=$1
AWS_ACCOUNT_ID="123456789012"

echo "🚀 Onboarding développeur: $DEVELOPER_NAME"

# 1. Créer IAM user pour développeur
aws iam create-user --user-name "dev-$DEVELOPER_NAME"

# 2. Attacher policy développeur
aws iam attach-user-policy \
  --user-name "dev-$DEVELOPER_NAME" \
  --policy-arn "arn:aws:iam::$AWS_ACCOUNT_ID:policy/AccessWeaverDeveloperPolicy"

# 3. Créer access key
aws iam create-access-key --user-name "dev-$DEVELOPER_NAME"

# 4. Ajouter au groupe développeurs
aws iam add-user-to-group \
  --user-name "dev-$DEVELOPER_NAME" \
  --group-name "AccessWeaverDevelopers"

echo "✅ Développeur $DEVELOPER_NAME configuré"
echo "📧 Envoyer les credentials via canal sécurisé"
```

### 2. Politique IAM Développeur

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:*",
        "logs:*",
        "cloudwatch:GetMetricStatistics",
        "rds:DescribeDBInstances",
        "elasticache:DescribeCacheClusters"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "eu-west-1"
        },
        "StringLike": {
          "aws:PrincipalTag/Project": "AccessWeaver",
          "aws:PrincipalTag/Environment": "dev"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:eu-west-1:*:secret:accessweaver/dev/*"
    },
    {
      "Effect": "Deny",
      "Action": [
        "ecs:DeleteService",
        "ecs:DeleteCluster",
        "rds:DeleteDBInstance",
        "elasticache:DeleteCacheCluster"
      ],
      "Resource": "*"
    }
  ]
}
```

### 3. Branch Strategy

```bash
# Git workflow pour développement
echo "
📋 AccessWeaver Git Workflow:

🌿 Branches:
  main       → Production releases
  develop    → Development integration
  feature/*  → Features en développement
  hotfix/*   → Corrections urgentes

🔄 Process:
  1. feature/XXX → develop (PR + tests)
  2. develop → staging (déploiement auto)
  3. staging → main (validation + PR)
  4. main → production (déploiement manuel)

🧪 Tests:
  - feature: tests unitaires obligatoires
  - develop: tests intégration + e2e
  - staging: tests complets + performance
  - main: validation business + security
"
```

## 📊 Métriques de Développement

### Dashboard Développeur

```bash
# Créer dashboard CloudWatch pour équipe dev
aws cloudwatch put-dashboard \
  --dashboard-name "AccessWeaver-Development-Team" \
  --dashboard-body '{
    "widgets": [
      {
        "type": "metric",
        "properties": {
          "metrics": [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "accessweaver-dev-aw-api-gateway"],
            [".", "MemoryUtilization", ".", "."]
          ],
          "period": 300,
          "stat": "Average",
          "region": "eu-west-1",
          "title": "API Gateway - Ressources"
        }
      },
      {
        "type": "log",
        "properties": {
          "query": "SOURCE \"/ecs/accessweaver-dev/aw-api-gateway\"\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 20",
          "region": "eu-west-1",
          "title": "Erreurs Récentes"
        }
      }
    ]
  }'
```

### Alertes Développement

```bash
# Alertes Slack pour l'équipe dev
aws sns create-topic --name accessweaver-dev-alerts

# Webhook Slack
aws sns subscribe \
  --topic-arn arn:aws:sns:eu-west-1:123456789012:accessweaver-dev-alerts \
  --protocol https \
  --notification-endpoint https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK

# Alarme: Service down
aws cloudwatch put-metric-alarm \
  --alarm-name "AccessWeaver-Dev-Service-Down" \
  --alarm-description "Un service AccessWeaver dev est down" \
  --metric-name RunningCount \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:eu-west-1:123456789012:accessweaver-dev-alerts \
  --dimensions Name=ServiceName,Value=accessweaver-dev-aw-api-gateway
```

## 🔧 Personnalisation Environnement

### 1. Développeur Frontend

```bash
# Configuration spécifique frontend
cat > environments/dev/frontend-dev.tfvars << 'EOF'
# Désactiver les services backend non nécessaires
service_overrides = {
  "aw-audit-service" = {
    desired_count = 0  # Pas besoin en dev frontend
  }
}

# CORS permissif pour développement local
common_environment_variables = {
  "CORS_ALLOWED_ORIGINS" = "http://localhost:4200,http://localhost:3000"
  "CORS_ALLOW_CREDENTIALS" = "true"
}

# Interface admin activée
enable_admin_ui = true
admin_ui_domain = "admin-dev.accessweaver.com"
EOF
```

### 2. Développeur Backend

```bash
# Configuration backend focus
cat > environments/dev/backend-dev.tfvars << 'EOF'
# Ressources augmentées pour développement intensif
service_overrides = {
  "aw-pdp-service" = {
    cpu           = 1024
    memory        = 2048
    desired_count = 2  # Pour tests de charge
  }
}

# Logs verbeux pour debugging
common_environment_variables = {
  "LOGGING_LEVEL_ROOT" = "DEBUG"
  "LOGGING_LEVEL_SQL" = "DEBUG"
  "SPRING_JPA_SHOW_SQL" = "true"
  "HIBERNATE_FORMAT_SQL" = "true"
}

# Profiling activé
enable_application_profiling = true
EOF
```

### 3. Tests de Performance

```bash
# Configuration pour tests de charge
cat > environments/dev/performance-test.tfvars << 'EOF'
# Scaling pour supporter les tests
service_overrides = {
  "aw-api-gateway" = {
    desired_count = 3
    cpu           = 512
    memory        = 1024
  }
  "aw-pdp-service" = {
    desired_count = 3
    cpu           = 1024
    memory        = 2048
  }
}

# Database sizing pour tests
instance_class_override = "db.t3.small"
allocated_storage_override = 50

# Redis sizing
node_type_override = "cache.t3.small"
num_cache_clusters_override = 2

# Auto-scaling activé
auto_scaling_enabled = true
max_capacity_override = 5
EOF
```

## 🧪 Tests et Validation

### Tests Automatisés Dev

```bash
#!/bin/bash
# scripts/run-dev-tests.sh

API_URL=$(terraform output -raw public_url)
echo "🧪 Running AccessWeaver Dev Tests against: $API_URL"

# 1. Health checks
echo "📋 Health Checks..."
curl -f "$API_URL/actuator/health" || exit 1

# 2. API fonctionnelle
echo "🔌 API Tests..."
curl -f "$API_URL/api/v1/health" || exit 1

# 3. Performance basique
echo "⚡ Performance Test..."
time curl -s "$API_URL/api/v1/policies" > /dev/null

# 4. Load test léger
echo "📊 Light Load Test..."
for i in {1..10}; do
  curl -s "$API_URL/actuator/health" &
done
wait

echo "✅ All tests passed!"
```

### Tests d'Intégration

```bash
#!/bin/bash
# scripts/integration-test-dev.sh

echo "🔗 Integration Tests - AccessWeaver Dev"

# Variables
DB_ENDPOINT=$(terraform output -raw db_instance_endpoint)
REDIS_ENDPOINT=$(terraform output -raw redis_primary_endpoint)
API_URL=$(terraform output -raw public_url)

# 1. Test connectivité base de données
echo "🗄️ Testing Database connectivity..."
PGPASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id accessweaver/dev/database \
  --query SecretString --output text | jq -r .password)

psql -h "$DB_ENDPOINT" -U postgres -d accessweaver -c "SELECT 1;" || exit 1

# 2. Test Redis
echo "⚡ Testing Redis connectivity..."
REDIS_TOKEN=$(aws secretsmanager get-secret-value \
  --secret-id accessweaver/dev/redis \
  --query SecretString --output text | jq -r .auth_token)

# Test via container ECS (Redis non accessible directement)
aws ecs execute-command \
  --cluster accessweaver-dev-cluster \
  --task $(aws ecs list-tasks \
    --cluster accessweaver-dev-cluster \
    --service-name accessweaver-dev-aw-api-gateway \
    --query 'taskArns[0]' --output text) \
  --container aw-api-gateway \
  --interactive \
  --command "redis-cli -h ${REDIS_ENDPOINT%%:*} -p 6379 -a $REDIS_TOKEN ping"

# 3. Test flow complet
echo "🔄 Testing complete authorization flow..."
# JWT token pour tests
JWT_TOKEN="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..." # Token de test

# Test RBAC
curl -H "Authorization: Bearer $JWT_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"user":"test@example.com","action":"read","resource":"document"}' \
     "$API_URL/api/v1/check" || exit 1

echo "✅ Integration tests completed successfully!"
```

## 📱 Mobile/Frontend Development

### Configuration CORS

```yaml
# Configuration spéciale pour développement mobile/frontend
accessweaver:
  cors:
    allowed-origins:
      - "http://localhost:3000"    # React dev server
      - "http://localhost:4200"    # Angular dev server
      - "http://localhost:8081"    # Vue dev server
      - "capacitor://localhost"    # Ionic Capacitor
      - "http://localhost"         # Ionic serve
    allowed-methods:
      - GET
      - POST
      - PUT
      - DELETE
      - OPTIONS
    allowed-headers:
      - "*"
    allow-credentials: true
    max-age: 3600
```

### Mock Data pour Frontend

```bash
# Script pour charger des données de démo
#!/bin/bash
# scripts/load-demo-data.sh

API_URL=$(terraform output -raw public_url)

echo "📊 Loading demo data for frontend development..."

# 1. Créer des tenants de démo
curl -X POST "$API_URL/api/v1/tenants" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Demo Company",
    "subdomain": "demo",
    "plan": "enterprise"
  }'

# 2. Créer des utilisateurs de démo
curl -X POST "$API_URL/api/v1/users" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@demo.com",
    "roles": ["admin"],
    "tenantId": "demo"
  }'

# 3. Créer des policies de démo
curl -X POST "$API_URL/api/v1/policies" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Document Access Policy",
    "rules": [
      {
        "effect": "allow",
        "subjects": ["role:employee"],
        "actions": ["read"],
        "resources": ["document:*"]
      }
    ]
  }'

echo "✅ Demo data loaded successfully!"
```

## 🔄 Backup et Restauration Dev

### Backup Quotidien

```bash
#!/bin/bash
# scripts/backup-dev-db.sh

echo "💾 Backing up AccessWeaver Dev Database..."

DB_IDENTIFIER="accessweaver-dev-postgres"
BACKUP_NAME="dev-backup-$(date +%Y%m%d-%H%M)"

# Créer snapshot RDS
aws rds create-db-snapshot \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --db-snapshot-identifier "$BACKUP_NAME"

echo "✅ Backup initiated: $BACKUP_NAME"

# Nettoyer les anciens snapshots (garder 7 jours)
aws rds describe-db-snapshots \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --snapshot-type manual \
  --query "DBSnapshots[?SnapshotCreateTime<='$(date -d '7 days ago' --iso-8601)'].DBSnapshotIdentifier" \
  --output text | while read snapshot; do
    if [ -n "$snapshot" ]; then
      echo "🗑️ Deleting old snapshot: $snapshot"
      aws rds delete-db-snapshot --db-snapshot-identifier "$snapshot"
    fi
  done
```

### Restauration Rapide

```bash
#!/bin/bash
# scripts/restore-dev-db.sh

SNAPSHOT_ID=$1

if [ -z "$SNAPSHOT_ID" ]; then
  echo "Usage: $0 <snapshot-identifier>"
  echo "Available snapshots:"
  aws rds describe-db-snapshots \
    --db-instance-identifier accessweaver-dev-postgres \
    --snapshot-type manual \
    --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime]' \
    --output table
  exit 1
fi

echo "🔄 Restoring from snapshot: $SNAPSHOT_ID"

# 1. Arrêter les services ECS
aws ecs update-service \
  --cluster accessweaver-dev-cluster \
  --service accessweaver-dev-aw-api-gateway \
  --desired-count 0

# 2. Supprimer l'instance actuelle
aws rds delete-db-instance \
  --db-instance-identifier accessweaver-dev-postgres \
  --skip-final-snapshot

# 3. Restaurer depuis snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier accessweaver-dev-postgres \
  --db-snapshot-identifier "$SNAPSHOT_ID"

# 4. Attendre que la DB soit disponible
echo "⏳ Waiting for database to be available..."
aws rds wait db-instance-available \
  --db-instance-identifier accessweaver-dev-postgres

# 5. Redémarrer les services
aws ecs update-service \
  --cluster accessweaver-dev-cluster \
  --service accessweaver-dev-aw-api-gateway \
  --desired-count 1

echo "✅ Database restored successfully!"
```

---

## 📈 Évolution de l'Environnement Dev

### Métriques de Performance

```bash
# Suivre l'évolution des performances en dev
echo "📊 AccessWeaver Dev - Performance Evolution"

# CPU moyen par service sur 7 jours
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=accessweaver-dev-aw-api-gateway \
  --start-time $(date -d '7 days ago' --iso-8601) \
  --end-time $(date --iso-8601) \
  --period 86400 \
  --statistics Average \
  --query 'Datapoints[*].[Timestamp,Average]' \
  --output table

# Requêtes ALB par jour
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=$(terraform output -raw alb_arn_suffix) \
  --start-time $(date -d '7 days ago' --iso-8601) \
  --end-time $(date --iso-8601) \
  --period 86400 \
  --statistics Sum \
  --query 'Datapoints[*].[Timestamp,Sum]' \
  --output table
```

---

**🎯 Cet environnement de développement est optimisé pour :**
- ✅ Développement rapide et itératif
- ✅ Tests d'intégration complets
- ✅ Coûts maîtrisés (~$100/mois)
- ✅ Onboarding simple des développeurs
- ✅ Debugging et troubleshooting facile

**💡 Bonnes Pratiques :**
- Toujours tester en local avant déploiement dev AWS
- Utiliser les scripts d'arrêt/démarrage pour économiser
- Sauvegarder avant tests destructifs
- Documenter les modifications pour l'équipe