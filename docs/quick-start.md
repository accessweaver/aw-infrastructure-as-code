# ⚡ Guide de Démarrage Rapide - AccessWeaver

Ce guide vous permet de déployer AccessWeaver sur AWS en 30 minutes. Pour une documentation plus détaillée, consultez les guides spécifiques.

---

## 📚 Table des Matières

- [Prérequis](#prérequis)
- [Configuration AWS](#configuration-aws)
- [Installation des Outils](#installation-des-outils)
- [Déploiement de l'Infrastructure](#déploiement-de-linfrastructure)
- [Vérification du Déploiement](#vérification-du-déploiement)
- [Prochaines Étapes](#prochaines-étapes)

---

## 🌟 Prérequis

### **Environnement Local**

- Système d'exploitation : macOS, Linux, ou Windows avec WSL2
- Minimum 8Go RAM, 4 cores CPU, 50Go disque
- Connexion internet stable

### **Compte AWS**

- Compte AWS actif avec carte de crédit valide
- Accès administrateur pour créer IAM, VPC, ECS, etc.
- Identifiants AWS (Access Key et Secret Key)

### **Outils Requis**

- AWS CLI v2
- Terraform v1.5+
- Git
- jq (pour traitement JSON)

---

## 🔑 Configuration AWS

### **1. Création d'un Utilisateur IAM**

```bash
# Connexion à la console AWS et création d'un utilisateur administratif
# https://console.aws.amazon.com/iamv2/

# Nom recommandé: accessweaver-admin
# Permissions: AdministratorAccess
# Type d'Accès: Programmatic access
```

### **2. Configuration du CLI AWS**

```bash
# Configuration des identifiants
aws configure
```

Entrez les informations suivantes :
- AWS Access Key ID: *votre_access_key*
- AWS Secret Access Key: *votre_secret_key*
- Default region name: `eu-west-1` (ou votre région préférée)
- Default output format: `json`

### **3. Création Bucket S3 et Table DynamoDB pour Terraform**

```bash
# Définir l'ID de compte AWS (remplacez avec votre ID)
export ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Créer un bucket pour le state Terraform
aws s3api create-bucket \
  --bucket accessweaver-terraform-state-$ACCOUNT_ID \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1

# Activer le versioning sur le bucket
aws s3api put-bucket-versioning \
  --bucket accessweaver-terraform-state-$ACCOUNT_ID \
  --versioning-configuration Status=Enabled

# Créer une table DynamoDB pour le verrou
aws dynamodb create-table \
  --table-name accessweaver-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

---

## 💻 Installation des Outils

### **Installation de Terraform**

MacOS :
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

Linux :
```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt update && sudo apt install terraform
```

Windows (avec Chocolatey) :
```powershell
choco install terraform
```

Vérification :
```bash
terraform version  # Doit afficher v1.5.0 ou plus
```

---

## 🔐 Configuration des Secrets

### **1. Création des Secrets pour les Bases de Données**

```bash
# Générer des mots de passe complexes
PG_PASSWORD=$(openssl rand -base64 16)
REDIS_TOKEN=$(openssl rand -base64 32)

# Créer les secrets dans AWS Secrets Manager
# Secret pour PostgreSQL
aws secretsmanager create-secret \
  --name accessweaver/dev/database/postgres-admin \
  --secret-string "{\"username\":\"awadmin\",\"password\":\"$PG_PASSWORD\"}"

# Secret pour Redis
aws secretsmanager create-secret \
  --name accessweaver/dev/redis/auth-token \
  --secret-string "{\"auth_token\":\"$REDIS_TOKEN\"}"
```

### **2. Création des Paramètres SSM**

```bash
# Configuration standard
aws ssm put-parameter \
  --name "/accessweaver/dev/config/db_host" \
  --value "accessweaver-postgres.internal" \
  --type "String"

aws ssm put-parameter \
  --name "/accessweaver/dev/config/db_port" \
  --value "5432" \
  --type "String"
```

---

## 🏗️ Déploiement de l'Infrastructure

### **1. Cloner le Repository**

```bash
git clone https://github.com/votre-org/accessweaver-infrastructure.git
cd accessweaver-infrastructure
```

### **2. Création du fichier de variables**

Créer un fichier `environments/dev/terraform.tfvars` :

```hcl
project_name    = "accessweaver"
environment     = "dev"
aws_region      = "eu-west-1"

# Réseau
vpc_cidr        = "10.0.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b"]

# Base de données
db_instance_class      = "db.t3.medium"
db_allocated_storage   = 20
db_multi_az            = false

# Redis
redis_node_type        = "cache.t3.micro"
redis_replicas_per_node_group = 1
```

### **3. Initialisation et Déploiement**

```bash
# Se placer dans l'environnement de développement
cd environments/dev

# Initialiser Terraform
terraform init \
  -backend-config="bucket=accessweaver-terraform-state-$ACCOUNT_ID" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=eu-west-1" \
  -backend-config="dynamodb_table=accessweaver-terraform-locks"

# Valider la configuration
terraform validate

# Générer un plan d'exécution
terraform plan -out=tfplan

# Appliquer le plan
terraform apply "tfplan"
```

---

## 🔎 Vérification du Déploiement

### **1. Vérifier les ressources déployées**

```bash
# Vérifier l'ALB créé
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'accessweaver-dev')].DNSName" \
  --output text

# Vérifier les clusters ECS
aws ecs list-clusters \
  --query "clusterArns[*]" \
  --output text

# Vérifier l'instance RDS
aws rds describe-db-instances \
  --query "DBInstances[?contains(DBInstanceIdentifier, 'accessweaver-dev')].Endpoint.Address" \
  --output text
```

### **2. Consulter les Outputs Terraform**

```bash
terraform output
```

Notez l'URL de l'ALB et les autres informations importantes affichées.

---

## 📃 Prochaines Étapes

Félicitations ! Vous avez déployé l'infrastructure de base d'AccessWeaver. Voici les prochaines étapes :

1. **Déployer les Services** : Déployer les containers ECS pour les services AccessWeaver
2. **Configurer DNS** : Utiliser Route53 pour configurer un nom de domaine pour votre application
3. **Sécuriser Davantage** : Consulter la documentation de sécurité pour renforcer votre déploiement

Pour une documentation plus détaillée :

- [Configuration détaillée AWS](./aws-setup.md)
- [Installation complète de Terraform](./terraform-setup.md)
- [Gestion avancée des Secrets](./secrets-setup.md)
- [Architecture de Sécurité](./architecture/security.md)

---

## 👩‍💻 Support et Ressources

- **Documentation Complète** : Dans le dossier `docs/` et sur notre site
- **Assistance Communauté** : Forum et chat accessibles sur [community.accessweaver.com](https://community.accessweaver.com)
- **Problèmes Connus** : Consultez les issues GitHub

---

*Ce guide est conçu pour un déploiement rapide. Pour un environnement de production, veuillez consulter les guides spécifiques sur la haute disponibilité, la sécurité et le scaling.*