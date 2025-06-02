# 🎭 Déploiement Staging - AccessWeaver

Guide complet pour déployer AccessWeaver en environnement staging - **le parfait équilibre entre réalisme production et coûts maîtrisés**.

---

## 🎯 Objectifs de l'Environnement Staging

### ✅ **Réplication Fidèle de Production**
- **Multi-AZ** avec haute disponibilité réelle
- **Tous les services** déployés et interconnectés
- **Même architecture** que production (échelle réduite)
- **Features complètes** : WAF, monitoring, alerting, backup

### ✅ **Validation Pré-Production**
- **Tests d'intégration** end-to-end complets
- **Tests de charge** jusqu'à 1000 req/min
- **Tests de failover** et disaster recovery
- **Validation des déploiements** avant production

### ✅ **Formation et Démonstrations**
- **Environnement de démo** client stable
- **Formation équipe** sur les procédures
- **Tests des runbooks** d'exploitation
- **Validation UX/UI** dans conditions réelles

### ✅ **Budget Optimisé**
- **Coût cible : ~$300/mois** (vs $2500 en prod)
- **Instances réduites** mais architecture identique
- **Automatisation complète** du provisioning
- **Cleanup automatique** des ressources temporaires

---

## 🏗 Architecture Staging

```
                              Internet (HTTPS only)
                                        ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Route 53 + ACM SSL                          │
│              staging.accessweaver.com                          │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                  AWS WAF (Protection OWASP)                    │
│              Rate Limit: 1000 req/5min                         │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│           Application Load Balancer (Multi-AZ)                 │
│                SSL Termination TLS 1.2+                        │
└─────────────────────┬───────────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
┌───────▼───┐    ┌───▼───┐     ┌──▼──┐
│    AZ-1a   │    │ AZ-1b │     │AZ-1c│
└───────────┘    └───────┘     └─────┘
        │             │             │
┌─────────────────────▼───────────────────────────────────────────┐
│                ECS Fargate Cluster                             │
│                                                                 │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│ │API Gateway  │ │PDP Service  │ │PAP Service  │ │Tenant Svc   │ │
│ │  2 tasks    │ │  2 tasks    │ │  1 task     │ │  1 task     │ │
│ │512CPU/1GB   │ │1024CPU/2GB  │ │512CPU/1GB   │ │256CPU/512MB │ │
│ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │
│ ┌─────────────┐                                                 │
│ │Audit Service│ 🔀 Auto-Scaling: 1-4 instances                │ │
│ │  1 task     │ 📊 Container Insights: ON                     │ │
│ │256CPU/512MB │ 🎯 Target: 70% CPU, 80% Memory                │ │
│ └─────────────┘                                                 │
└─────────────────────▼───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│              Private Network Layer                              │
│                                                                 │
│ ┌─────────────────┐         ┌─────────────────┐                 │
│ │ RDS PostgreSQL  │◄────────┤ Redis Cluster   │                 │
│ │                 │         │                 │                 │
│ │ db.t3.small     │         │ cache.t3.small  │                 │
│ │ Multi-AZ ✅     │         │ 2 nodes (M+R)   │                 │
│ │ 50GB storage    │         │ Multi-AZ ✅     │                 │
│ │ 7 days backup   │         │ 5 days backup   │                 │
│ └─────────────────┘         └─────────────────┘                 │
└─────────────────────────────────────────────────────────────────┘

💰 Coût Total Estimé: ~$300/mois
📈 Performance: 1000+ req/min, <500ms p99
🔧 Monitoring: CloudWatch + Container Insights + Alerting
```

---

## 💰 Budget Détaillé Staging

| Composant | Service | Config Staging | Coût/Mois | vs Prod |
|-----------|---------|----------------|-----------|---------|
| **Compute** | ECS Fargate | 6 tasks, CPU réduit | $85 | -75% |
| **Database** | RDS PostgreSQL | db.t3.small, Multi-AZ | $65 | -70% |
| **Cache** | ElastiCache Redis | 2×cache.t3.small | $48 | -60% |
| **Load Balancer** | ALB + WAF | Standard config | $35 | -30% |
| **Network** | VPC, NAT Gateway | Multi-AZ | $45 | -20% |
| **Storage** | EBS + S3 logs | 50GB + lifecycle | $15 | -50% |
| **Monitoring** | CloudWatch + Insights | Standard retention | $12 | -60% |
| **DNS & SSL** | Route 53 + ACM | staging subdomain | $5 | -50% |
| **🎯 TOTAL** | | | **~$310/mois** | **-75%** |

### 💡 Stratégies d'Économies vs Production

| Optimisation | Économies | Impact |
|--------------|-----------|--------|
| **Instance sizes** | 60-70% | ✅ Aucun impact fonctionnel |
| **Storage réduit** | 50% | ✅ Suffisant pour tests |
| **Retention logs** | 60% | ✅ 14j vs 30j en prod |
| **1 NAT Gateway** | 50% | ⚠️ Single point (acceptable) |
| **Pas de Reserved Instances** | Variable | ⚠️ Peut optimiser plus tard |

---

## 🚀 Déploiement Étape par Étape

### 📋 **Phase 1 : Préparation (15 min)**

#### 1.1 Vérification des Prérequis

```bash
# Vérifier les outils requis
terraform --version  # >= 1.6.0
aws --version        # >= 2.13.0
make --version       # >= 3.81

# Vérifier la configuration AWS
aws sts get-caller-identity
aws sts get-caller-identity --query Account --output text

# Vérifier les permissions IAM nécessaires
aws iam simulate-principal-policy \
  --policy-source-arn $(aws sts get-caller-identity --query Arn --output text) \
  --action-names ec2:CreateVpc rds:CreateDBInstance ecs:CreateCluster \
  --resource-arns "*"
```

#### 1.2 Setup du Repository

```bash
# Cloner ou naviguer vers le repository
cd aw-infrastructure-as-code

# Vérifier la structure
tree -L 2
├── environments/
│   ├── dev/
│   ├── staging/     # ← Notre focus
│   └── prod/
├── modules/
│   ├── vpc/
│   ├── rds/
│   ├── redis/
│   ├── ecs/
│   └── alb/
└── docs/
```

#### 1.3 Configuration Backend S3

```bash
# Initialiser le backend Terraform pour staging
./scripts/setup-backend.sh staging eu-west-1

# Vérifier la création du backend
aws s3 ls s3://accessweaver-terraform-state-staging-$(aws sts get-caller-identity --query Account --output text)
aws dynamodb describe-table --table-name accessweaver-terraform-locks-staging --region eu-west-1
```

### 📋 **Phase 2 : Configuration Variables (10 min)**

#### 2.1 Création du fichier de variables

```bash
# Copier le template
cp environments/staging/terraform.tfvars.example environments/staging/terraform.tfvars

# Éditer les variables spécifiques staging
cat > environments/staging/terraform.tfvars << EOF
# =============================================================================
# AccessWeaver Staging Environment Configuration
# =============================================================================

# Project Configuration
project_name = "accessweaver"
environment  = "staging"
aws_region   = "eu-west-1"

# Network Configuration
vpc_cidr = "10.1.0.0/16"  # Différent de dev (10.0.x) et prod (10.2.x)
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

# Domain & SSL
custom_domain = "accessweaver.com"  # staging.accessweaver.com sera créé
route53_zone_id = "Z1234567890ABCDEF"  # À remplacer par votre zone

# Database Configuration (Optimisé staging)
db_instance_class = "db.t3.small"      # Plus petit que prod (db.r6g.large)
db_allocated_storage = 50              # 50GB vs 200GB en prod
db_multi_az = true                     # HA comme en prod
db_backup_retention = 7                # 7 jours vs 30 en prod

# Redis Configuration (Optimisé staging)
redis_node_type = "cache.t3.small"     # Plus petit que prod
redis_num_cache_nodes = 2              # Master + 1 replica
redis_auth_token_enabled = true

# ECS Configuration (Ressources réduites)
ecs_cpu_base = 512                     # 512 vs 1024 en prod
ecs_memory_base = 1024                 # 1GB vs 2GB en prod
ecs_desired_count_base = 1             # Moins d'instances qu'en prod
ecs_max_capacity = 4                   # Scaling limité vs 10 en prod

# ALB & WAF Configuration
enable_waf = true                      # Comme en prod
waf_rate_limit = 1000                  # Plus strict que dev, moins que prod
alb_access_logs = true                 # Logging activé
alb_deletion_protection = false        # Flexibilité pour tests

# Monitoring Configuration
enable_container_insights = true       # Comme en prod
log_retention_days = 14               # 14j vs 30j en prod
enable_performance_insights = false   # Économie vs prod

# Security Configuration
force_https_redirect = true           # Comme en prod
enable_encryption = true              # Chiffrement obligatoire

# Cost Optimization
enable_fargate_spot = true            # 30% Spot pour économies
single_nat_gateway = true             # 1 NAT vs 3 en prod
skip_final_snapshot = false           # Sécurité

# Tags pour gestion des coûts
default_tags = {
  Project      = "AccessWeaver"
  Environment  = "staging"
  ManagedBy    = "Terraform"
  CostCenter   = "Engineering"
  Owner        = "Platform Team"
  BusinessUnit = "Product"
  Purpose      = "PreProd Testing"
  Compliance   = "GDPR"
}
EOF
```

#### 2.2 Validation de la Configuration

```bash
# Valider la syntaxe Terraform
cd environments/staging
terraform fmt -check
terraform validate

# Vérifier les variables
terraform console
> var.project_name
> var.environment
> var.vpc_cidr
```

### 📋 **Phase 3 : Déploiement Infrastructure (45 min)**

#### 3.1 Initialisation Terraform

```bash
# Initialiser Terraform avec backend S3
make init ENV=staging

# Vérifier l'état initial
terraform show
terraform state list  # Doit être vide
```

#### 3.2 Planification et Validation

```bash
# Créer un plan détaillé
make plan ENV=staging

# Analyser les ressources qui seront créées
grep "# will be created" terraform.tfplan -A 2 | head -20

# Estimer les coûts (optionnel avec Infracost)
infracost breakdown --path . --terraform-plan-path terraform.tfplan
```

#### 3.3 Déploiement par Phases

**Phase 3.3.1 : Réseau (VPC, Subnets, NAT) - 10 min**

```bash
# Déployer le réseau en premier
terraform apply -target=module.vpc -auto-approve

# Vérifier la création
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=accessweaver-staging-vpc"
aws ec2 describe-subnets --filters "Name=tag:Environment,Values=staging"
```

**Phase 3.3.2 : Sécurité (Security Groups, KMS) - 5 min**

```bash
# Déployer les groupes de sécurité
terraform apply -target=module.vpc.aws_security_group -auto-approve
terraform apply -target=aws_kms_key -auto-approve
```

**Phase 3.3.3 : Base de Données (RDS PostgreSQL) - 15 min**

```bash
# Déployer RDS (le plus long)
terraform apply -target=module.rds -auto-approve

# Attendre que RDS soit disponible
aws rds wait db-instance-available --db-instance-identifier accessweaver-staging-postgres

# Vérifier la connectivité (optionnel)
aws rds describe-db-instances --db-instance-identifier accessweaver-staging-postgres \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address}'
```

**Phase 3.3.4 : Cache (Redis ElastiCache) - 10 min**

```bash
# Déployer Redis
terraform apply -target=module.redis -auto-approve

# Vérifier le statut
aws elasticache describe-replication-groups \
  --replication-group-id accessweaver-staging-redis \
  --query 'ReplicationGroups[0].Status'
```

**Phase 3.3.5 : Load Balancer (ALB + WAF) - 5 min**

```bash
# Déployer ALB
terraform apply -target=module.alb -auto-approve

# Vérifier DNS
nslookup staging.accessweaver.com
```

**Phase 3.3.6 : Services ECS Fargate - 10 min**

```bash
# Déployer tous les services
terraform apply -auto-approve

# Vérifier les services ECS
aws ecs list-services --cluster accessweaver-staging-cluster
aws ecs describe-services --cluster accessweaver-staging-cluster \
  --services accessweaver-staging-aw-api-gateway
```

### 📋 **Phase 4 : Configuration Post-Déploiement (20 min)**

#### 4.1 Validation DNS et SSL

```bash
# Vérifier la propagation DNS
dig staging.accessweaver.com
nslookup staging.accessweaver.com

# Tester SSL
curl -I https://staging.accessweaver.com/actuator/health
openssl s_client -connect staging.accessweaver.com:443 -servername staging.accessweaver.com < /dev/null
```

#### 4.2 Tests de Connectivité

```bash
# Test health check principal
curl -f https://staging.accessweaver.com/actuator/health | jq .

# Test API Gateway
curl -f https://staging.accessweaver.com/actuator/info | jq .

# Test documentation API
curl -I https://staging.accessweaver.com/swagger-ui/index.html
```

#### 4.3 Configuration Database Initiale

```bash
# Récupérer les credentials DB
ENDPOINT=$(terraform output -json | jq -r '.rds_endpoint.value')
USERNAME=$(terraform output -json | jq -r '.rds_username.value')
PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id accessweaver/staging/database \
  --query SecretString --output text | jq -r .password)

# Se connecter et vérifier
PGPASSWORD="$PASSWORD" psql -h "$ENDPOINT" -U "$USERNAME" -d accessweaver << EOF
-- Vérifier la configuration RLS
SHOW row_security;

-- Créer le schéma de base (si pas fait par migration)
CREATE SCHEMA IF NOT EXISTS accessweaver;

-- Vérifier les extensions disponibles
SELECT name FROM pg_available_extensions WHERE name IN ('uuid-ossp', 'pgcrypto');

-- Quitter
\q
EOF
```

#### 4.4 Configuration Redis

```bash
# Récupérer les infos Redis
REDIS_ENDPOINT=$(terraform output -json | jq -r '.redis_primary_endpoint.value')
REDIS_TOKEN=$(aws secretsmanager get-secret-value \
  --secret-id accessweaver/staging/redis \
  --query SecretString --output text | jq -r .auth_token)

# Tester la connexion Redis
redis-cli -h "${REDIS_ENDPOINT%:*}" -p 6379 -a "$REDIS_TOKEN" ping
# Expected: PONG

# Vérifier les paramètres Redis
redis-cli -h "${REDIS_ENDPOINT%:*}" -p 6379 -a "$REDIS_TOKEN" config get maxmemory-policy
redis-cli -h "${REDIS_ENDPOINT%:*}" -p 6379 -a "$REDIS_TOKEN" info memory
```

---

## 🧪 Tests et Validation

### 🔍 **Tests de Fonctionnement**

#### Test 1 : Santé Générale du Système

```bash
# Script de test complet
cat > test-staging-health.sh << 'EOF'
#!/bin/bash
set -e

BASE_URL="https://staging.accessweaver.com"
echo "🧪 Testing AccessWeaver Staging Environment"
echo "🌐 Base URL: $BASE_URL"

# Test 1: Health check général
echo "✅ Testing health check..."
curl -f "$BASE_URL/actuator/health" | jq .status
if [ $? -eq 0 ]; then echo "✅ Health check passed"; else echo "❌ Health check failed"; exit 1; fi

# Test 2: Info endpoint
echo "✅ Testing info endpoint..."
curl -f "$BASE_URL/actuator/info" | jq .app.name
if [ $? -eq 0 ]; then echo "✅ Info endpoint passed"; else echo "❌ Info endpoint failed"; fi

# Test 3: Swagger UI
echo "✅ Testing Swagger UI..."
curl -I "$BASE_URL/swagger-ui/index.html" | grep "200 OK"
if [ $? -eq 0 ]; then echo "✅ Swagger UI accessible"; else echo "❌ Swagger UI failed"; fi

# Test 4: SSL/TLS
echo "✅ Testing SSL/TLS..."
echo | openssl s_client -connect staging.accessweaver.com:443 -servername staging.accessweaver.com 2>/dev/null | openssl x509 -noout -issuer
if [ $? -eq 0 ]; then echo "✅ SSL certificate valid"; else echo "❌ SSL certificate invalid"; fi

echo "🎉 All basic tests passed!"
EOF

chmod +x test-staging-health.sh
./test-staging-health.sh
```

#### Test 2 : Performance de Base

```bash
# Test de charge basique avec Apache Bench
apt-get install -y apache2-utils  # ou brew install httpie sur Mac

# Test 100 requêtes, 10 concurrentes
ab -n 100 -c 10 https://staging.accessweaver.com/actuator/health

# Analyser les résultats
echo "✅ Rechercher ces métriques:"
echo "   - Time per request: < 500ms"
echo "   - Requests per second: > 20"
echo "   - Failed requests: 0"

# Test avec HTTPie pour plus de détails
http GET https://staging.accessweaver.com/actuator/health --print=HhBb --timeout=5
```

#### Test 3 : Failover et Résilience

```bash
# Test failover database (simulation panne)
echo "🧪 Testing database resilience..."

# Identifier l'instance primaire
aws rds describe-db-instances --db-instance-identifier accessweaver-staging-postgres \
  --query 'DBInstances[0].AvailabilityZone'

# Forcer un failover (uniquement si Multi-AZ)
aws rds reboot-db-instance \
  --db-instance-identifier accessweaver-staging-postgres \
  --force-failover

# Attendre et vérifier que l'app reste disponible
sleep 30
curl -f https://staging.accessweaver.com/actuator/health

echo "✅ Database failover test completed"
```

### 📊 **Tests de Monitoring**

#### Vérification CloudWatch

```bash
# Vérifier les métriques ALB
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=app/accessweaver-staging-alb/* \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum

# Vérifier les métriques ECS
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=accessweaver-staging-aw-api-gateway Name=ClusterName,Value=accessweaver-staging-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 900 \
  --statistics Average
```

#### Test des Alertes

```bash
# Déclencher une alerte CPU (simulation)
# Se connecter à une instance ECS pour générer de la charge
aws ecs execute-command \
  --cluster accessweaver-staging-cluster \
  --task $(aws ecs list-tasks --cluster accessweaver-staging-cluster --service-name accessweaver-staging-aw-api-gateway --query 'taskArns[0]' --output text) \
  --container aw-api-gateway \
  --interactive \
  --command "/bin/bash"

# Dans le container, générer de la charge CPU
# stress --cpu 2 --timeout 300  # 5 minutes
```

---

## 📈 Monitoring et Alerting

### 🔔 **Configuration des Alertes Staging**

Les alertes staging sont moins strictes que la production mais plus complètes que le développement :

| Métrique | Seuil Staging | Seuil Prod | Action |
|----------|---------------|------------|---------|
| **ALB Response Time** | > 1000ms | > 500ms | Email équipe |
| **ALB Error Rate 5xx** | > 20 erreurs/5min | > 10 erreurs/5min | Email + Slack |
| **ECS CPU** | > 80% | > 70% | Email |
| **ECS Memory** | > 85% | > 80% | Email |
| **RDS CPU** | > 85% | > 75% | Email |
| **RDS Connections** | > 80 | > 150 | Email |
| **Redis Memory** | > 85% | > 80% | Email |
| **Cache Hit Ratio** | < 70% | < 80% | Email |

### 📊 **Dashboards CloudWatch**

#### Dashboard Principal Staging

```bash
# Créer le dashboard CloudWatch pour staging
aws cloudwatch put-dashboard --dashboard-name "AccessWeaver-Staging-Overview" --dashboard-body '{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "app/accessweaver-staging-alb/*"],
          [".", "TargetResponseTime", ".", "."],
          [".", "HTTPCode_Target_2XX_Count", ".", "."],
          [".", "HTTPCode_ELB_5XX_Count", ".", "."]
        ],
        "period": 300,
        "stat": "Sum",
        "region": "eu-west-1",
        "title": "ALB Metrics - Staging"
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ECS", "CPUUtilization", "ServiceName", "accessweaver-staging-aw-api-gateway", "ClusterName", "accessweaver-staging-cluster"],
          [".", "MemoryUtilization", ".", ".", ".", "."]
        ],
        "period": 300,
        "stat": "Average",
        "region": "eu-west-1",
        "title": "ECS Metrics - API Gateway"
      }
    }
  ]
}'
```

### 📧 **Configuration SNS pour Alertes**

```bash
# Créer le topic SNS pour staging
aws sns create-topic --name accessweaver-staging-alerts

# Souscrire l'équipe aux alertes
aws sns subscribe \
  --topic-arn arn:aws:sns:eu-west-1:ACCOUNT-ID:accessweaver-staging-alerts \
  --protocol email \
  --notification-endpoint platform-team@accessweaver.com

# Configurer Slack (optionnel)
aws sns subscribe \
  --topic-arn arn:aws:sns:eu-west-1:ACCOUNT-ID:accessweaver-staging-alerts \
  --protocol https \
  --notification-endpoint https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
```

---

## 🛠 Maintenance et Opérations

### 🔄 **Mises à Jour Régulières**

#### Déploiement d'une Nouvelle Version

```bash
#!/bin/bash
# deploy-staging.sh - Script de déploiement staging

set -e

VERSION=${1:-latest}
CLUSTER="accessweaver-staging-cluster"

echo "🚀 Deploying AccessWeaver $VERSION to staging..."

# 1. Mettre à jour les images Docker
SERVICES=(
  "accessweaver-staging-aw-api-gateway"
  "accessweaver-staging-aw-pdp-service"  
  "accessweaver-staging-aw-pap-service"
  "accessweaver-staging-aw-tenant-service"
  "accessweaver-staging-aw-audit-service"
)

for SERVICE in "${SERVICES[@]}"; do
  echo "💤 Stopping $SERVICE..."
  aws ecs update-service \
    --cluster accessweaver-staging-cluster \
    --service $SERVICE \
    --desired-count 0
done

# Arrêter RDS (optionnel - économise ~$2/jour)
echo "💤 Stopping RDS instance..."
aws rds stop-db-instance --db-instance-identifier accessweaver-staging-postgres

echo "✅ Staging environment stopped - Savings: ~$5/day"
```

#### Redémarrage Automatique le Matin

```bash
# Cron job pour redémarrer staging le matin (8h)
# 0 8 * * 1-5 /usr/local/bin/start-staging.sh

#!/bin/bash
# start-staging.sh - Redémarrage automatique staging

echo "🌅 Starting staging environment..."

# Redémarrer RDS d'abord
echo "🔄 Starting RDS instance..."
aws rds start-db-instance --db-instance-identifier accessweaver-staging-postgres
aws rds wait db-instance-available --db-instance-identifier accessweaver-staging-postgres

# Redémarrer les services ECS
SERVICES=(
  "accessweaver-staging-aw-api-gateway"
  "accessweaver-staging-aw-pdp-service"  
  "accessweaver-staging-aw-pap-service"
  "accessweaver-staging-aw-tenant-service"
  "accessweaver-staging-aw-audit-service"
)

for SERVICE in "${SERVICES[@]}"; do
  echo "🚀 Starting $SERVICE..."
  aws ecs update-service \
    --cluster accessweaver-staging-cluster \
    --service $SERVICE \
    --desired-count 1
done

# Attendre que tout soit stable
echo "⏳ Waiting for services to be ready..."
sleep 120

# Vérification health check
curl -f https://staging.accessweaver.com/actuator/health
echo "✅ Staging environment ready!"
```

### 🧹 **Nettoyage Automatique**

#### Cleanup des Ressources Temporaires

```bash
#!/bin/bash
# cleanup-staging.sh - Nettoyage hebdomadaire

echo "🧹 Weekly cleanup of staging environment..."

# 1. Nettoyer les anciens logs CloudWatch
echo "📊 Cleaning old CloudWatch logs..."
for LOG_GROUP in $(aws logs describe-log-groups --log-group-name-prefix "/ecs/accessweaver-staging" --query 'logGroups[].logGroupName' --output text); do
  aws logs delete-retention-policy --log-group-name "$LOG_GROUP" || true
  aws logs put-retention-policy --log-group-name "$LOG_GROUP" --retention-in-days 14
done

# 2. Nettoyer les anciens snapshots RDS
echo "💾 Cleaning old RDS snapshots..."
aws rds describe-db-snapshots \
  --db-instance-identifier accessweaver-staging-postgres \
  --snapshot-type manual \
  --query 'DBSnapshots[?SnapshotCreateTime<=`2024-01-01`].DBSnapshotIdentifier' \
  --output text | while read SNAPSHOT; do
  if [ -n "$SNAPSHOT" ]; then
    aws rds delete-db-snapshot --db-snapshot-identifier "$SNAPSHOT"
    echo "🗑️ Deleted old snapshot: $SNAPSHOT"
  fi
done

# 3. Nettoyer les images Docker non utilisées dans ECR
echo "🐳 Cleaning unused Docker images..."
aws ecr list-repositories --query 'repositories[].repositoryName' --output text | while read REPO; do
  # Garder seulement les 10 dernières images
  aws ecr describe-images --repository-name "$REPO" \
    --query 'sort_by(imageDetails,&imagePushedAt)[:-10].imageDigest' \
    --output text | while read DIGEST; do
    if [ -n "$DIGEST" ]; then
      aws ecr batch-delete-image --repository-name "$REPO" --image-ids imageDigest="$DIGEST"
    fi
  done
done

# 4. Nettoyer les logs d'accès S3 anciens (> 30 jours)
echo "📁 Cleaning old S3 access logs..."
BUCKET=$(aws s3 ls | grep accessweaver-staging-alb-access-logs | awk '{print $3}')
if [ -n "$BUCKET" ]; then
  aws s3 ls "s3://$BUCKET/alb-access-logs/" --recursive | \
    awk '$1 < "'$(date -d '30 days ago' +%Y-%m-%d)'" {print $4}' | \
    while read FILE; do
      aws s3 rm "s3://$BUCKET/$FILE"
    done
fi

echo "✅ Cleanup completed!"
```

---

## 🔧 Troubleshooting Staging

### 🚨 **Problèmes Courants et Solutions**

#### Problème 1 : Services ECS ne démarrent pas

```bash
# Diagnostic ECS
echo "🔍 Diagnosing ECS issues..."

CLUSTER="accessweaver-staging-cluster"
SERVICE="accessweaver-staging-aw-api-gateway"

# 1. Vérifier le statut du service
aws ecs describe-services --cluster $CLUSTER --services $SERVICE \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Events:events[0:3]}'

# 2. Vérifier les événements récents
aws ecs describe-services --cluster $CLUSTER --services $SERVICE \
  --query 'services[0].events[0:5].[createdAt,message]' --output table

# 3. Vérifier les logs des tâches
TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE --query 'taskArns[0]' --output text)
if [ -n "$TASK_ARN" ]; then
  aws ecs describe-tasks --cluster $CLUSTER --tasks $TASK_ARN \
    --query 'tasks[0].{LastStatus:lastStatus,HealthStatus:healthStatus,StoppedReason:stoppedReason}'
fi

# 4. Vérifier les logs CloudWatch
aws logs tail "/ecs/accessweaver-staging/aw-api-gateway" --since 1h
```

**Solutions courantes :**

```bash
# Solution 1: Redémarrage forcé
aws ecs update-service --cluster $CLUSTER --service $SERVICE --force-new-deployment

# Solution 2: Vérifier les secrets
aws secretsmanager get-secret-value --secret-id accessweaver/staging/database --query SecretString
aws secretsmanager get-secret-value --secret-id accessweaver/staging/redis --query SecretString

# Solution 3: Vérifier la connectivité réseau
aws ec2 describe-security-groups --filters "Name=group-name,Values=accessweaver-staging-ecs-*"
```

#### Problème 2 : Base de données inaccessible

```bash
# Diagnostic RDS
echo "🔍 Diagnosing RDS connectivity..."

DB_INSTANCE="accessweaver-staging-postgres"

# 1. Vérifier le statut RDS
aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address,Port:Endpoint.Port}'

# 2. Vérifier les security groups
SECURITY_GROUPS=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE \
  --query 'DBInstances[0].VpcSecurityGroups[].VpcSecurityGroupId' --output text)

for SG in $SECURITY_GROUPS; do
  aws ec2 describe-security-groups --group-ids $SG --query 'SecurityGroups[0].IpPermissions'
done

# 3. Test de connectivité depuis une instance ECS
TASK_ARN=$(aws ecs list-tasks --cluster accessweaver-staging-cluster --service-name accessweaver-staging-aw-api-gateway --query 'taskArns[0]' --output text)

aws ecs execute-command \
  --cluster accessweaver-staging-cluster \
  --task $TASK_ARN \
  --container aw-api-gateway \
  --interactive \
  --command "pg_isready -h $DB_ENDPOINT -p 5432"
```

#### Problème 3 : Certificat SSL invalide

```bash
# Diagnostic SSL/TLS
echo "🔍 Diagnosing SSL certificate..."

# 1. Vérifier le certificat ACM
aws acm list-certificates --query 'CertificateSummaryList[?DomainName==`staging.accessweaver.com`]'

# 2. Vérifier la validation DNS
aws acm describe-certificate --certificate-arn "YOUR_CERT_ARN" \
  --query 'Certificate.DomainValidationOptions'

# 3. Vérifier Route 53
aws route53 list-resource-record-sets --hosted-zone-id "YOUR_ZONE_ID" \
  --query 'ResourceRecordSets[?Name==`staging.accessweaver.com.`]'

# 4. Test SSL externe
echo | openssl s_client -connect staging.accessweaver.com:443 -servername staging.accessweaver.com 2>/dev/null | openssl x509 -noout -dates -issuer
```

### 📞 **Escalade et Support**

#### Contacts d'Escalade Staging

| Problème | Contact | Disponibilité | Escalade |
|----------|---------|---------------|----------|
| **Services ECS Down** | Platform Team | 9h-18h | +15min → CTO |
| **Database Issues** | DBA Team | 9h-18h | +30min → Platform |
| **Network/DNS** | DevOps Lead | 9h-18h | +30min → Ops Manager |
| **Sécurité/Certificats** | Security Team | 9h-18h | +60min → CISO |
| **Performance** | Platform Team | 9h-18h | Non-critique |

#### Runbook d'Urgence Staging

```bash
#!/bin/bash
# emergency-staging-recovery.sh

echo "🚨 EMERGENCY RECOVERY - AccessWeaver Staging"
echo "Choose recovery option:"
echo "1. Full environment restart"
echo "2. Database failover"
echo "3. Rollback to previous version"
echo "4. Enable debug logging"
echo "5. Scale up resources"

read -p "Enter option (1-5): " OPTION

case $OPTION in
  1)
    echo "🔄 Full environment restart..."
    # Redémarrer tous les services
    ./scripts/restart-staging-full.sh
    ;;
  2)
    echo "🔄 Database failover..."
    aws rds reboot-db-instance --db-instance-identifier accessweaver-staging-postgres --force-failover
    ;;
  3)
    echo "⏪ Rollback to previous version..."
    # Logique de rollback
    ./scripts/rollback-staging.sh
    ;;
  4)
    echo "🐛 Enabling debug logging..."
    # Activer debug logs temporairement
    ./scripts/enable-debug-staging.sh
    ;;
  5)
    echo "📈 Scaling up resources..."
    # Scale up temporaire
    ./scripts/scale-up-staging.sh
    ;;
esac
```

---

## 📚 Documentation et Procédures

### 📖 **Guides Opérationnels**

#### Guide de Première Connexion

```markdown
# 🎯 Guide de Première Connexion - Staging AccessWeaver

## Pour les Développeurs

1. **Accès à l'interface web**
   - URL: https://staging.accessweaver.com
   - Login: Utiliser les credentials partagés sur Slack #accessweaver-team

2. **Accès API pour tests**
   ```bash
   # Obtenir un token JWT
   curl -X POST https://staging.accessweaver.com/api/v1/auth/login \
     -H "Content-Type: application/json" \
     -d '{"username":"demo","password":"demo123"}'
   
   # Utiliser le token
   curl -H "Authorization: Bearer YOUR_TOKEN" \
     https://staging.accessweaver.com/api/v1/users/me
   ```

3. **Swagger UI**
    - URL: https://staging.accessweaver.com/swagger-ui/index.html
    - Documentation interactive de l'API

## Pour les Testeurs QA

1. **Environnement de test**
    - Données de test pré-chargées
    - Reset quotidien à 2h du matin
    - Pas de données production

2. **Cas de tests recommandés**
    - Création de tenant
    - Gestion des rôles et permissions
    - Tests multi-tenant
    - Tests de performance basique

## Pour les Démos Client

1. **Compte de démonstration**
    - Tenant: "demo-company"
    - Admin: demo@accessweaver.com / DemoPass123!
    - URL: https://staging.accessweaver.com/demo

2. **Scénarios de démo préparés**
    - Gestion des employés et rôles
    - Contrôle d'accès aux documents
    - Audit trail et reporting
```

#### Checklist de Déploiement Staging

```markdown
# ✅ Checklist Déploiement Staging

## Pré-Déploiement
- [ ] Backup de la base de données actuelle
- [ ] Vérification des credentials AWS
- [ ] Validation du plan Terraform
- [ ] Notification équipe sur Slack #deployments

## Déploiement
- [ ] Déploiement infrastructure (Terraform)
- [ ] Vérification des services ECS
- [ ] Test de connectivité DB/Redis
- [ ] Validation SSL/DNS

## Post-Déploiement
- [ ] Tests de santé automatiques
- [ ] Validation des APIs principales
- [ ] Vérification monitoring/alerting
- [ ] Tests de performance basiques
- [ ] Documentation mise à jour

## Rollback (si problème)
- [ ] Identification du problème
- [ ] Décision rollback (Go/No-Go)
- [ ] Exécution rollback
- [ ] Validation post-rollback
- [ ] Post-mortem schedulé
```

### 📈 **Métriques et KPIs Staging**

#### KPIs Techniques

| Métrique | Cible Staging | Seuil Alerte | Fréquence |
|----------|---------------|--------------|-----------|
| **Disponibilité** | > 99.5% | < 99% | Temps réel |
| **Latence P99** | < 1000ms | > 1500ms | 5 minutes |
| **Taux d'erreur** | < 1% | > 2% | 5 minutes |
| **CPU moyen** | < 70% | > 85% | 15 minutes |
| **Mémoire moyenne** | < 80% | > 90% | 15 minutes |
| **DB Connections** | < 60 | > 80 | 15 minutes |
| **Cache Hit Ratio** | > 70% | < 60% | 15 minutes |

#### KPIs Business (Tests)

| Métrique | Cible | Mesure |
|----------|-------|--------|
| **Tests E2E passants** | > 95% | Quotidien |
| **Performance tests** | < 1s response | Hebdomadaire |
| **Démos client réussies** | 100% | Par démo |
| **Onboarding dev** | < 30min | Par nouveau dev |

---

## 🎯 Checklist de Validation Finale

### ✅ **Validation Technique**

```bash
#!/bin/bash
# final-staging-validation.sh

echo "🎯 FINAL STAGING VALIDATION CHECKLIST"
echo "======================================="

CHECKS_PASSED=0
TOTAL_CHECKS=15

# Check 1: Infrastructure déployée
echo "1. Checking infrastructure deployment..."
if terraform show | grep -q "accessweaver-staging"; then
  echo "✅ Infrastructure deployed"
  ((CHECKS_PASSED++))
else
  echo "❌ Infrastructure not found"
fi

# Check 2: Services ECS en cours d'exécution
echo "2. Checking ECS services..."
RUNNING_SERVICES=$(aws ecs list-services --cluster accessweaver-staging-cluster --query 'serviceArns' --output text | wc -w)
if [ "$RUNNING_SERVICES" -eq 5 ]; then
  echo "✅ All 5 ECS services running"
  ((CHECKS_PASSED++))
else
  echo "❌ Expected 5 services, found $RUNNING_SERVICES"
fi

# Check 3: Base de données accessible
echo "3. Checking database connectivity..."
DB_STATUS=$(aws rds describe-db-instances --db-instance-identifier accessweaver-staging-postgres --query 'DBInstances[0].DBInstanceStatus' --output text)
if [ "$DB_STATUS" = "available" ]; then
  echo "✅ Database available"
  ((CHECKS_PASSED++))
else
  echo "❌ Database status: $DB_STATUS"
fi

# Check 4: Redis accessible
echo "4. Checking Redis connectivity..."
REDIS_STATUS=$(aws elasticache describe-replication-groups --replication-group-id accessweaver-staging-redis --query 'ReplicationGroups[0].Status' --output text)
if [ "$REDIS_STATUS" = "available" ]; then
  echo "✅ Redis available"
  ((CHECKS_PASSED++))
else
  echo "❌ Redis status: $REDIS_STATUS"
fi

# Check 5: DNS résolution
echo "5. Checking DNS resolution..."
if nslookup staging.accessweaver.com | grep -q "address"; then
  echo "✅ DNS resolving correctly"
  ((CHECKS_PASSED++))
else
  echo "❌ DNS resolution failed"
fi

# Check 6: SSL certificat valide
echo "6. Checking SSL certificate..."
if echo | openssl s_client -connect staging.accessweaver.com:443 -servername staging.accessweaver.com 2>/dev/null | grep -q "Verify return code: 0"; then
  echo "✅ SSL certificate valid"
  ((CHECKS_PASSED++))
else
  echo "❌ SSL certificate invalid"
fi

# Check 7: Health check principal
echo "7. Checking main health endpoint..."
if curl -f -s https://staging.accessweaver.com/actuator/health | grep -q '"status":.*"UP"'; then
  echo "✅ Main health check passing"
  ((CHECKS_PASSED++))
else
  echo "❌ Main health check failing"
fi

# Check 8: API Gateway responsive
echo "8. Checking API Gateway..."
if curl -f -s https://staging.accessweaver.com/actuator/info | grep -q '"name"'; then
  echo "✅ API Gateway responsive"
  ((CHECKS_PASSED++))
else
  echo "❌ API Gateway not responding"
fi

# Check 9: Swagger UI accessible
echo "9. Checking Swagger UI..."
if curl -I -s https://staging.accessweaver.com/swagger-ui/index.html | grep -q "200 OK"; then
  echo "✅ Swagger UI accessible"
  ((CHECKS_PASSED++))
else
  echo "❌ Swagger UI not accessible"
fi

# Check 10: Monitoring configuré
echo "10. Checking CloudWatch alarms..."
ALARMS=$(aws cloudwatch describe-alarms --alarm-name-prefix "accessweaver-staging" --query 'MetricAlarms' --output text | wc -l)
if [ "$ALARMS" -gt 5 ]; then
  echo "✅ CloudWatch alarms configured ($ALARMS alarms)"
  ((CHECKS_PASSED++))
else
  echo "❌ Insufficient CloudWatch alarms ($ALARMS found)"
fi

# Check 11: WAF activé
echo "11. Checking WAF configuration..."
if aws wafv2 list-web-acls --scope REGIONAL --query 'WebACLs[?Name==`accessweaver-staging-waf`]' --output text | grep -q "accessweaver-staging-waf"; then
  echo "✅ WAF configured"
  ((CHECKS_PASSED++))
else
  echo "❌ WAF not found"
fi

# Check 12: Backup configuré
echo "12. Checking backup configuration..."
BACKUP_RETENTION=$(aws rds describe-db-instances --db-instance-identifier accessweaver-staging-postgres --query 'DBInstances[0].BackupRetentionPeriod' --output text)
if [ "$BACKUP_RETENTION" -gt 0 ]; then
  echo "✅ Database backups configured ($BACKUP_RETENTION days)"
  ((CHECKS_PASSED++))
else
  echo "❌ Database backups not configured"
fi

# Check 13: Multi-AZ activé
echo "13. Checking Multi-AZ deployment..."
MULTI_AZ=$(aws rds describe-db-instances --db-instance-identifier accessweaver-staging-postgres --query 'DBInstances[0].MultiAZ' --output text)
if [ "$MULTI_AZ" = "True" ]; then
  echo "✅ Multi-AZ enabled"
  ((CHECKS_PASSED++))
else
  echo "❌ Multi-AZ not enabled"
fi

# Check 14: Encryption activé
echo "14. Checking encryption..."
DB_ENCRYPTED=$(aws rds describe-db-instances --db-instance-identifier accessweaver-staging-postgres --query 'DBInstances[0].StorageEncrypted' --output text)
if [ "$DB_ENCRYPTED" = "True" ]; then
  echo "✅ Database encryption enabled"
  ((CHECKS_PASSED++))
else
  echo "❌ Database encryption not enabled"
fi

# Check 15: Performance baseline
echo "15. Checking performance baseline..."
RESPONSE_TIME=$(curl -w "%{time_total}" -o /dev/null -s https://staging.accessweaver.com/actuator/health)
if (( $(echo "$RESPONSE_TIME < 1.0" | bc -l) )); then
  echo "✅ Performance baseline met (${RESPONSE_TIME}s)"
  ((CHECKS_PASSED++))
else
  echo "❌ Performance baseline not met (${RESPONSE_TIME}s)"
fi

echo "======================================="
echo "VALIDATION SUMMARY: $CHECKS_PASSED/$TOTAL_CHECKS checks passed"

if [ "$CHECKS_PASSED" -eq "$TOTAL_CHECKS" ]; then
  echo "🎉 STAGING ENVIRONMENT FULLY VALIDATED!"
  echo "✅ Ready for testing and demonstrations"
  exit 0
else
  echo "⚠️  Some checks failed - please review before using staging"
  exit 1
fi
```

### 📋 **Validation Business**

#### Critères d'Acceptation Staging

- [ ] **Fonctionnalités complètes** : Toutes les fonctionnalités production disponibles
- [ ] **Performance acceptable** : Réponse < 1s pour 95% des requêtes
- [ ] **Haute disponibilité** : Multi-AZ configuré et testé
- [ ] **Sécurité** : HTTPS, WAF, chiffrement, secrets management
- [ ] **Monitoring** : Alertes configurées et testées
- [ ] **Coûts maîtrisés** : Budget < $350/mois
- [ ] **Documentation** : Procédures et runbooks à jour
- [ ] **Tests automatisés** : Pipeline de validation fonctionnel

---

## 🎉 Conclusion

L'environnement **staging AccessWeaver** est maintenant **complètement configuré et opérationnel** !

### 🏆 **Ce qui a été accompli :**

✅ **Architecture production-like** avec Multi-AZ et haute disponibilité  
✅ **Budget optimisé** à ~$300/mois (75% d'économies vs production)  
✅ **Sécurité enterprise** avec WAF, SSL/TLS et chiffrement  
✅ **Monitoring complet** avec alertes et dashboards  
✅ **Procédures opérationnelles** documentées et testées  
✅ **Tests automatisés** et validation continue

### 🚀 **Prochaines étapes recommandées :**

1. **Configurer les pipelines CI/CD** → `docs/deployment/cicd.md`
2. **Implémenter les tests d'infrastructure** → `docs/deployment/testing.md`
3. **Définir les stratégies de déploiement** → `docs/deployment/strategies.md`
4. **Former l'équipe** sur les procédures staging
5. **Programmer les tests de charge** hebdomadaires

### 🎯 **URLs et Accès Staging :**

- **Interface Web** : https://staging.accessweaver.com
- **API Documentation** : https://staging.accessweaver.com/swagger-ui/
- **Health Check** : https://staging.accessweaver.com/actuator/health
- **CloudWatch Dashboard** : [Lien AWS Console]

**L'environnement staging est prêt pour vos tests, démonstrations et validations ! 🎭✨**audit-service"
)

for SERVICE in "${SERVICES[@]}"; do
echo "📦 Updating $SERVICE to version $VERSION..."

# Obtenir la task definition actuelle
TASK_DEF=$(aws ecs describe-services --cluster $CLUSTER --services $SERVICE \
--query 'services[0].taskDefinition' --output text)

# Créer nouvelle task definition avec nouvelle image
# (Ici on simule - dans la vraie vie utiliser un script plus sophistiqué)
aws ecs update-service \
--cluster $CLUSTER \
--service $SERVICE \
--force-new-deployment

echo "⏳ Waiting for $SERVICE to stabilize..."
aws ecs wait services-stable --cluster $CLUSTER --services $SERVICE
echo "✅ $SERVICE updated successfully"
done

echo "🎉 Deployment completed!"

# Vérification post-déploiement
echo "🔍 Running post-deployment checks..."
curl -f https://staging.accessweaver.com/actuator/health
echo "✅ Health check passed after deployment"
```

#### Rotation des Secrets

```bash
#!/bin/bash
# rotate-secrets-staging.sh

echo "🔐 Rotating secrets for staging environment..."

# Rotation password database
NEW_DB_PASSWORD=$(openssl rand -base64 32)
aws secretsmanager update-secret \
  --secret-id accessweaver/staging/database \
  --secret-string "{\"password\":\"$NEW_DB_PASSWORD\"}"

# Rotation Redis auth token
NEW_REDIS_TOKEN=$(openssl rand -base64 32)
aws secretsmanager update-secret \
  --secret-id accessweaver/staging/redis \
  --secret-string "{\"auth_token\":\"$NEW_REDIS_TOKEN\"}"

# Redémarrer les services pour prendre en compte les nouveaux secrets
aws ecs update-service \
  --cluster accessweaver-staging-cluster \
  --service accessweaver-staging-aw-api-gateway \
  --force-new-deployment

echo "✅ Secrets rotated successfully"
```

### 📊 **Optimisation des Coûts**

#### Arrêt Automatique Hors Heures de Bureau

```bash
# Cron job pour arrêter staging le soir (20h)
# 0 20 * * 1-5 /usr/local/bin/stop-staging.sh

#!/bin/bash
# stop-staging.sh - Arrêt automatique staging

echo "🌙 Stopping staging environment for the night..."

# Réduire les services ECS à 0
SERVICES=(
  "accessweaver-staging-aw-api-gateway"
  "accessweaver-staging-aw-pdp-service"  
  "accessweaver-staging-aw-pap-service"
  "accessweaver-staging-aw-tenant-service"
  "accessweaver-staging-