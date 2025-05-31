# 🚀 Quick Start Guide - AccessWeaver Infrastructure

Déployez AccessWeaver sur AWS en 30 minutes avec ce guide pas à pas.

## 📋 Prérequis (5 minutes)

### 1. Outils Requis

```bash
# Vérifier les versions minimales
terraform --version  # >= 1.0
aws --version        # >= 2.0
git --version        # >= 2.0
```

### 2. Installation si Nécessaire

```bash
# macOS (Homebrew)
brew install terraform awscli git

# Ubuntu/Debian
sudo apt update
sudo apt install terraform awscli git

# Windows (Chocolatey)
choco install terraform awscli git
```

### 3. Compte AWS
- Compte AWS actif avec carte de crédit
- Utilisateur IAM avec permissions AdministratorAccess
- Access Key + Secret Key configurés

## ⚙️ Configuration Initiale (10 minutes)

### 1. Clone du Repository

```bash
git clone https://github.com/your-org/aw-infrastructure-as-code.git
cd aw-infrastructure-as-code
```

### 2. Configuration AWS

```bash
# Configuration interactive
aws configure

# Ou export des variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="eu-west-1"
```

### 3. Vérification des Permissions

```bash
# Test des permissions AWS
aws sts get-caller-identity
aws ec2 describe-regions --region eu-west-1
```

## 🏗 Déploiement Développement (15 minutes)

### 1. Préparation de l'Environnement

```bash
# Aller dans l'environnement dev
cd environments/dev

# Copier le fichier de variables
cp terraform.tfvars.example terraform.tfvars
```

### 2. Configuration des Variables

Éditer `terraform.tfvars` :

```hcl
# environments/dev/terraform.tfvars

# Configuration projet
project_name = "accessweaver"
environment  = "dev"
region      = "eu-west-1"

# Réseau (ajuster selon vos besoins)
vpc_cidr = "10.0.0.0/16"

# Base de données (dev = configuration économique)
db_instance_class = "db.t3.micro"
db_allocated_storage = 20

# Cache Redis (dev = single node)
redis_node_type = "cache.t3.micro"
redis_num_cache_clusters = 1

# ECS (dev = ressources minimales)
ecs_cpu_units = 256
ecs_memory_mb = 512

# Domaine (optionnel pour dev)
# custom_domain = "dev.your-domain.com"
# route53_zone_id = "Z1234567890ABCDEF"

# Container registry (adapter à votre registry)
container_registry = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/accessweaver"
image_tag = "latest"

# Tags pour identification des coûts
additional_tags = {
  Environment = "development"
  Project     = "accessweaver"
  Owner       = "your-team"
  CostCenter  = "engineering"
}
```

### 3. Initialisation Terraform

```bash
# Initialiser le backend et providers
terraform init

# Vérifier la configuration
terraform validate

# Planifier les changements
terraform plan
```

### 4. Déploiement

```bash
# Appliquer la configuration (attention aux coûts !)
terraform apply

# Confirmer avec 'yes' quand demandé
```

⏱️ **Temps d'attente :** 10-15 minutes pour le déploiement complet.

### 5. Vérification du Déploiement

```bash
# Récupérer les outputs importants
terraform output alb_dns_name
terraform output api_base_url
terraform output health_check_url

# Test de connectivité
curl -f $(terraform output -raw health_check_url)
```

## ✅ Validation du Déploiement

### 1. Services ECS

```bash
# Vérifier le cluster ECS
aws ecs describe-clusters --clusters accessweaver-dev-cluster

# Vérifier les services
aws ecs list-services --cluster accessweaver-dev-cluster

# Vérifier les tâches actives
aws ecs list-tasks --cluster accessweaver-dev-cluster
```

### 2. Base de Données

```bash
# Vérifier l'instance RDS
aws rds describe-db-instances --db-instance-identifier accessweaver-dev-postgres

# Test de connectivité (depuis une instance ECS)
# psql -h ENDPOINT -U postgres -d accessweaver
```

### 3. Cache Redis

```bash
# Vérifier le cluster Redis
aws elasticache describe-replication-groups --replication-group-id accessweaver-dev-redis

# Test de connectivité (depuis une instance ECS)
# redis-cli -h ENDPOINT -p 6379 ping
```

### 4. Load Balancer

```bash
# Vérifier l'ALB
aws elbv2 describe-load-balancers --names accessweaver-dev-alb

# Test des endpoints
curl -f https://your-alb-dns/actuator/health
curl -f https://your-alb-dns/api/v1/health
```

## 🧪 Tests Fonctionnels

### 1. Health Checks

```bash
# API Gateway health
curl -f $(terraform output -raw public_url)/actuator/health

# Response attendue:
# {"status":"UP","components":{"db":{"status":"UP"},"redis":{"status":"UP"}}}
```

### 2. API Documentation

```bash
# Swagger UI (si activé)
open $(terraform output -raw public_url)/swagger-ui/index.html

# OpenAPI spec
curl $(terraform output -raw public_url)/v3/api-docs
```

### 3. Test d'Autorisation

```bash
# Test de base (nécessite configuration supplémentaire)
curl -X POST $(terraform output -raw api_base_url)/check \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "user": "test-user",
    "action": "read", 
    "resource": "document"
  }'
```

## 📊 Monitoring de Base

### 1. CloudWatch Dashboards

```bash
# URL du dashboard (remplacer REGION et ACCOUNT)
echo "https://console.aws.amazon.com/cloudwatch/home?region=eu-west-1#dashboards:"
```

### 2. Métriques Importantes

```bash
# CPU ECS
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --start-time $(date -d '1 hour ago' --iso-8601) \
  --end-time $(date --iso-8601) \
  --period 300 \
  --statistics Average

# Response time ALB
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --start-time $(date -d '1 hour ago' --iso-8601) \
  --end-time $(date --iso-8601) \
  --period 300 \
  --statistics Average
```

## 💰 Contrôle des Coûts

### 1. Vérification des Coûts

```bash
# Coûts des derniers 30 jours
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

### 2. Configuration d'Alertes Budget

```bash
# Créer un budget de 200€/mois
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget '{
    "BudgetName": "AccessWeaver-Dev-Budget",
    "BudgetLimit": {
      "Amount": "200",
      "Unit": "EUR"
    },
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }'
```

## 🔧 Configuration Avancée (Optionnelle)

### 1. Domaine Personnalisé

```hcl
# Ajouter dans terraform.tfvars
custom_domain = "dev.accessweaver.com"
route53_zone_id = "Z1234567890ABCDEF"
```

### 2. Monitoring Enhanced

```hcl
# Activer Container Insights
container_insights_enabled = true
enable_access_logs = true
```

### 3. Secrets Management

```bash
# Créer les secrets requis
aws secretsmanager create-secret \
  --name "accessweaver/dev/database" \
  --description "Database credentials for AccessWeaver dev" \
  --secret-string '{"password":"your-secure-password"}'

aws secretsmanager create-secret \
  --name "accessweaver/dev/redis" \
  --description "Redis auth token for AccessWeaver dev" \
  --secret-string '{"auth_token":"your-redis-token"}'
```

## ⚠️ Troubleshooting Rapide

### Problème : Terraform init échoue
```bash
# Vérifier les permissions AWS
aws sts get-caller-identity

# Réinitialiser Terraform
rm -rf .terraform .terraform.lock.hcl
terraform init
```

### Problème : Services ECS ne démarrent pas
```bash
# Vérifier les logs
aws logs tail /ecs/accessweaver-dev/aw-api-gateway --follow

# Vérifier les images Docker
aws ecr describe-images --repository-name accessweaver/aw-api-gateway
```

### Problème : Health checks échouent
```bash
# Vérifier la connectivité interne
aws ecs execute-command \
  --cluster accessweaver-dev-cluster \
  --task TASK_ID \
  --container aw-api-gateway \
  --interactive \
  --command "curl localhost:8080/actuator/health"
```

## 🧹 Nettoyage (Destruction)

⚠️ **ATTENTION** : Ceci supprimera toute l'infrastructure !

```bash
# Sauvegarder les données importantes avant destruction
aws rds create-db-snapshot \
  --db-instance-identifier accessweaver-dev-postgres \
  --db-snapshot-identifier accessweaver-dev-backup-$(date +%Y%m%d)

# Destruction de l'infrastructure
terraform destroy

# Confirmer avec 'yes'
```

## 📞 Support

### En cas de problème :

1. **Vérifier les logs** : `aws logs tail /ecs/accessweaver-dev/aw-api-gateway --follow`
2. **Consulter la documentation** : [Troubleshooting Guide](./operations/troubleshooting.md)
3. **Contacter l'équipe** : platform@accessweaver.com

### Ressources utiles :

- [Architecture Overview](./architecture/overview.md)
- [Configuration Guide](./configuration/terraform.md)
- [Security Best Practices](./security/best-practices.md)

---

🎉 **Félicitations !** Vous avez déployé AccessWeaver sur AWS. Prochaine étape : [Configuration Production](./deployment/production.md)