# 🔧 Terraform Configuration - AccessWeaver

Configuration complète de Terraform pour l'infrastructure AccessWeaver : variables, backend, providers et organisation du code.

---

## 🎯 Vue d'Ensemble

Ce document couvre la configuration de base de Terraform pour AccessWeaver, incluant l'organisation des fichiers, la configuration des providers AWS, et la gestion des variables par environnement.

### 📁 Structure de Configuration

```
aw-infrastructure-as-code/
├── environments/                   # Configuration par environnement
│   ├── dev/
│   │   ├── main.tf                # Configuration principale dev
│   │   ├── variables.tf           # Variables spécifiques dev
│   │   ├── terraform.tfvars       # Valeurs des variables (gitignored)
│   │   ├── terraform.tfvars.example # Template des variables
│   │   ├── backend.tf             # Configuration backend S3
│   │   └── outputs.tf             # Outputs pour dev
│   ├── staging/
│   └── prod/
├── modules/                        # Modules réutilisables
│   ├── vpc/
│   ├── rds/
│   ├── redis/
│   ├── ecs/
│   └── alb/
└── scripts/
    ├── setup-backend.sh           # Initialisation backend
    └── deploy.sh                  # Script de déploiement
```

---

## 🏗 Configuration Backend

### Backend S3 avec DynamoDB

AccessWeaver utilise un backend S3 distant pour partager l'état Terraform entre les équipes et environnements.

```hcl
# environments/dev/backend.tf
terraform {
  backend "s3" {
    bucket         = "accessweaver-terraform-state-dev-123456789012"
    key            = "dev/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "accessweaver-terraform-locks-dev"
    encrypt        = true

    # Sécurité et validation
    skip_region_validation      = false
    skip_credentials_validation = false
    skip_metadata_api_check     = false
    force_path_style           = false
  }
}
```

### Initialisation Automatique

```bash
# Script d'initialisation du backend
./scripts/setup-backend.sh dev eu-west-1

# Fonctionnalités du script :
# ✅ Création bucket S3 chiffré avec versioning
# ✅ Table DynamoDB pour locking
# ✅ Politique de sécurité stricte
# ✅ Lifecycle management des versions
# ✅ Génération automatique du backend.tf
```

**Caractéristiques de Sécurité :**
- 🔐 Chiffrement AES-256 activé
- 🔒 Versioning pour rollback
- 🛡️ Accès public bloqué
- ♻️ Nettoyage automatique anciennes versions (30j)

---

## 🌐 Configuration Providers

### Provider AWS Principal

```hcl
# environments/dev/main.tf
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Tags par défaut appliqués à toutes les ressources
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      CostCenter  = "Engineering"
      Owner       = "Platform Team"
    }
  }

  # Assume role pour cross-account (optionnel)
  # assume_role {
  #   role_arn = "arn:aws:iam::123456789012:role/TerraformExecutionRole"
  # }
}
```

### Provider Random pour Secrets

```hcl
provider "random" {
  # Utilisé pour générer :
  # - Mots de passe DB
  # - Tokens d'authentification Redis
  # - Suffixes uniques pour ressources
}
```

---

## 📊 Variables par Environnement

### Variables Communes

```hcl
# environments/dev/variables.tf

# =============================================================================
# Variables Obligatoires
# =============================================================================

variable "project_name" {
  description = "Nom du projet AccessWeaver"
  type        = string
  default     = "accessweaver"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Le nom du projet doit contenir uniquement des lettres minuscules, chiffres et tirets."
  }
}

variable "environment" {
  description = "Environnement de déploiement"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être : dev, staging ou prod."
  }
}

variable "aws_region" {
  description = "Région AWS de déploiement"
  type        = string
  default     = "eu-west-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "La région doit être au format AWS valide (ex: eu-west-1)."
  }
}

# =============================================================================
# Configuration Réseau
# =============================================================================

variable "vpc_cidr" {
  description = "CIDR block pour le VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Le CIDR VPC doit être un bloc CIDR valide."
  }
}

variable "availability_zones" {
  description = "Zones de disponibilité à utiliser"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Au moins 2 zones de disponibilité sont requises."
  }
}

# =============================================================================
# Configuration Base de Données
# =============================================================================

variable "db_instance_class" {
  description = "Type d'instance RDS"
  type        = string
  default     = "db.t3.micro"

  validation {
    condition     = can(regex("^db\\.[a-z0-9]+\\.[a-z0-9]+$", var.db_instance_class))
    error_message = "Le type d'instance doit être au format db.type.size."
  }
}

variable "db_allocated_storage" {
  description = "Stockage alloué pour RDS en GB"
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage >= 20 && var.db_allocated_storage <= 65536
    error_message = "Le stockage doit être entre 20 GB et 65536 GB."
  }
}

# =============================================================================
# Configuration Redis
# =============================================================================

variable "redis_node_type" {
  description = "Type d'instance Redis"
  type        = string
  default     = "cache.t3.micro"

  validation {
    condition     = can(regex("^cache\\.[a-z0-9]+\\.[a-z0-9]+$", var.redis_node_type))
    error_message = "Le type d'instance Redis doit être au format cache.type.size."
  }
}

# =============================================================================
# Configuration ECS
# =============================================================================

variable "ecs_cpu_default" {
  description = "CPU par défaut pour les services ECS"
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.ecs_cpu_default)
    error_message = "CPU doit être une valeur Fargate valide."
  }
}

variable "ecs_memory_default" {
  description = "Mémoire par défaut pour les services ECS"
  type        = number
  default     = 512

  validation {
    condition     = var.ecs_memory_default >= 512 && var.ecs_memory_default <= 8192
    error_message = "La mémoire doit être entre 512 MB et 8192 MB."
  }
}
```

### Fichiers de Variables par Environnement

#### 🔧 Development (terraform.tfvars)

```hcl
# environments/dev/terraform.tfvars

# Configuration de base
project_name = "accessweaver"
environment  = "dev"
aws_region   = "eu-west-1"

# Réseau - Configuration économique
vpc_cidr = "10.0.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b"]
enable_nat_gateway = true
single_nat_gateway = true  # 1 seul NAT Gateway pour économiser

# Base de données - Configuration minimale
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_multi_az         = false
db_backup_retention = 1
enable_read_replica = false

# Redis - Single node
redis_node_type         = "cache.t3.micro"
redis_num_cache_nodes   = 1
enable_redis_cluster    = false

# ECS - Ressources minimales
ecs_cpu_default    = 256
ecs_memory_default = 512
ecs_min_capacity   = 1
ecs_max_capacity   = 2
enable_container_insights = false

# Load Balancer - Configuration simplifiée
enable_alb_waf        = false
enable_alb_access_logs = false
force_https_redirect  = false

# Monitoring - Logs courts
log_retention_days = 7
enable_xray_tracing = false

# Domaine (optionnel en dev)
# domain_name = "dev.accessweaver.com"

# Tags additionnels
additional_tags = {
  Team = "Platform"
  Cost = "Development"
}
```

#### 🎭 Staging (terraform.tfvars)

```hcl
# environments/staging/terraform.tfvars

# Configuration de base
project_name = "accessweaver"
environment  = "staging"
aws_region   = "eu-west-1"

# Réseau - Multi-AZ pour HA
vpc_cidr = "10.1.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
enable_nat_gateway = true
single_nat_gateway = false  # Un NAT Gateway par AZ

# Base de données - Configuration intermédiaire
db_instance_class    = "db.t3.small"
db_allocated_storage = 50
db_multi_az         = true
db_backup_retention = 7
enable_read_replica = true

# Redis - Replication group
redis_node_type         = "cache.t3.small"
redis_num_cache_nodes   = 2  # Master + Replica
enable_redis_cluster    = false

# ECS - Ressources équilibrées
ecs_cpu_default    = 512
ecs_memory_default = 1024
ecs_min_capacity   = 1
ecs_max_capacity   = 4
enable_container_insights = true

# Load Balancer - Sécurité activée
enable_alb_waf        = true
enable_alb_access_logs = true
force_https_redirect  = true

# Monitoring - Logs étendus
log_retention_days = 14
enable_xray_tracing = true

# Domaine staging
domain_name = "staging.accessweaver.com"
route53_zone_id = "Z123456789ABCDEF"

# Tags additionnels
additional_tags = {
  Team = "Platform"
  Cost = "Staging"
  Purpose = "Integration-Testing"
}
```

#### 🚀 Production (terraform.tfvars)

```hcl
# environments/prod/terraform.tfvars

# Configuration de base
project_name = "accessweaver"
environment  = "prod"
aws_region   = "eu-west-1"

# Réseau - Configuration robuste
vpc_cidr = "10.2.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
enable_nat_gateway = true
single_nat_gateway = false

# Base de données - Configuration haute performance
db_instance_class    = "db.r6g.large"
db_allocated_storage = 100
db_multi_az         = true
db_backup_retention = 30
enable_read_replica = true
enable_performance_insights = true

# Redis - Cluster mode avec sharding
redis_node_type         = "cache.r6g.large"
redis_num_node_groups   = 3
redis_replicas_per_group = 2
enable_redis_cluster    = true

# ECS - Ressources robustes
ecs_cpu_default    = 1024
ecs_memory_default = 2048
ecs_min_capacity   = 2
ecs_max_capacity   = 10
enable_container_insights = true

# Load Balancer - Sécurité maximale
enable_alb_waf        = true
enable_alb_access_logs = true
force_https_redirect  = true
enable_ddos_protection = false  # Coût élevé, évaluer selon besoins

# Monitoring - Logs complets
log_retention_days = 30
enable_xray_tracing = true

# Domaine production
domain_name = "accessweaver.com"
route53_zone_id = "Z123456789ABCDEF"

# Sécurité avancée
deletion_protection = true
enable_encryption = true
kms_key_id = "arn:aws:kms:eu-west-1:123456789012:key/12345678-1234-1234-1234-123456789012"

# Tags additionnels
additional_tags = {
  Team = "Platform"
  Cost = "Production"
  Compliance = "GDPR"
  Backup = "Required"
  Monitoring = "Enhanced"
}
```

---

## 📤 Outputs de Configuration

### Outputs Principaux

```hcl
# environments/dev/outputs.tf

# =============================================================================
# Informations Réseau
# =============================================================================

output "vpc_id" {
  description = "ID du VPC créé"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs des subnets privés"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs des subnets publics"
  value       = module.vpc.public_subnet_ids
}

# =============================================================================
# Base de Données
# =============================================================================

output "database_endpoint" {
  description = "Endpoint de la base de données"
  value       = module.rds.db_instance_endpoint
  sensitive   = false
}

output "database_connection_string" {
  description = "Chaîne de connexion JDBC"
  value       = module.rds.connection_string
  sensitive   = false
}

# =============================================================================
# Cache Redis
# =============================================================================

output "redis_primary_endpoint" {
  description = "Endpoint Redis principal"
  value       = module.redis.primary_endpoint
  sensitive   = false
}

output "redis_connection_string" {
  description = "URL de connexion Redis"
  value       = module.redis.jedis_connection_string
  sensitive   = true
}

# =============================================================================
# Services ECS
# =============================================================================

output "ecs_cluster_name" {
  description = "Nom du cluster ECS"
  value       = module.ecs.cluster_name
}

output "service_urls" {
  description = "URLs des services AccessWeaver"
  value = {
    api_gateway = module.alb.api_base_url
    health_check = module.alb.health_check_url
    swagger_ui = module.alb.swagger_ui_url
  }
}

# =============================================================================
# Load Balancer
# =============================================================================

output "public_url" {
  description = "URL publique AccessWeaver"
  value       = module.alb.public_url
}

output "alb_dns_name" {
  description = "DNS name de l'ALB"
  value       = module.alb.alb_dns_name
}

# =============================================================================
# Configuration pour CI/CD
# =============================================================================

output "deployment_config" {
  description = "Configuration pour déploiement automatisé"
  value = {
    aws_region = var.aws_region
    environment = var.environment
    cluster_name = module.ecs.cluster_name
    ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  }
  sensitive = false
}

# =============================================================================
# Monitoring et Debug
# =============================================================================

output "debug_information" {
  description = "Informations pour debugging"
  value = {
    cloudwatch_log_groups = module.ecs.cloudwatch_log_groups
    health_check_urls = module.ecs.health_check_urls
    alarms = {
      rds = module.rds.cloudwatch_alarms
      redis = module.redis.cloudwatch_alarms_arns
      alb = module.alb.cloudwatch_alarms
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
```

---

## 🛠 Organisation des Modules

### Utilisation des Modules

```hcl
# environments/dev/main.tf

# =============================================================================
# Module VPC - Réseau de base
# =============================================================================
module "vpc" {
  source = "../../modules/vpc"
  
  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
  
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  enable_flow_logs   = var.environment != "dev"
  
  default_tags = var.additional_tags
}

# =============================================================================
# Module RDS - Base de données PostgreSQL
# =============================================================================
module "rds" {
  source = "../../modules/rds"
  
  project_name           = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  allowed_security_groups = [module.ecs.security_group_id]
  
  # Configuration adaptée à l'environnement
  instance_class_override = var.db_instance_class
  allocated_storage_override = var.db_allocated_storage
  backup_retention_period_override = var.db_backup_retention
  
  # Tags
  additional_tags = var.additional_tags
  
  depends_on = [module.vpc]
}

# =============================================================================
# Module Redis - Cache distribué
# =============================================================================
module "redis" {
  source = "../../modules/redis"
  
  project_name             = var.project_name
  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  allowed_security_groups = [module.ecs.security_group_id]
  
  # Configuration Redis
  node_type_override = var.redis_node_type
  
  # Tags
  additional_tags = var.additional_tags
  
  depends_on = [module.vpc]
}

# =============================================================================
# Module ECS - Orchestration des services
# =============================================================================
module "ecs" {
  source = "../../modules/ecs"
  
  project_name               = var.project_name
  environment               = var.environment
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  
  # Intégration avec autres modules
  rds_security_group_id     = module.rds.security_group_id
  redis_security_group_id   = module.redis.security_group_id
  
  # Configuration ECS
  container_registry        = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/accessweaver"
  
  # Auto-scaling
  min_capacity_override     = var.ecs_min_capacity
  max_capacity_override     = var.ecs_max_capacity
  
  # Tags
  additional_tags = var.additional_tags
  
  depends_on = [module.vpc, module.rds, module.redis]
}

# =============================================================================
# Module ALB - Load Balancer public
# =============================================================================
module "alb" {
  source = "../../modules/alb"
  
  project_name           = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  ecs_security_group_id = module.ecs.security_group_id
  
  # Configuration SSL et domaine
  custom_domain     = var.domain_name
  route53_zone_id   = var.route53_zone_id
  
  # Sécurité
  enable_waf = var.enable_alb_waf
  
  # Tags
  additional_tags = var.additional_tags
  
  depends_on = [module.vpc, module.ecs]
}
```

---

## 🔒 Sécurité et Validation

### Validation des Variables

```hcl
# Exemples de validations avancées

variable "environment" {
  description = "Environnement de déploiement"
  type        = string

  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être : dev, staging ou prod."
  }
}

variable "aws_region" {
  description = "Région AWS"
  type        = string

  validation {
    condition = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "Format de région AWS invalide."
  }
}

variable "vpc_cidr" {
  description = "CIDR du VPC"
  type        = string

  validation {
    condition = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Le CIDR VPC doit être valide."
  }
}
```

### Variables Sensibles

```hcl
# Marquage des variables sensibles
variable "database_password" {
  description = "Mot de passe de la base de données"
  type        = string
  sensitive   = true
}

variable "redis_auth_token" {
  description = "Token d'authentification Redis"
  type        = string
  sensitive   = true
}
```

---

## 📋 Commandes Utiles

### Commandes de Base

```bash
# Initialiser Terraform
terraform init

# Planifier les changements
terraform plan -var-file="terraform.tfvars"

# Appliquer les changements
terraform apply -var-file="terraform.tfvars"

# Voir les outputs
terraform output

# Nettoyer les ressources
terraform destroy -var-file="terraform.tfvars"
```

### Commandes Avancées

```bash
# Validation du code
terraform validate
terraform fmt -check -recursive

# Import de ressources existantes
terraform import module.vpc.aws_vpc.main vpc-12345678

# Debug avec logs détaillés
TF_LOG=DEBUG terraform plan

# State management
terraform state list
terraform state show module.vpc.aws_vpc.main

# Refresh sans modification
terraform refresh
```

### Makefile pour Automatisation

```makefile
# Makefile dans la racine du projet
.PHONY: help init plan apply destroy validate fmt

ENV ?= dev
REGION ?= eu-west-1

help: ## Afficher l'aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

init: ## Initialiser Terraform
	cd environments/$(ENV) && terraform init

plan: ## Planifier les changements
	cd environments/$(ENV) && terraform plan -var-file="terraform.tfvars"

apply: ## Appliquer les changements
	cd environments/$(ENV) && terraform apply -var-file="terraform.tfvars"

destroy: ## Détruire l'infrastructure
	cd environments/$(ENV) && terraform destroy -var-file="terraform.tfvars"

validate: ## Valider la configuration
	terraform fmt -check -recursive .
	cd environments/$(ENV) && terraform validate

fmt: ## Formatter le code
	terraform fmt -recursive .
```

---

## 🎯 Prochaines Étapes

Une fois la configuration Terraform maîtrisée, consultez :

1. **[Environment Variables](./environment.md)** - Configuration détaillée par environnement
2. **[State Management](./state.md)** - Gestion avancée du state Terraform
3. **[Terraform Best Practices](./terraform-best-practices.md)** - Optimisations et bonnes pratiques
4. **[Secrets Management](./secrets.md)** - Gestion sécurisée des secrets

---

**📝 Note :** Cette configuration est optimisée pour AccessWeaver mais peut être adaptée selon vos besoins spécifiques. Les exemples de coûts sont indicatifs et peuvent varier selon l'utilisation réelle.