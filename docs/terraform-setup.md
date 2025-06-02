# 🛠️ Installation et Configuration de Terraform pour AccessWeaver

Guide complet pour installer et configurer Terraform afin de gérer l'infrastructure d'AccessWeaver sur AWS.

---

## 📚 Table des Matières

- [Installation de Terraform](#installation-de-terraform)
- [Configuration Initiale](#configuration-initiale)
- [Backend S3 pour Terraform State](#backend-s3-pour-terraform-state)
- [Structure des Modules Terraform](#structure-des-modules-terraform)
- [Variables et Secrets](#variables-et-secrets)
- [Commandes Essentielles](#commandes-essentielles)
- [Bonnes Pratiques](#bonnes-pratiques)

---

## 💻 Installation de Terraform

### **macOS (recommandé)**

```bash
# Installation avec Homebrew
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Vérification
terraform version  # Doit afficher v1.5.0 ou supérieur
```

### **Linux**

```bash
# Ajout du référentiel HashiCorp
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

# Installation
sudo apt update && sudo apt install terraform

# Vérification
terraform version  # Doit afficher v1.5.0 ou supérieur
```

### **Windows**

```powershell
# Installation avec Chocolatey
choco install terraform

# Alternative avec Scoop
scoop install terraform

# Vérification
terraform version  # Doit afficher v1.5.0 ou supérieur
```

### **Installation AWS CLI**

Le CLI AWS est également nécessaire :

```bash
# macOS
brew install awscli

# Linux
sudo apt install awscli

# Configuration
aws configure
```

---

## ⚙️ Configuration Initiale

### **1. Création de la structure de projet**

```bash
mkdir -p accessweaver-infra/environments/{dev,staging,prod}
mkdir -p accessweaver-infra/modules
cd accessweaver-infra
```

### **2. Initialisation de Git**

```bash
git init
cat > .gitignore << EOF
# Local .terraform directories
**/.terraform/*

# .tfstate files
*.tfstate
*.tfstate.*

# tfvars files (potentiellement sensibles)
*.tfvars

# override files
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# CLI configuration files
.terraformrc
terraform.rc
EOF
```

### **3. Installation du Provider AWS**

Créez un fichier `providers.tf` dans la racine du projet :

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}
```

---

## 💾 Backend S3 pour Terraform State

Le state Terraform sera stocké dans S3 avec verrou DynamoDB pour la collaboration.

### **1. Création du bucket S3 et table DynamoDB**

```bash
# Création du bucket S3 (remplacer ACCOUNT_ID par votre ID de compte AWS)
aws s3api create-bucket \
  --bucket accessweaver-terraform-state-$ACCOUNT_ID \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1

# Activer le versioning sur le bucket
aws s3api put-bucket-versioning \
  --bucket accessweaver-terraform-state-$ACCOUNT_ID \
  --versioning-configuration Status=Enabled

# Créer la table DynamoDB pour le verrou
aws dynamodb create-table \
  --table-name accessweaver-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### **2. Configuration du backend S3**

Ajoutez cette configuration à votre fichier `providers.tf` :

```hcl
terraform {
  backend "s3" {
    bucket         = "accessweaver-terraform-state-${var.account_id}"
    key            = "${var.environment}/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "accessweaver-terraform-locks"
    encrypt        = true
  }
  
  # ... autres configurations terraform
}
```

---

## 🖼️ Structure des Modules Terraform

AccessWeaver utilise une organisation modulaire pour son infrastructure Terraform :

```
accessweaver-infra/
├── environments/
│   ├── dev/
│   │   ├── main.tf        # Appel des modules avec config dev
│   │   ├── variables.tf   # Variables spécifiques à dev
│   │   └── outputs.tf      # Sorties spécifiques à dev
│   ├── staging/         # Même structure pour staging
│   └── prod/            # Même structure pour production
├── modules/
│   ├── vpc/             # Module réseau
│   ├── alb/             # Module load balancer
│   ├── ecs/             # Module ECS pour microservices
│   ├── rds/             # Module RDS PostgreSQL
│   └── redis/           # Module ElastiCache Redis
└── providers.tf        # Configuration des providers et backend
```

### **Structure d'un Module**

Chaque module d'AccessWeaver suit une structure standard :

```
modules/vpc/
├── main.tf          # Définition des ressources
├── variables.tf     # Variables d'entrée du module
└── outputs.tf       # Valeurs de sortie du module
```

---

## 🔑 Variables et Secrets

### **1. Gestion des variables d'environnement**

Pour chaque environnement, créez un fichier `terraform.tfvars` qui ne sera pas committé dans Git :

```hcl
# environments/dev/terraform.tfvars
aws_region     = "eu-west-1"
environment    = "dev"
project_name   = "accessweaver"

vpc_cidr       = "10.0.0.0/16"

db_instance_class      = "db.t3.medium"
db_allocated_storage   = 20
db_multi_az            = false

redis_node_type        = "cache.t3.micro"
redis_replicas_per_node_group = 1
```

### **2. Gestion des secrets avec AWS Secrets Manager**

```bash
# Création des secrets pour la base de données
aws secretsmanager create-secret \
  --name accessweaver/dev/db-credentials \
  --description "AccessWeaver Dev DB Credentials" \
  --secret-string '{"username":"awadmin","password":"YOUR_STRONG_PASSWORD"}'

# Création des secrets pour Redis
aws secretsmanager create-secret \
  --name accessweaver/dev/redis-credentials \
  --description "AccessWeaver Dev Redis Credentials" \
  --secret-string '{"auth_token":"YOUR_STRONG_TOKEN"}'
```

Repéter pour staging et prod avec différentes valeurs.

### **3. Récupération des secrets dans Terraform**

```hcl
data "aws_secretsmanager_secret" "db_credentials" {
  name = "accessweaver/${var.environment}/db-credentials"
}

data "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = data.aws_secretsmanager_secret.db_credentials.id
}

locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.db_credentials.secret_string)
}

# Utilisation : local.db_creds.username, local.db_creds.password
```

---

## 👨‍💻 Commandes Essentielles

### **Initialisation du Projet**

```bash
# Dans le répertoire environnement (ex: environments/dev)
terraform init
```

### **Planification des Changements**

```bash
terraform plan
```

### **Application des Changements**

```bash
terraform apply
# ou pour appliquer sans confirmation
terraform apply -auto-approve
```

### **Suppression de l'Infrastructure**

```bash
# Attention : supprime complètement l'infrastructure
terraform destroy
```

### **Validation de la Syntaxe**

```bash
terraform fmt -check -recursive
terraform validate
```

---

## 👨‍🎓 Bonnes Pratiques AccessWeaver

### **1. Gestion des Environnements**

- Définir clairement les différences entre dev/staging/prod dans les fichiers `terraform.tfvars`
- Utiliser des workspaces Terraform pour isoler les états

```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod
terraform workspace select dev
```

### **2. Sécurité**

- Ne jamais stocker de secrets dans les fichiers Terraform
- Utiliser AWS Secrets Manager ou SSM Parameter Store
- Toujours activer la journalisation et le chiffrement

### **3. Modélisation**

- Toujours utiliser le tagging cohérent (projet, environnement, service...)
- Séparer les fichiers Terraform par préoccupation (réseau, calcul, données...)
- Limiter la taille des modules à moins de 300 lignes

### **4. Vérification des modifications**

- Exécuter `terraform plan` avant tout `apply`
- Utiliser la commande `terraform plan -out=tfplan` pour sauvegarder le plan
- Revête des modifications par un collègue

### **5. Intégration CI/CD**

- Utiliser GitHub Actions pour l'exécution automatique
- Configurer la validation dans la pipeline CI
- Appliquer automatiquement seulement pour dev, manuellement pour prod

```yaml
# Exemple GitHub Actions workflow
name: Terraform Dev Deploy
on:
  push:
    branches:
      - main
    paths:
      - 'environments/dev/**'

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      
      - name: Terraform Init
        run: |
          cd environments/dev
          terraform init
          
      - name: Terraform Validate
        run: |
          cd environments/dev
          terraform validate
          
      - name: Terraform Plan
        run: |
          cd environments/dev
          terraform plan
          
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: |
          cd environments/dev
          terraform apply -auto-approve
```

---

## 👉 Étapes Suivantes

Après avoir configuré Terraform :

1. [Configuration des secrets AWS](./secrets-setup.md) pour sécuriser vos informations sensibles
2. [Premier déploiement](./first-deployment.md) d'AccessWeaver sur votre infrastructure
3. Consulter la documentation des [modules](./modules/vpc.md) pour comprendre l'architecture de base