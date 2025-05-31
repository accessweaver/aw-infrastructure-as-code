# 🚀 First Deployment Guide - AccessWeaver Infrastructure

Guide complet pour votre premier déploiement AccessWeaver sur AWS - De zéro à production en 60 minutes.

---

## 📋 Table des Matières

- [Vue d'Ensemble](#vue-densemble)
- [Pré-Requis](#pré-requis)
- [Phase 1: Setup Initial](#phase-1-setup-initial)
- [Phase 2: Déploiement Development](#phase-2-déploiement-development)
- [Phase 3: Validation et Tests](#phase-3-validation-et-tests)
- [Phase 4: Préparation Production](#phase-4-préparation-production)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Vue d'Ensemble

### **Objectif**
Déployer AccessWeaver de A à Z avec une approche progressive :
1. **Development** (15 min) - Validation de l'architecture
2. **Staging** (20 min) - Tests complets
3. **Production** (25 min) - Déploiement sécurisé

### **Timeline Complète**
```
🕐 T+00:00 - Setup initial (repositories, secrets)
🕐 T+15:00 - Dev environment opérationnel
🕐 T+35:00 - Staging environment + tests
🕐 T+60:00 - Production ready + monitoring
```

### **Résultats Attendus**
- ✅ Infrastructure complète sur AWS
- ✅ 5 microservices déployés et fonctionnels
- ✅ Base de données PostgreSQL avec multi-tenancy
- ✅ Cache Redis haute performance
- ✅ Monitoring et alerting configurés
- ✅ SSL/TLS et sécurité enterprise

---

## ✅ Pré-Requis

### **Vérification Rapide**
```bash
# Vérifier que tout est prêt (5 minutes max)
./scripts/check-prerequisites.sh

# Doit afficher:
# ✅ Terraform: 1.6.0+
# ✅ AWS CLI: 2.0.0+
# ✅ Git: 2.0.0+
# ✅ AWS Access: Confirmed
# ✅ Permissions: Administrator
# 🎉 Ready to deploy!
```

### **Si des problèmes sont détectés**
Consultez le [Prerequisites & Setup Guide](./prerequisites.md) avant de continuer.

---

## 🏗 Phase 1: Setup Initial (10 minutes)

### **1.1 - Clone du Repository Principal**

```bash
# Cloner le repository infrastructure
git clone https://github.com/your-org/aw-infrastructure-as-code.git
cd aw-infrastructure-as-code

# Vérifier la structure
tree -L 2
```

**Structure attendue :**
```
aw-infrastructure-as-code/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── modules/
│   ├── vpc/, rds/, ecs/, redis/, alb/
├── scripts/
├── docs/
└── README.md
```

### **1.2 - Configuration AWS Profile**

```bash
# Configurer le profil AWS pour AccessWeaver
aws configure --profile accessweaver
# AWS Access Key ID: AKIAXXXXXXXXXXXXX
# AWS Secret Access Key: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# Default region: eu-west-1
# Default output format: json

# Tester la connectivité
export AWS_PROFILE=accessweaver
aws sts get-caller-identity

# Résultat attendu:
# {
#   "UserId": "AIDACKCEVSQ6C2EXAMPLE",
#   "Account": "123456789012", 
#   "Arn": "arn:aws:iam::123456789012:user/terraform-accessweaver"
# }
```

### **1.3 - Setup des Backends Terraform**

```bash
# Créer les backends S3/DynamoDB pour chaque environnement
./scripts/setup-backend.sh dev eu-west-1
./scripts/setup-backend.sh staging eu-west-1  
./scripts/setup-backend.sh prod eu-west-1

# Vérifier la création
aws s3 ls | grep accessweaver-terraform-state
aws dynamodb list-tables | grep accessweaver-terraform-locks
```

### **1.4 - Configuration Initiale des Secrets**

```bash
# Générer les secrets pour tous les environnements
./scripts/setup-secrets.sh dev
./scripts/setup-secrets.sh staging
./scripts/setup-secrets.sh prod

# Vérifier la création
aws secretsmanager list-secrets --query 'SecretList[?contains(Name, `accessweaver`)].Name'
```

---

## 🛠 Phase 2: Déploiement Development (15 minutes)

### **2.1 - Configuration Environment Dev**

```bash
# Aller dans l'environnement dev
cd environments/dev

# Copier et personnaliser les variables
cp terraform.tfvars.example terraform.tfvars
```

### **2.2 - Personnalisation des Variables Dev**

Éditer `terraform.tfvars` avec vos valeurs :

```hcl
# ============================================================================
# VOTRE CONFIGURATION DEVELOPMENT
# ============================================================================

# Identité projet - MODIFIER SELON VOS BESOINS
project_name = "accessweaver"          # Votre nom de projet
environment  = "dev"
region      = "eu-west-1"              # Votre région préférée

# Domaine - MODIFIER AVEC VOTRE DOMAINE
custom_domain   = "dev.votre-domaine.com"    # Votre sous-domaine dev
route53_zone_id = "Z1234567890ABCDEF012345"  # Votre Zone ID Route 53

# Container Registry - MODIFIER AVEC VOTRE ACCOUNT ID
container_registry = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/accessweaver"
# Remplacer 123456789012 par votre Account ID AWS

# Autres paramètres (garder tel quel pour dev)
vpc_cidr = "10.0.0.0/16"
db_instance_class = "db.t3.micro"
redis_node_type = "cache.t3.micro"
enable_waf = false

# Tags personnalisés
additional_tags = {
  Environment = "development"
  Project     = "accessweaver"
  Owner       = "votre-nom"              # MODIFIER
  Team        = "votre-equipe"           # MODIFIER
}
```

### **2.3 - Premier Déploiement Dev**

```bash
# Initialiser Terraform
terraform init

# Vérifier la configuration
terraform validate
echo "✅ Configuration valide"

# Planifier le déploiement
terraform plan -out=dev.tfplan

# 🔍 IMPORTANT: Examiner le plan
# - Vérifier les ressources à créer (environ 50-60 ressources)
# - Confirmer les coûts estimés (~$95/mois)
# - S'assurer qu'aucune ressource critique n'est détruite

# Appliquer le déploiement
terraform apply dev.tfplan
```

**⏱️ Temps d'attente :** 10-15 minutes pour le déploiement complet.

### **2.4 - Surveillance du Déploiement**

```bash
# Dans un autre terminal, surveiller les ressources
watch -n 30 'aws ecs list-services --cluster accessweaver-dev-cluster'

# Surveiller les logs si problème
aws logs tail /ecs/accessweaver-dev/aw-api-gateway --follow
```

### **2.5 - Récupération des Outputs**

```bash
# Une fois le déploiement terminé
terraform output

# Outputs importants:
# alb_dns_name = "accessweaver-dev-alb-123456789.eu-west-1.elb.amazonaws.com"
# api_base_url = "https://dev.votre-domaine.com"
# vpc_id = "vpc-12345678"
# database_endpoint = "accessweaver-dev-postgres.xyz.eu-west-1.rds.amazonaws.com"

# Sauvegarder les outputs
terraform output -json > ../dev-outputs.json
```

---

## ✅ Phase 3: Validation et Tests (10 minutes)

### **3.1 - Tests de Connectivité**

```bash
# Test 1: Health check ALB
ALB_DNS=$(terraform output -raw alb_dns_name)
curl -f "https://$ALB_DNS/actuator/health"

# Résultat attendu:
# {"status":"UP","components":{"db":{"status":"UP"},"redis":{"status":"UP"}}}

# Test 2: API Gateway via domaine custom
API_URL=$(terraform output -raw api_base_url)
curl -f "$API_URL/actuator/health"

# Test 3: Services ECS
aws ecs describe-services --cluster accessweaver-dev-cluster \
  --query 'services[*].[serviceName,status,runningCount,desiredCount]' \
  --output table
```

### **3.2 - Tests des Services**

```bash
# Test des microservices individuels
./scripts/test-services.sh dev

# Doit tester:
# ✅ API Gateway - Health check
# ✅ PDP Service - Decision endpoint  
# ✅ PAP Service - Policy management
# ✅ Tenant Service - Multi-tenancy
# ✅ Audit Service - Logging
```

### **3.3 - Test du Multi-Tenancy**

```bash
# Créer un tenant de test
TENANT_ID=$(uuidgen)
curl -X POST "$API_URL/api/v1/tenants" \
  -H "Content-Type: application/json" \
  -d "{\"id\":\"$TENANT_ID\",\"name\":\"Test Tenant\"}"

# Test isolation
curl -H "X-Tenant-ID: $TENANT_ID" "$API_URL/api/v1/users"
# Doit retourner une liste vide (tenant isolé)
```

### **3.4 - Test Base de Données**

```bash
# Vérifier la connectivité PostgreSQL
DB_ENDPOINT=$(terraform output -raw database_endpoint)

# Depuis une instance ECS (pour les tests internes)
aws ecs execute-command \
  --cluster accessweaver-dev-cluster \
  --task $(aws ecs list-tasks --cluster accessweaver-dev-cluster --query 'taskArns[0]' --output text) \
  --container aw-api-gateway \
  --interactive \
  --command "psql -h $DB_ENDPOINT -U postgres -d accessweaver -c 'SELECT version();'"
```

### **3.5 - Test Performance de Base**

```bash
# Test de charge léger (100 requêtes)
./scripts/load-test.sh dev 100

# Résultats attendus:
# - Latence moyenne < 50ms
# - Pas d'erreurs 5xx
# - CPU ECS < 30%
```

---

## 🎯 Phase 4: Préparation Production (15 minutes)

### **4.1 - Déploiement Staging**

```bash
# Passer à l'environnement staging
cd ../staging

# Copier et adapter la config dev
cp ../dev/terraform.tfvars terraform.tfvars
# Modifier les paramètres staging (cf. Environment Setup Guide)

# Déployer staging
terraform init
terraform plan -out=staging.tfplan
terraform apply staging.tfplan
```

### **4.2 - Tests Staging Complets**

```bash
# Tests d'intégration complets
./scripts/test-integration.sh staging

# Tests de performance
./scripts/test-performance.sh staging

# Tests de sécurité
./scripts/test-security.sh staging
```

### **4.3 - Configuration Production**

```bash
# Passer à l'environnement production
cd ../prod

# Copier template et personnaliser soigneusement
cp terraform.tfvars.example terraform.tfvars
```

**Configuration Production (terraform.tfvars) :**
```hcl
# ============================================================================
# PRODUCTION CONFIGURATION - ATTENTION AUX COÛTS (~$900/mois)
# ============================================================================

# Identité projet
project_name = "accessweaver"
environment  = "prod"
region      = "eu-west-1"

# Domaine production - CRITICAL
custom_domain   = "accessweaver.com"           # Domaine principal
route53_zone_id = "Z1234567890ABCDEF012345"    # VOTRE Zone ID

# Container Registry
container_registry = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/accessweaver"
image_tag         = "v1.0.0"                   # Version stable, PAS latest

# Infrastructure haute performance
vpc_cidr = "10.2.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

# Base de données - Performance optimisée
db_instance_class           = "db.r6g.xlarge"  # Memory optimized
db_allocated_storage       = 200
db_max_allocated_storage   = 1000
db_backup_retention_period = 30                # Compliance
db_multi_az               = true               # HA obligatoire
db_deletion_protection    = true               # Protection suppression

# Redis cluster haute performance
redis_node_type                = "cache.r6g.large"
redis_num_node_groups         = 3              # 3 shards
redis_replicas_per_node_group = 2              # 2 replicas per shard
redis_at_rest_encryption      = true
redis_transit_encryption      = true

# ECS - Configuration robuste
ecs_services = {
  api-gateway = {
    cpu           = 1024
    memory        = 2048
    desired_count = 3                           # HA minimum
    max_capacity  = 10
  }
  pdp-service = {
    cpu           = 2048                        # Critical service
    memory        = 4096
    desired_count = 3
    max_capacity  = 15
  }
  # ... autres services
}

# Sécurité maximale
enable_waf               = true
waf_rate_limit          = 1000
ssl_policy              = "ELBSecurityPolicy-TLS-1-3-2021-06"
enable_deletion_protection = true

# Monitoring enhanced
enable_container_insights    = true
enable_access_logs          = true
enable_xray_tracing         = true
sns_topic_arn              = "arn:aws:sns:eu-west-1:123456789012:accessweaver-prod-alerts"

# Tags production
additional_tags = {
  Environment     = "production"
  Project         = "accessweaver"
  Owner          = "platform-team"
  CostCenter     = "product"
  BusinessUnit   = "saas"
  Compliance     = "GDPR,SOC2"
  Support        = "24x7"
  SLA            = "99.95%"
}
```

### **4.4 - Déploiement Production (Avec Précautions)**

```bash
# ⚠️ ATTENTION: Déploiement production - DOUBLE VÉRIFICATION

# 1. Vérification finale des coûts
terraform plan -out=prod.tfplan
# 📊 Examiner attentivement les ressources et coûts estimés

# 2. Validation avec l'équipe
echo "🔍 Plan production généré. REVIEW OBLIGATOIRE avant apply!"
echo "💰 Coût estimé: ~900€/mois"
echo "📋 Ressources créées: ~80 ressources AWS"
echo ""
read -p "✅ Plan validé par l'équipe ? (yes/no): " confirm

if [ "$confirm" = "yes" ]; then
    echo "🚀 Déploiement production en cours..."
    terraform apply prod.tfplan
else
    echo "❌ Déploiement annulé. Revoir le plan."
    exit 1
fi
```

### **4.5 - Configuration Post-Déploiement Production**

```bash
# Configuration DNS (si Route 53 externe)
PROD_ALB_DNS=$(terraform output -raw alb_dns_name)
echo "🌐 Configurer votre DNS:"
echo "   accessweaver.com CNAME $PROD_ALB_DNS"
echo "   api.accessweaver.com CNAME $PROD_ALB_DNS"
echo "   admin.accessweaver.com CNAME $PROD_ALB_DNS"

# Attendre propagation DNS (2-5 minutes)
echo "⏳ Attendre propagation DNS..."
while ! nslookup accessweaver.com | grep -q "$PROD_ALB_DNS"; do
    echo "   DNS pas encore propagé, attente 30s..."
    sleep 30
done
echo "✅ DNS propagé avec succès"
```

---

## 🎉 Validation Finale du Déploiement

### **5.1 - Tests de Validation Production**

```bash
# Test complet de l'infrastructure
./scripts/validate-production.sh

# Checklist automatique:
# ✅ Health checks tous services
# ✅ SSL/TLS correctement configuré
# ✅ WAF actif et configuré
# ✅ Monitoring opérationnel
# ✅ Base de données accessible
# ✅ Cache Redis fonctionnel
# ✅ Auto-scaling configuré
# ✅ Backups programmés
```

### **5.2 - Test End-to-End Production**

```bash
# Test du workflow complet d'autorisation
API_URL="https://accessweaver.com"

# 1. Créer un tenant
TENANT_ID=$(uuidgen)
curl -X POST "$API_URL/api/v1/tenants" \
  -H "Content-Type: application/json" \
  -d "{\"id\":\"$TENANT_ID\",\"name\":\"Production Test Tenant\"}"

# 2. Créer un utilisateur
USER_ID=$(uuidgen) 
curl -X POST "$API_URL/api/v1/users" \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: $TENANT_ID" \
  -d "{\"id\":\"$USER_ID\",\"email\":\"test@accessweaver.com\"}"

# 3. Créer un rôle
ROLE_ID=$(uuidgen)
curl -X POST "$API_URL/api/v1/roles" \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: $TENANT_ID" \
  -d "{\"id\":\"$ROLE_ID\",\"name\":\"viewer\",\"permissions\":[\"document:read\"]}"

# 4. Assigner le rôle
curl -X POST "$API_URL/api/v1/users/$USER_ID/roles" \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: $TENANT_ID" \
  -d "{\"roleId\":\"$ROLE_ID\"}"

# 5. Test d'autorisation
curl -X POST "$API_URL/api/v1/check" \
  -H "Content-Type: application/json" \
  -H "X-Tenant-ID: $TENANT_ID" \
  -d "{
    \"user\":\"$USER_ID\",
    \"action\":\"read\",
    \"resource\":{\"type\":\"document\",\"id\":\"doc123\"}
  }"

# Résultat attendu: {"allowed":true,"reason":"user has viewer role"}
```

### **5.3 - Test de Performance Production**

```bash
# Test de charge avec 1000 requêtes parallèles
./scripts/load-test.sh prod 1000

# Métriques attendues:
# 📊 Latence p99 < 10ms
# 📊 Latence p50 < 5ms  
# 📊 Error rate < 0.1%
# 📊 Throughput > 500 rps
# 📊 CPU utilization < 70%
```

### **5.4 - Configuration Monitoring**

```bash
# Créer dashboard CloudWatch principal
aws cloudwatch put-dashboard \
  --dashboard-name "AccessWeaver-Production" \
  --dashboard-body file://scripts/dashboard-config.json

# Configurer alertes critiques
./scripts/setup-production-alerts.sh

# Configurer notifications Slack/Teams (optionnel)
aws sns subscribe \
  --topic-arn arn:aws:sns:eu-west-1:123456789012:accessweaver-prod-alerts \
  --protocol https \
  --notification-endpoint https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
```

---

## 📊 Récapitulatif du Déploiement

### **Infrastructure Déployée**

| Composant | Development | Staging | Production |
|-----------|-------------|---------|------------|
| **🏗 Compute** | 5 services ECS | 5 services ECS | 5 services ECS |
| **💾 Database** | PostgreSQL t3.micro | PostgreSQL t3.small | PostgreSQL r6g.xlarge |
| **⚡ Cache** | Redis t3.micro (1 node) | Redis t3.small (2 nodes) | Redis r6g.large (3 shards) |
| **🌐 Load Balancer** | ALB standard | ALB + WAF | ALB + WAF + SSL strict |
| **🔐 Security** | Basic | Production-like | Maximum |
| **📊 Monitoring** | Basic CloudWatch | Full monitoring | Enhanced + alerts |

### **URLs et Endpoints**

```bash
# Development
Dev API: https://dev.votre-domaine.com
Dev Admin: https://dev.votre-domaine.com/admin
Dev Health: https://dev.votre-domaine.com/actuator/health

# Staging  
Staging API: https://staging.votre-domaine.com
Staging Admin: https://staging.votre-domaine.com/admin

# Production
Prod API: https://accessweaver.com
Prod Admin: https://admin.accessweaver.com
Prod API Docs: https://api.accessweaver.com/swagger-ui/
```

### **Coûts Mensuels Estimés**

| Environnement | Coût/Mois | Services Principaux |
|---------------|-----------|-------------------|
| **Development** | ~$95 | ECS micro, RDS micro, Redis micro |
| **Staging** | ~$300 | ECS small, RDS small, Redis cluster |
| **Production** | ~$900 | ECS optimized, RDS xlarge, Redis HA |
| **TOTAL** | **~$1295** | Infrastructure complète |

---

## 🚨 Troubleshooting

### **Problème 1: Déploiement Terraform Échoue**

#### **Symptôme**
```
Error: creating ECS Service: InvalidParameterException
```

#### **Solution**
```bash
# 1. Vérifier les quotas AWS
aws service-quotas get-service-quota --service-code ecs --quota-code L-34B43A08

# 2. Vérifier les images Docker
aws ecr describe-images --repository-name accessweaver/aw-api-gateway

# 3. Nettoyer et relancer
terraform destroy -target=aws_ecs_service.api_gateway
terraform apply
```

### **Problème 2: Services ECS ne Démarrent Pas**

#### **Symptôme**
```bash
aws ecs describe-services --cluster accessweaver-dev-cluster
# runningCount: 0, desiredCount: 1
```

#### **Solution**
```bash
# 1. Vérifier les logs ECS
aws logs tail /ecs/accessweaver-dev/aw-api-gateway --follow

# 2. Vérifier les task definitions
aws ecs describe-task-definition --task-definition accessweaver-dev-api-gateway

# 3. Problème commun: Mémoire insuffisante
# Augmenter la mémoire dans terraform.tfvars:
# memory = 1024 # au lieu de 512
```

### **Problème 3: Health Checks Échouent**

#### **Symptôme**
```bash
curl https://dev.votre-domaine.com/actuator/health
# Connection refused ou timeout
```

#### **Solution**
```bash
# 1. Vérifier ALB Target Groups
aws elbv2 describe-target-health --target-group-arn "arn:aws:elasticloadbalancing:..."

# 2. Vérifier Security Groups
aws ec2 describe-security-groups --filters "Name=tag:Environment,Values=dev"

# 3. Test connectivité interne
aws ecs execute-command --cluster accessweaver-dev-cluster \
  --task TASK_ID --container aw-api-gateway \
  --interactive --command "curl localhost:8080/actuator/health"
```

### **Problème 4: Base de Données Inaccessible**

#### **Symptôme**
```
Connection to database failed: timeout
```

#### **Solution**
```bash
# 1. Vérifier RDS status
aws rds describe-db-instances --db-instance-identifier accessweaver-dev-postgres

# 2. Vérifier security groups RDS
aws ec2 describe-security-groups --filters "Name=tag:Name,Values=*rds*"

# 3. Test depuis ECS task
aws ecs execute-command --cluster accessweaver-dev-cluster \
  --task TASK_ID --container aw-api-gateway \
  --interactive --command "telnet RDS_ENDPOINT 5432"
```

### **Problème 5: Coûts Inattendus**

#### **Symptôme**
Facturation AWS plus élevée que prévu

#### **Solution**
```bash
# 1. Analyser les coûts
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# 2. Identifier ressources coûteuses
aws ce get-dimension-values \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --dimension SERVICE \
  --context COST_AND_USAGE

# 3. Actions correctives:
# - Arrêter dev/staging hors heures: make stop ENV=dev
# - Utiliser Reserved Instances pour production
# - Optimiser tailles d'instances
```

---

## ✅ Checklist Post-Déploiement

### **Sécurité**
- [ ] Certificats SSL configurés et valides
- [ ] WAF activé en staging/production
- [ ] Security Groups restrictifs
- [ ] Secrets dans AWS Secrets Manager
- [ ] IAM roles avec principe du moindre privilège
- [ ] Audit logging activé

### **Performance**
- [ ] Cache Redis opérationnel
- [ ] Auto-scaling configuré
- [ ] Health checks optimisés
- [ ] Latence < 10ms en production
- [ ] Base de données optimisée

### **Monitoring**
- [ ] CloudWatch dashboards créés
- [ ] Alertes critiques configurées
- [ ] Logs centralisés et accessibles
- [ ] X-Ray tracing activé
- [ ] Notifications configurées

### **Opérations**
- [ ] Backups automatiques configurés
- [ ] Documentation à jour
- [ ] Runbooks créés
- [ ] Équipe formée
- [ ] Contacts d'urgence définis

---

## 🎉 Félicitations !

**Votre infrastructure AccessWeaver est maintenant déployée et opérationnelle !**

### **Prochaines Étapes Recommandées**

1. **[Monitoring Setup](./monitoring/setup.md)** - Configuration monitoring avancé
2. **[Security Hardening](./security/best-practices.md)** - Renforcement sécurité
3. **[Performance Tuning](./performance/tuning.md)** - Optimisation performances
4. **[Operational Runbooks](./operations/daily.md)** - Procédures opérationnelles

### **Support et Ressources**

- **📚 Documentation complète:** [docs/README.md](./README.md)
- **🐛 Issues GitHub:** [Repository Issues](https://github.com/your-org/aw-infrastructure-as-code/issues)
- **💬 Support équipe:** platform@accessweaver.com
- **📞 Urgences production:** +33 X XX XX XX XX (24/7)

---

**🚀 AccessWeaver est maintenant prêt à autoriser vos applications !**