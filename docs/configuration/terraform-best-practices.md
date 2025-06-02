# 🏗️ Bonnes Pratiques Terraform - AccessWeaver

Guide complet des bonnes pratiques pour l'infrastructure as code d'AccessWeaver avec Terraform.

## 🎯 Philosophie AccessWeaver

### Principes Fondamentaux

```
🔧 Infrastructure as Code First
├── 📝 Tout doit être dans Terraform (pas de clics dans la console)
├── 🔄 Reproductible et versionnée
├── 🧪 Testable et validable
└── 📊 Observable et auditable

🏛️ Architecture Modulaire
├── 🧩 Modules réutilisables et testables
├── 🎭 Configuration par environnement
├── 🔗 Dépendances explicites
└── 📦 Versioning des modules

🛡️ Sécurité by Design  
├── 🔐 Secrets via AWS Secrets Manager uniquement
├── 🔑 Clés KMS dédiées par environnement
├── 🚫 Zéro secret en plain text
└── 📋 Audit trail complet
```

## 📁 Structure de Projet

### Organisation des Dossiers

```
aw-infrastructure-as-code/
├── 📂 environments/              # Configurations par environnement
│   ├── 📁 dev/
│   │   ├── main.tf              # Configuration principale dev
│   │   ├── variables.tf         # Variables spécifiques dev
│   │   ├── terraform.tfvars     # Valeurs dev (gitignored)
│   │   ├── terraform.tfvars.example  # Template pour dev
│   │   ├── backend.tf           # Backend S3 dev
│   │   └── outputs.tf           # Outputs spécifiques dev
│   ├── 📁 staging/              # Structure identique
│   └── 📁 prod/                 # Structure identique
│
├── 📂 modules/                  # Modules réutilisables
│   ├── 📁 vpc/                  # Module réseau
│   │   ├── main.tf             # Ressources principales
│   │   ├── variables.tf        # Variables d'entrée
│   │   ├── outputs.tf          # Valeurs de sortie
│   │   ├── README.md           # Documentation module
│   │   └── versions.tf         # Contraintes providers
│   ├── 📁 rds/                 # Module base de données
│   ├── 📁 redis/               # Module cache
│   ├── 📁 ecs/                 # Module containers
│   ├── 📁 alb/                 # Module load balancer
│   ├── 📁 kms/                 # Module chiffrement
│   └── 📁 secrets/             # Module secrets
│
├── 📂 scripts/                 # Scripts utilitaires
│   ├── setup-backend.sh       # Initialisation backend
│   ├── validate-terraform.sh  # Validation code
│   ├── plan-all-envs.sh       # Plan multi-environnements
│   └── deploy-env.sh          # Déploiement automatisé
│
├── 📂 tests/                   # Tests infrastructure
│   ├── 📁 unit/               # Tests unitaires modules
│   ├── 📁 integration/        # Tests intégration
│   └── 📁 e2e/               # Tests end-to-end
│
├── 📂 docs/                    # Documentation
├── 📄 .gitignore              # Exclusions Git
├── 📄 .terraform-version       # Version Terraform
├── 📄 .tflint.hcl             # Configuration TFLint
├── 📄 Makefile                # Commandes automatisées
└── 📄 README.md               # Documentation principale
```

### Conventions de Nommage

#### Resources AWS

```hcl
# Convention: {project}-{environment}-{service}-{resource_type}
# ✅ Bon
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "accessweaver-prod-vpc"  # accessweaver-prod-vpc
  }
}

resource "aws_db_instance" "main" {
  identifier = "accessweaver-prod-postgres"  # accessweaver-prod-postgres
}

# ❌ Mauvais
resource "aws_vpc" "vpc" {
  tags = {
    Name = "vpc-prod"  # Trop générique
  }
}
```

#### Variables et Locals

```hcl
# ✅ Variables descriptives avec validation
variable "project_name" {
  description = "Nom du projet AccessWeaver"
  type        = string
  default     = "accessweaver"
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.project_name))
    error_message = "Le nom du projet doit être en minuscules avec tirets."
  }
}

# ✅ Locals avec nommage clair
locals {
  # Configuration adaptative par environnement
  is_production = var.environment == "prod"
  is_staging    = var.environment == "staging"
  
  # Tags communs appliqués partout
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "infrastructure"
  }
  
  # Configuration base de données selon environnement
  db_config = {
    dev = {
      instance_class = "db.t3.micro"
      multi_az      = false
    }
    staging = {
      instance_class = "db.t3.small"
      multi_az      = true
    }
    prod = {
      instance_class = "db.r6g.large"
      multi_az      = true
    }
  }
  
  current_db_config = local.db_config[var.environment]
}
```

#### Fichiers et Modules

```bash
# ✅ Structure claire et cohérente
modules/
├── vpc/                    # Un module = un dossier
│   ├── main.tf            # Ressources principales
│   ├── variables.tf       # Toujours présent
│   ├── outputs.tf         # Toujours présent  
│   ├── versions.tf        # Versions providers
│   └── README.md          # Documentation obligatoire

# ✅ Nommage des fichiers
main.tf                    # Ressources principales
variables.tf               # Variables d'entrée
outputs.tf                # Valeurs de sortie
versions.tf               # Contraintes de version
data.tf                   # Data sources (si nombreuses)
locals.tf                 # Locals complexes (si nombreuses)

# ❌ À éviter
infrastructure.tf          # Nom trop générique
vars.tf                   # Abréviation
output.tf                 # Singulier au lieu de pluriel
```

## 🧩 Architecture Modulaire

### Design Patterns AccessWeaver

#### 1. Module Auto-Configurable

```hcl
# modules/rds/main.tf - Configuration adaptative
locals {
  # Configuration par environnement avec overrides possibles
  default_config = {
    dev = {
      instance_class        = "db.t3.micro"
      allocated_storage     = 20
      backup_retention     = 1
      multi_az             = false
      deletion_protection  = false
    }
    staging = {
      instance_class        = "db.t3.small" 
      allocated_storage     = 50
      backup_retention     = 7
      multi_az             = true
      deletion_protection  = false
    }
    prod = {
      instance_class        = "db.r6g.large"
      allocated_storage     = 100
      backup_retention     = 30
      multi_az             = true
      deletion_protection  = true
    }
  }
  
  # Fusionner config par défaut avec overrides utilisateur
  final_config = merge(
    local.default_config[var.environment],
    {
      instance_class = var.instance_class_override != null ? var.instance_class_override : local.default_config[var.environment].instance_class
      # ... autres overrides
    }
  )
}

resource "aws_db_instance" "main" {
  # Utiliser la configuration finale
  instance_class = local.final_config.instance_class
  multi_az      = local.final_config.multi_az
  # ...
}
```

#### 2. Module avec Sorties Riches

```hcl
# modules/rds/outputs.tf - Outputs complets pour intégration
output "connection_info" {
  description = "Informations de connexion prêtes pour Spring Boot"
  value = {
    # Informations de base
    endpoint = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    database = aws_db_instance.main.db_name
    
    # Configuration Spring Boot clé en main
    jdbc_url = "jdbc:postgresql://${aws_db_instance.main.endpoint}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
    
    # Configuration pour Docker Compose
    docker_env_vars = {
      DATABASE_HOST = aws_db_instance.main.address
      DATABASE_PORT = tostring(aws_db_instance.main.port)
      DATABASE_NAME = aws_db_instance.main.db_name
    }
    
    # Configuration pour ECS Task Definition
    ecs_environment = [
      {
        name  = "DATABASE_HOST"
        value = aws_db_instance.main.address
      },
      {
        name  = "DATABASE_PORT" 
        value = tostring(aws_db_instance.main.port)
      }
    ]
  }
  sensitive = false
}

output "monitoring_config" {
  description = "Configuration monitoring prête à utiliser"
  value = {
    cloudwatch_log_group = aws_cloudwatch_log_group.rds_logs.name
    alarm_arns = [
      aws_cloudwatch_metric_alarm.cpu_high.arn,
      aws_cloudwatch_metric_alarm.connections_high.arn
    ]
    dashboard_url = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=RDS-${var.project_name}-${var.environment}"
  }
}
```

#### 3. Module avec Validations Robustes

```hcl
# modules/vpc/variables.tf - Validations complètes
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Le CIDR VPC doit être un bloc CIDR IPv4 valide."
  }
  
  validation {
    condition     = can(regex("^10\\.|^172\\.(1[6-9]|2[0-9]|3[0-1])\\.|^192\\.168\\.", var.vpc_cidr))
    error_message = "Le CIDR VPC doit utiliser une plage d'adresses privées RFC 1918."
  }
  
  validation {
    condition     = tonumber(split("/", var.vpc_cidr)[1]) >= 16
    error_message = "Le CIDR VPC doit avoir un masque de /16 ou plus grand (plus d'adresses disponibles)."
  }
}

variable "environment" {
  description = "Environnement de déploiement"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être exactement: dev, staging, ou prod."
  }
}

variable "availability_zones" {
  description = "Liste des zones de disponibilité"
  type        = list(string)
  
  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Au moins 2 zones de disponibilité sont requises pour la haute disponibilité."
  }
  
  validation {
    condition = alltrue([
      for az in var.availability_zones :
      can(regex("^[a-z]{2}-[a-z]+-[0-9][a-z]$", az))
    ])
    error_message = "Les AZ doivent être au format AWS standard (ex: eu-west-1a)."
  }
}
```

### Composition d'Environnement

```hcl
# environments/prod/main.tf - Orchestration des modules
terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  # Tags par défaut appliqués à toutes les ressources
  default_tags {
    tags = {
      Project     = "AccessWeaver"
      Environment = "prod"
      ManagedBy   = "Terraform"
      CostCenter  = "Engineering"
      Owner       = "Platform-Team"
    }
  }
}

# ===== RÉSEAU =====
module "vpc" {
  source = "../../modules/vpc"
  
  project_name       = var.project_name
  environment        = "prod"
  vpc_cidr          = "10.0.0.0/16"
  availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  
  # Production: Flow logs activés
  enable_flow_logs = true
  flow_log_retention_days = 90
}

# ===== SÉCURITÉ =====
module "kms" {
  source = "../../modules/kms"
  
  project_name = var.project_name
  environment  = "prod"
  
  # Production: Rotation fréquente
  enable_key_rotation = true
  key_rotation_days  = 30
}

module "secrets" {
  source = "../../modules/secrets"
  
  project_name = var.project_name
  environment  = "prod"
  
  # Utiliser les clés KMS créées
  kms_key_id = module.kms.kms_key_arns["secrets"]
  
  # Production: Rotation automatique
  auto_rotation_enabled = true
  rotation_days        = 30
  
  # Backup cross-region
  replica_regions = ["eu-central-1"]
}

# ===== DONNÉES =====
module "rds" {
  source = "../../modules/rds"
  
  project_name           = var.project_name
  environment           = "prod" 
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  allowed_security_groups = [module.ecs.security_group_id]
  
  # Utiliser la clé KMS dédiée
  kms_key_id = module.kms.kms_key_arns["rds"]
  
  # Monitoring avancé
  sns_topic_arn = aws_sns_topic.critical_alerts.arn
}

module "redis" {
  source = "../../modules/redis"
  
  project_name             = var.project_name
  environment             = "prod"
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  allowed_security_groups = [module.ecs.security_group_id]
  
  # Utiliser la clé KMS dédiée
  kms_key_id = module.kms.kms_key_arns["redis"]
  
  # Production: Cluster mode avec HA
  node_type_override = "cache.r6g.large"
  
  # Monitoring
  sns_topic_arn = aws_sns_topic.critical_alerts.arn
}

# ===== COMPUTE =====
module "ecs" {
  source = "../../modules/ecs"
  
  project_name               = var.project_name
  environment               = "prod"
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  
  # Sécurité réseau
  alb_security_group_ids    = [module.alb.security_group_id]
  rds_security_group_id     = module.rds.security_group_id  
  redis_security_group_id   = module.redis.security_group_id
  
  # Configuration containers
  container_registry        = var.container_registry
  image_tag                = var.image_tag
  
  # Production: Monitoring complet
  container_insights_enabled = true
  enable_xray_tracing        = true
  log_retention_days         = 30
  
  # Auto-scaling agressif
  min_capacity_override     = 2
  max_capacity_override     = 10
  scaling_cpu_target        = 60
  
  # Variables d'environnement communes
  common_environment_variables = {
    SPRING_PROFILES_ACTIVE = "prod"
    JAVA_OPTS             = "-Xmx1536m -XX:+UseG1GC"
    LOG_LEVEL             = "INFO"
  }
  
  # Integration ALB
  target_group_arns = module.alb.target_group_arns
}

# ===== LOAD BALANCER =====
module "alb" {
  source = "../../modules/alb"
  
  project_name           = var.project_name
  environment           = "prod"
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  ecs_security_group_id = module.ecs.security_group_id
  
  # Production: Domaine custom
  custom_domain         = "accessweaver.com"
  route53_zone_id      = var.route53_zone_id
  
  # Sécurité maximale
  enable_waf           = true
  waf_rate_limit      = 1000  # Plus strict
  ssl_policy          = "ELBSecurityPolicy-TLS-1-3-2021-06"
  
  # Accès restreint
  allowed_cidr_blocks = var.production_allowed_cidrs
  
  # Monitoring
  enable_access_logs         = true
  access_logs_retention_days = 90
  sns_topic_arn             = aws_sns_topic.critical_alerts.arn
}

# ===== MONITORING =====
resource "aws_sns_topic" "critical_alerts" {
  name = "accessweaver-prod-critical-alerts"
  
  tags = {
    Name = "accessweaver-prod-critical-alerts"
    Type = "monitoring"
  }
}

# ===== OUTPUTS =====
output "application_urls" {
  description = "URLs principales de l'application"
  value = {
    public_url    = module.alb.public_url
    api_base_url  = module.alb.api_base_url
    health_check  = module.alb.health_check_url
    swagger_ui    = module.alb.swagger_ui_url
  }
}

output "database_config" {
  description = "Configuration base de données pour les équipes"
  value = {
    endpoint     = module.rds.db_instance_endpoint
    port        = module.rds.db_instance_port
    database    = module.rds.database_name
    # Note: Pas de mot de passe ici (sécurité)
  }
  sensitive = false
}

output "monitoring_dashboards" {
  description = "URLs des dashboards de monitoring"
  value = {
    cloudwatch = "https://console.aws.amazon.com/cloudwatch/home?region=eu-west-1"
    rds        = module.rds.cloudwatch_dashboard_url
    ecs        = module.ecs.cloudwatch_dashboard_url
  }
}
```

## 🔄 Gestion des États

### Backend Configuration

```hcl
# environments/prod/backend.tf
terraform {
  backend "s3" {
    bucket         = "accessweaver-terraform-state-prod-123456789012"
    key            = "prod/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "accessweaver-terraform-locks-prod"
    encrypt        = true
    
    # Sécurité renforcée
    skip_region_validation      = false
    skip_credentials_validation = false
    skip_metadata_api_check    = false
    force_path_style           = false
  }
}
```

### State Management Best Practices

```bash
#!/bin/bash
# scripts/state-management.sh

# ✅ Toujours faire un plan avant apply
terraform plan -out=tfplan
terraform apply tfplan
rm tfplan

# ✅ Protéger l'état en cas de conflit
terraform state pull > backup-$(date +%Y%m%d-%H%M%S).tfstate

# ✅ Importer des ressources existantes proprement
terraform import aws_vpc.main vpc-0123456789abcdef0
terraform plan  # Vérifier qu'aucun changement n'est prévu

# ✅ Déplacer des ressources entre modules
terraform state mv aws_instance.old_location module.new_module.aws_instance.new_location

# ❌ Ne jamais modifier l'état manuellement
# terraform state rm aws_instance.important  # DANGEREUX
```

### Remote State Sharing

```hcl
# Référencer l'état d'un autre environnement
data "terraform_remote_state" "shared_services" {
  backend = "s3"
  config = {
    bucket = "accessweaver-terraform-state-shared-123456789012"
    key    = "shared/terraform.tfstate"
    region = "eu-west-1"
  }
}

# Utiliser les outputs d'autres états
resource "aws_route53_record" "app" {
  zone_id = data.terraform_remote_state.shared_services.outputs.route53_zone_id
  name    = "api-${var.environment}.accessweaver.com"
  # ...
}
```

## 🧪 Validation et Tests

### Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
        args:
          - '--args=--sort-by-required'
      - id: terraform_tflint
        args:
          - '--args=--only=terraform_deprecated_interpolation'
          - '--args=--only=terraform_deprecated_index'
          - '--args=--only=terraform_unused_declarations'
          - '--args=--only=terraform_comment_syntax'
          - '--args=--only=terraform_documented_outputs'
          - '--args=--only=terraform_documented_variables'
          - '--args=--only=terraform_typed_variables'
          - '--args=--only=terraform_module_pinned_source'
          - '--args=--only=terraform_naming_convention'
          - '--args=--only=terraform_required_version'
          - '--args=--only=terraform_required_providers'
          - '--args=--only=terraform_standard_module_structure'
      - id: terraform_checkov
        args:
          - '--args=--framework terraform --check CKV_AWS_79,CKV_AWS_61'
      - id: terrascan
        args:
          - '--args=--iac-type terraform --policy-type aws'
```

### TFLint Configuration

```hcl
# .tflint.hcl
config {
  module = true
  force = false
  disabled_by_default = false
}

plugin "aws" {
  enabled = true
  version = "0.24.1"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Règles obligatoires AccessWeaver
rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

# Règles AWS spécifiques
rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_db_instance_invalid_type" {
  enabled = true
}

rule "aws_elasticache_cluster_invalid_type" {
  enabled = true
}
```

### Tests avec Terratest

```go
// tests/integration/vpc_test.go
package integration

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/gruntwork-io/terratest/modules/aws"
    "github.com/stretchr/testify/assert"
)

func TestVPCModule(t *testing.T) {
    t.Parallel()
    
    // Configuration du test
    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../../modules/vpc",
        Vars: map[string]interface{}{
            "project_name":       "accessweaver-test",
            "environment":        "test",
            "vpc_cidr":          "10.99.0.0/16",
            "availability_zones": []string{"eu-west-1a", "eu-west-1b"},
        },
    })
    
    // Nettoyage à la fin du test
    defer terraform.Destroy(t, terraformOptions)
    
    // Déployer l'infrastructure
    terraform.InitAndApply(t, terraformOptions)
    
    // Tests
    vpcId := terraform.Output(t, terraformOptions, "vpc_id")
    assert.NotEmpty(t, vpcId)
    
    publicSubnetIds := terraform.OutputList(t, terraformOptions, "public_subnet_ids") 
    assert.Len(t, publicSubnetIds, 2)
    
    // Vérifier que le VPC existe dans AWS
    vpc := aws.GetVpcById(t, vpcId, "eu-west-1")
    assert.Equal(t, "10.99.0.0/16", *vpc.CidrBlock)
    
    // Vérifier les tags
    assert.Equal(t, "accessweaver-test-test-vpc", aws.GetTagsForVpc(t, vpcId, "eu-west-1")["Name"])
}

func TestRDSModule(t *testing.T) {
    t.Parallel()
    
    terraformOptions := &terraform.Options{
        TerraformDir: "../../modules/rds",
        Vars: map[string]interface{}{
            "project_name":         "accessweaver-test",
            "environment":          "test",
            "vpc_id":              "vpc-test",
            "private_subnet_ids":   []string{"subnet-test1", "subnet-test2"},
            "allowed_security_groups": []string{"sg-test"},
        },
    }
    
    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)
    
    // Vérifier les outputs
    endpoint := terraform.Output(t, terraformOptions, "db_instance_endpoint")
    assert.Contains(t, endpoint, "rds.amazonaws.com")
    
    connectionString := terraform.Output(t, terraformOptions, "connection_string")
    assert.Contains(t, connectionString, "jdbc:postgresql://")
}
```

### Tests avec Kitchen-Terraform

```yaml
# .kitchen.yml
---
driver:
  name: terraform
  root_module_directory: test/fixtures/complete

provisioner:
  name: terraform

verifier:
  name: terraform
  systems:
    - name: local
      backend: local

platforms:
  - name: aws

suites:
  - name: complete
    driver:
      variables:
        project_name: "accessweaver-test"
        environment: "test"
    verifier:
      systems:
        - name: local
          backend: local
          controls:
            - vpc_created
            - subnets_created_in_multiple_azs
            - internet_gateway_attached
```

## 🔧 Outils et Automation

### Makefile pour Automation

```makefile
# Makefile
.PHONY: help plan apply destroy validate fmt docs test

# Variables
ENV ?= dev
REGION ?= eu-west-1
TF_VAR_FILE ?= terraform.tfvars

help: ## Afficher l'aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

validate: ## Valider la configuration Terraform
	@echo "🔍 Validating Terraform configuration..."
	terraform fmt -check=true -recursive
	terraform validate
	tflint --recursive
	checkov -d . --framework terraform

fmt: ## Formater le code Terraform
	@echo "🎨 Formatting Terraform code..."
	terraform fmt -recursive

init: ## Initialiser Terraform
	@echo "🚀 Initializing Terraform for $(ENV)..."
	cd environments/$(ENV) && terraform init

plan: init ## Planifier les changements
	@echo "📋 Planning changes for $(ENV)..."
	cd environments/$(ENV) && terraform plan -var-file=$(TF_VAR_FILE) -out=terraform.tfplan

apply: ## Appliquer les changements  
	@echo "🚀 Applying changes for $(ENV)..."
	cd environments/$(ENV) && terraform apply terraform.tfplan
	rm -f environments/$(ENV)/terraform.tfplan

destroy: ## Détruire l'infrastructure
	@echo "💥 Destroying infrastructure for $(ENV)..."
	@read -p "Are you sure you want to destroy $(ENV)? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		cd environments/$(ENV) && terraform destroy -var-file=$(TF_VAR_FILE); \
	else \
		echo "Operation cancelled."; \
	fi

docs: ## Générer la documentation
	@echo "📚 Generating documentation..."
	terraform-docs markdown table --output-file README.md modules/vpc/
	terraform-docs markdown table --output-file README.md modules/rds/
	terraform-docs markdown table --output-file README.md modules/redis/
	terraform-docs markdown table --output-file README.md modules/ecs/
	terraform-docs markdown table --output-file README.md modules/alb/

test: ## Lancer les tests
	@echo "🧪 Running tests..."
	cd tests && go test -v -timeout 30m ./...

security-scan: ## Scanner la sécurité
	@echo "🛡️ Running security scan..."
	checkov -d . --framework terraform --check CKV_AWS_79,CKV_AWS_61,CKV_AWS_273
	tfsec .

cost-estimate: ## Estimer les coûts
	@echo "💰 Estimating costs for $(ENV)..."
	cd environments/$(ENV) && terraform plan -var-file=$(TF_VAR_FILE) -out=cost-plan.tfplan
	infracost breakdown --path environments/$(ENV)/cost-plan.tfplan

plan-all: ## Planifier tous les environnements
	@echo "📋 Planning all environments..."
	@for env in dev staging prod; do \
		echo "Planning $env..."; \
		cd environments/$env && terraform init && terraform plan -var-file=terraform.tfvars -out=terraform.tfplan; \
		cd ../..; \
	done

clean: ## Nettoyer les fichiers temporaires
	@echo "🧹 Cleaning temporary files..."
	find . -name "*.tfplan" -delete
	find . -name ".terraform" -type d -exec rm -rf {} +
	find . -name ".terraform.lock.hcl" -delete
```

### Scripts d'Automation

```bash
#!/bin/bash
# scripts/deploy-env.sh - Déploiement automatisé avec validation

set -e

ENV=${1:-dev}
REGION=${2:-eu-west-1}
AUTO_APPROVE=${3:-false}

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}🔧 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Validation des paramètres
if [[ "$ENV" != "dev" && "$ENV" != "staging" && "$ENV" != "prod" ]]; then
    print_error "Environment must be one of: dev, staging, prod"
    exit 1
fi

print_step "Starting deployment for environment: $ENV"

# Vérification des prérequis
print_step "Checking prerequisites..."

# AWS CLI configuré
if ! aws sts get-caller-identity &>/dev/null; then
    print_error "AWS CLI not configured properly"
    exit 1
fi

# Terraform installé
if ! command -v terraform &>/dev/null; then
    print_error "Terraform not installed"
    exit 1
fi

# TFLint installé
if ! command -v tflint &>/dev/null; then
    print_warning "TFLint not installed, skipping validation"
    SKIP_TFLINT=true
fi

print_success "Prerequisites check passed"

# Validation de la configuration
print_step "Validating Terraform configuration..."

cd "environments/$ENV"

# Format check
if ! terraform fmt -check=true -recursive; then
    print_error "Terraform files are not properly formatted"
    print_step "Running terraform fmt..."
    terraform fmt -recursive
    print_success "Files formatted"
fi

# Terraform validate
terraform init -backend=false
terraform validate

if [[ "$SKIP_TFLINT" != "true" ]]; then
    # TFLint validation
    tflint --init
    tflint
fi

print_success "Validation passed"

# Initialisation
print_step "Initializing Terraform..."
terraform init

# Plan
print_step "Creating execution plan..."
terraform plan -var-file=terraform.tfvars -out=terraform.tfplan

# Affichage du résumé
print_step "Plan summary:"
terraform show -json terraform.tfplan | jq -r '
  .planned_values.root_module.resources[] | 
  select(.type | startswith("aws_")) | 
  "\(.type): \(.values.tags.Name // .address)"
' | sort | uniq -c

# Confirmation pour apply
if [[ "$AUTO_APPROVE" != "true" ]]; then
    echo ""
    read -p "Do you want to apply these changes to $ENV? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled"
        rm -f terraform.tfplan
        exit 0
    fi
fi

# Application des changements
print_step "Applying changes..."
terraform apply terraform.tfplan

# Nettoyage
rm -f terraform.tfplan

print_success "Deployment completed successfully for $ENV!"

# Affichage des outputs utiles
print_step "Important outputs:"
if terraform output public_url &>/dev/null; then
    echo "Public URL: $(terraform output -raw public_url)"
fi

if terraform output api_base_url &>/dev/null; then
    echo "API Base URL: $(terraform output -raw api_base_url)"
fi

print_step "Deployment completed at $(date)"
```

```bash
#!/bin/bash
# scripts/validate-terraform.sh - Validation complète

set -e

print_step() {
    echo -e "\033[0;34m🔧 $1\033[0m"
}

print_success() {
    echo -e "\033[0;32m✅ $1\033[0m"
}

print_error() {
    echo -e "\033[0;31m❌ $1\033[0m"
}

ERRORS=0

# 1. Format check
print_step "Checking Terraform formatting..."
if ! terraform fmt -check=true -recursive; then
    print_error "Code is not properly formatted"
    ERRORS=$((ERRORS + 1))
else
    print_success "Code formatting OK"
fi

# 2. Validation syntaxe
print_step "Validating Terraform syntax..."
for env_dir in environments/*/; do
    env=$(basename "$env_dir")
    print_step "Validating $env..."
    
    cd "$env_dir"
    terraform init -backend=false
    
    if ! terraform validate; then
        print_error "Validation failed for $env"
        ERRORS=$((ERRORS + 1))
    else
        print_success "Validation passed for $env"
    fi
    
    cd - > /dev/null
done

# 3. TFLint
if command -v tflint &>/dev/null; then
    print_step "Running TFLint..."
    if ! tflint --recursive; then
        print_error "TFLint found issues"
        ERRORS=$((ERRORS + 1))
    else
        print_success "TFLint passed"
    fi
else
    print_step "TFLint not available, skipping..."
fi

# 4. Checkov security scan
if command -v checkov &>/dev/null; then
    print_step "Running Checkov security scan..."
    if ! checkov -d . --framework terraform --quiet; then
        print_error "Checkov found security issues"
        ERRORS=$((ERRORS + 1))
    else
        print_success "Checkov security scan passed"
    fi
else
    print_step "Checkov not available, skipping security scan..."
fi

# 5. Module documentation
print_step "Checking module documentation..."
for module_dir in modules/*/; do
    module=$(basename "$module_dir")
    
    if [[ ! -f "$module_dir/README.md" ]]; then
        print_error "Missing README.md for module $module"
        ERRORS=$((ERRORS + 1))
    fi
    
    if [[ ! -f "$module_dir/variables.tf" ]]; then
        print_error "Missing variables.tf for module $module"
        ERRORS=$((ERRORS + 1))
    fi
    
    if [[ ! -f "$module_dir/outputs.tf" ]]; then
        print_error "Missing outputs.tf for module $module"
        ERRORS=$((ERRORS + 1))
    fi
done

if [[ $ERRORS -eq 0 ]]; then
    print_success "All validations passed!"
    exit 0
else
    print_error "$ERRORS validation(s) failed"
    exit 1
fi
```

## 🔒 Sécurité

### Scan Automatique des Vulnérabilités

```yaml
# .github/workflows/security-scan.yml
name: Security Scan
on:
  pull_request:
    paths:
      - '**.tf'
      - '**.tfvars.example'
  push:
    branches: [main]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: .
          framework: terraform
          output_format: sarif
          output_file_path: checkov-results.sarif
          check: CKV_AWS_79,CKV_AWS_61,CKV_AWS_273,CKV_AWS_144
          
      - name: Upload Checkov results
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: checkov-results.sarif
          
      - name: Run TFSec
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          working_directory: .
          additional_args: --force-all-dirs --verbose
          
      - name: Run Terrascan
        uses: accurics/terrascan-action@main
        with:
          iac_type: terraform
          policy_type: aws
          only_warn: false
```

### Gestion des Secrets

```hcl
# ✅ Bonne pratique - Secrets via AWS Secrets Manager
resource "aws_ecs_task_definition" "app" {
  container_definitions = jsonencode([{
    name = "app"
    
    # Variables publiques
    environment = [
      {
        name  = "SPRING_PROFILES_ACTIVE"
        value = var.environment
      }
    ]
    
    # Secrets depuis Secrets Manager
    secrets = [
      {
        name      = "DATABASE_PASSWORD"
        valueFrom = "arn:aws:secretsmanager:eu-west-1:123456789:secret:accessweaver/prod/database/password"
      }
    ]
  }])
}

# ❌ Mauvaise pratique - Secrets en variables
resource "aws_ecs_task_definition" "bad_example" {
  container_definitions = jsonencode([{
    environment = [
      {
        name  = "DATABASE_PASSWORD"
        value = "hardcoded_password"  # JAMAIS FAIRE ÇA
      }
    ]
  }])
}
```

### Protection des Ressources Critiques

```hcl
# Protection contre suppression accidentelle
resource "aws_db_instance" "main" {
  # ... configuration ...
  
  deletion_protection = var.environment == "prod" ? true : false
  skip_final_snapshot = var.environment == "prod" ? false : true
  
  lifecycle {
    prevent_destroy = true  # Protection Terraform
    ignore_changes = [
      password,  # Géré par Secrets Manager
    ]
  }
}

# Tags obligatoires pour audit
locals {
  required_tags = {
    Project      = var.project_name
    Environment  = var.environment
    ManagedBy    = "terraform"
    Owner        = "platform-team"
    CostCenter   = "engineering"
    Compliance   = var.environment == "prod" ? "SOC2" : "none"
  }
}

resource "aws_instance" "example" {
  # ... configuration ...
  
  tags = merge(local.required_tags, {
    Name = "accessweaver-${var.environment}-example"
    Type = "application-server"
  })
}
```

## 📊 Monitoring et Observabilité

### Métriques Terraform

```hcl
# CloudWatch Dashboard pour infrastructure
resource "aws_cloudwatch_dashboard" "infrastructure" {
  dashboard_name = "AccessWeaver-Infrastructure-${var.environment}"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix],
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.id],
            ["AWS/ElastiCache", "CPUUtilization", "CacheClusterId", aws_elasticache_cluster.main.cluster_id]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Infrastructure Health"
        }
      },
      {
        type   = "log"
        width  = 24
        height = 6
        properties = {
          query   = "SOURCE '/aws/lambda/terraform-state-monitor'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 100"
          region  = data.aws_region.current.name
          title   = "Infrastructure Errors"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# Alertes sur les dérives de configuration
resource "aws_cloudwatch_log_metric_filter" "terraform_drift" {
  name           = "terraform-drift-${var.environment}"
  log_group_name = "/aws/lambda/terraform-drift-detector"
  
  pattern = "[timestamp, request_id, level=\"ERROR\", message=\"Configuration drift detected\"]"
  
  metric_transformation {
    name      = "TerraformDrift"
    namespace = "AccessWeaver/Infrastructure"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "terraform_drift_alarm" {
  alarm_name          = "terraform-drift-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "TerraformDrift"
  namespace           = "AccessWeaver/Infrastructure"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Terraform configuration drift detected"
  alarm_actions       = [aws_sns_topic.infrastructure_alerts.arn]
  
  tags = local.common_tags
}
```

### Drift Detection

```bash
#!/bin/bash
# scripts/drift-detection.sh - Détection des dérives de configuration

set -e

ENV=${1:-prod}
SLACK_WEBHOOK=${2:-""}

detect_drift() {
    local env=$1
    echo "🔍 Checking drift for environment: $env"
    
    cd "environments/$env"
    
    # Initialiser Terraform
    terraform init
    
    # Créer un plan de détection de dérive
    terraform plan -detailed-exitcode -var-file=terraform.tfvars -out=drift-check.tfplan
    exit_code=$?
    
    case $exit_code in
        0)
            echo "✅ No drift detected for $env"
            rm -f drift-check.tfplan
            ;;
        1)
            echo "❌ Error occurred during drift detection for $env"
            rm -f drift-check.tfplan
            return 1
            ;;
        2)
            echo "⚠️  Configuration drift detected for $env"
            
            # Analyser les changements
            terraform show -json drift-check.tfplan > drift-analysis.json
            
            # Extraire les ressources modifiées
            jq -r '.resource_changes[] | select(.change.actions[] | contains("update") or contains("delete") or contains("create")) | "\(.type): \(.change.actions | join(","))"' drift-analysis.json > drift-summary.txt
            
            echo "📋 Drift summary:"
            cat drift-summary.txt
            
            # Notification Slack si webhook fourni
            if [[ -n "$SLACK_WEBHOOK" ]]; then
                send_slack_notification "$env" "drift-summary.txt"
            fi
            
            # Cleanup
            rm -f drift-check.tfplan drift-analysis.json
            ;;
    esac
    
    cd - > /dev/null
}

send_slack_notification() {
    local env=$1
    local summary_file=$2
    
    local drift_details=$(cat "$summary_file")
    
    curl -X POST -H 'Content-type: application/json' \
        --data "{
            \"text\": \"🚨 Terraform Drift Detected\",
            \"attachments\": [
                {
                    \"color\": \"warning\",
                    \"fields\": [
                        {
                            \"title\": \"Environment\",
                            \"value\": \"$env\",
                            \"short\": true
                        },
                        {
                            \"title\": \"Changes Detected\",
                            \"value\": \"\\`\\`\\`$drift_details\\`\\`\\`\",
                            \"short\": false
                        }
                    ]
                }
            ]
        }" "$SLACK_WEBHOOK"
}

# Vérifier tous les environnements si aucun spécifié
if [[ "$ENV" == "all" ]]; then
    for env in dev staging prod; do
        detect_drift "$env"
    done
else
    detect_drift "$ENV"
fi
```

## 📈 Performance et Optimisation

### Optimisation des Plans Terraform

```hcl
# Utilisation de data sources avec cache
data "aws_availability_zones" "available" {
  state = "available"
  
  # Cache pendant 1 heure
  lifecycle {
    postcondition {
      condition     = length(self.names) >= 2
      error_message = "Au moins 2 AZ doivent être disponibles."
    }
  }
}

# Parallelization hints
resource "aws_subnet" "private" {
  count = length(var.availability_zones)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]
  
  # Permet à Terraform de créer en parallèle
  depends_on = [aws_vpc.main]
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-${count.index + 1}"
  })
}

# Éviter les cycles de dépendances
resource "aws_security_group" "app" {
  name_prefix = "${var.project_name}-app-"
  vpc_id      = aws_vpc.main.id
  
  # Règles définies séparément pour éviter les cycles
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "app_ingress" {
  type                     = "ingress"
  from_port               = 8080
  to_port                 = 8080
  protocol                = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id       = aws_security_group.app.id
}
```

### Optimisation des Coûts

```hcl
# Variables pour optimisation des coûts
variable "cost_optimization_level" {
  description = "Niveau d'optimisation des coûts (basic, aggressive)"
  type        = string
  default     = "basic"
  
  validation {
    condition     = contains(["basic", "aggressive"], var.cost_optimization_level)
    error_message = "Cost optimization level must be 'basic' or 'aggressive'."
  }
}

locals {
  # Configuration adaptative selon le niveau d'optimisation
  cost_config = {
    basic = {
      rds_backup_retention = var.environment == "prod" ? 30 : 7
      log_retention_days  = var.environment == "prod" ? 30 : 14
      enable_monitoring   = var.environment == "prod"
    }
    aggressive = {
      rds_backup_retention = var.environment == "prod" ? 7 : 1
      log_retention_days  = var.environment == "prod" ? 14 : 3
      enable_monitoring   = false
    }
  }
  
  current_cost_config = local.cost_config[var.cost_optimization_level]
}

# Application de l'optimisation
resource "aws_db_instance" "main" {
  # ... autres configurations ...
  
  backup_retention_period = local.current_cost_config.rds_backup_retention
  
  # Désactiver les features coûteuses si optimisation agressive
  performance_insights_enabled = var.cost_optimization_level == "basic" ? local.current_cost_config.enable_monitoring : false
  monitoring_interval         = var.cost_optimization_level == "basic" ? 60 : 0
}

# Tags pour suivi des coûts
resource "aws_resourcegroups_group" "cost_tracking" {
  name = "AccessWeaver-${var.environment}-CostTracking"
  
  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Project"
          Values = [var.project_name]
        },
        {
          Key    = "Environment"  
          Values = [var.environment]
        }
      ]
    })
  }
  
  tags = {
    Name = "AccessWeaver-${var.environment}-CostTracking"
  }
}
```

## ⚠️ Erreurs Courantes à Éviter

### ❌ Antipatterns Terraform

```hcl
# ❌ MAUVAIS - Hardcoding de valeurs
resource "aws_instance" "bad" {
  ami           = "ami-12345"  # AMI hardcodée
  instance_type = "t3.micro"   # Type hardcodé
  subnet_id     = "subnet-123" # Subnet hardcodé
}

# ✅ BON - Configuration paramétrable
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "good" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = local.instance_types[var.environment]
  subnet_id     = module.vpc.private_subnet_ids[0]
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-instance"
  })
}

# ❌ MAUVAIS - State mutable
resource "aws_s3_bucket" "bad" {
  bucket = var.bucket_name
  acl    = "private"  # Deprecated
}

# ✅ BON - Resources séparées
resource "aws_s3_bucket" "good" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_acl" "good" {
  bucket = aws_s3_bucket.good.id
  acl    = "private"
}

# ❌ MAUVAIS - Cycles de dépendances
resource "aws_security_group" "app" {
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
}

resource "aws_security_group" "alb" {
  egress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]  # CYCLE!
  }
}

# ✅ BON - Règles séparées
resource "aws_security_group" "app" {
  name_prefix = "app-"
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "app_from_alb" {
  type                     = "ingress"
  from_port               = 8080
  to_port                 = 8080
  protocol                = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id       = aws_security_group.app.id
}
```

### 🛡️ Bonnes Pratiques de Sécurité

```hcl
# ✅ Validation stricte des inputs
variable "allowed_cidr_blocks" {
  description = "CIDR blocks autorisés"
  type        = list(string)
  
  validation {
    condition = alltrue([
      for cidr in var.allowed_cidr_blocks :
      can(cidrhost(cidr, 0))
    ])
    error_message = "Tous les CIDR doivent être valides."
  }
  
  validation {
    condition = length([
      for cidr in var.allowed_cidr_blocks :
      cidr if cidr == "0.0.0.0/0"
    ]) == 0 || var.environment == "dev"
    error_message = "CIDR 0.0.0.0/0 non autorisé en staging/prod."
  }
}

# ✅ Protection des ressources sensibles
resource "aws_db_instance" "main" {
  # ... configuration ...
  
  # Sécurité renforcée
  storage_encrypted = true
  kms_key_id       = aws_kms_key.rds.arn
  
  # Backup sécurisé
  backup_retention_period = var.environment == "prod" ? 30 : 7
  copy_tags_to_snapshot  = true
  
  # Protection contre suppression
  deletion_protection = var.environment == "prod"
  skip_final_snapshot = var.environment != "prod"
  
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [password]
  }
}

# ✅ Monitoring obligatoire pour ressources critiques
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "RDS CPU utilization too high"
  
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
  
  alarm_actions = var.environment == "prod" ? [aws_sns_topic.alerts.arn] : []
  
  tags = local.common_tags
}
```

---

## 📞 Support et Ressources

### 🔧 Outils Recommandés

| Outil | Usage | Installation |
|-------|--------|-------------|
| **Terraform** | Infrastructure as Code | `brew install terraform` |
| **TFLint** | Validation et linting | `brew install tflint` |
| **Checkov** | Sécurité et compliance | `pip install checkov` |
| **TFSec** | Analyse sécurité | `brew install tfsec` |
| **Terraform-docs** | Génération documentation | `brew install terraform-docs` |
| **Infracost** | Estimation coûts | `brew install infracost` |
| **Terratest** | Tests infrastructure | `go get github.com/gruntwork-io/terratest` |

### 📚 Documentation et Standards

- **📖 Terraform Best Practices** : [Terraform Documentation](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- **🛡️ AWS Security Best Practices** : [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- **🔐 CIS Benchmarks** : [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- **📋 AccessWeaver Standards** : [GitHub Wiki](https://github.com/accessweaver/aw-infrastructure-as-code/wiki)

### 🚨 Contacts Support

- **🔧 Issues Infrastructure** : [GitHub Issues](https://github.com/accessweaver/aw-infrastructure-as-code/issues)
- **📧 Équipe Platform** : platform@accessweaver.com
- **💬 Slack** : #platform-support
- **📞 Urgences Production** : +33 X XX XX XX XX

---

**⚠️ Note Importante** : Ces bonnes pratiques évoluent avec l'écosystème Terraform et AWS. Consultez régulièrement les mises à jour et adaptez selon les besoins spécifiques d'AccessWeaver.