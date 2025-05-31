# 🔧 Prerequisites & Setup - AccessWeaver Infrastructure

Guide complet pour préparer votre environnement avant le déploiement AccessWeaver sur AWS.

---

## 📋 Table des Matières

- [Prérequis Système](#prérequis-système)
- [Compte AWS](#compte-aws)
- [Outils Obligatoires](#outils-obligatoires)
- [Configuration Initiale](#configuration-initiale)
- [Vérifications](#vérifications)
- [Dépannage](#dépannage)

---

## 💻 Prérequis Système

### **Système d'Exploitation**
| OS | Version Minimale | Recommandé |
|-----|------------------|------------|
| **macOS** | 10.15+ | macOS 12+ |
| **Linux** | Ubuntu 20.04+ / RHEL 8+ | Ubuntu 22.04 LTS |
| **Windows** | Windows 10+ | Windows 11 + WSL2 |

### **Hardware Minimum**
```yaml
cpu: 4 cores
memory: 8 GB RAM
storage: 50 GB disponible
network: Connexion stable (uploads fréquents vers AWS)
```

### **Permissions Utilisateur**
- Droits administrateur local pour installations
- Accès réseau pour téléchargements et AWS
- Pas de proxy restrictif (ou configuration proxy)

---

## ☁️ Compte AWS

### **1. Compte AWS Requis**

#### **Nouveau Compte (Recommandé)**
```bash
# Créer un compte dédié pour AccessWeaver
✅ Compte AWS séparé pour le projet
✅ Carte de crédit valide associée
✅ Vérification téléphonique complétée
✅ Support Business ou Enterprise (production)
```

#### **Compte Existant**
```bash
# Si utilisation d'un compte existant
⚠️  Vérifier les limites de services
⚠️  S'assurer de l'organisation des ressources
⚠️  Planifier les tags et la facturation
```

### **2. Structure Organisationnelle**

#### **Mono-Account (Simple)**
```yaml
# Structure pour démarrer
accessweaver-main-account:
  environments:
    - dev
    - staging
    - prod
  isolation: Tags + naming
```

#### **Multi-Account (Production)**
```yaml
# Structure recommandée pour production
organization:
  master-account: 123456789012
  accounts:
    security: 123456789013      # Gestion sécurité centralisée
    logging: 123456789014       # Logs et audit
    prod: 123456789015          # Workloads production
    staging: 123456789016       # Tests pré-production
    dev: 123456789017           # Développement
```

### **3. Limites de Service AWS**

#### **Vérification des Quotas**
```bash
# Vérifier les limites actuelles
aws service-quotas list-service-quotas --service-code ec2 \
  --query 'Quotas[?QuotaName==`Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances`]'

aws service-quotas list-service-quotas --service-code elasticloadbalancing \
  --query 'Quotas[?QuotaName==`Application Load Balancers per Region`]'

aws service-quotas list-service-quotas --service-code ecs \
  --query 'Quotas[?QuotaName==`Services per cluster`]'
```

#### **Quotas Minimums Requis**
| Service | Quota | Usage AccessWeaver |
|---------|-------|-------------------|
| **EC2 vCPUs** | 20+ | ECS tasks (5-15 vCPUs) |
| **ECS Services** | 10+ | 5 microservices |
| **ALB** | 5+ | 1 par environnement |
| **RDS Instances** | 3+ | PostgreSQL instances |
| **ElastiCache Nodes** | 10+ | Redis clusters |

#### **Demande d'Augmentation**
```bash
# Exemple d'augmentation de limite
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-34B43A08 \
  --desired-value 50
```

---

## 🛠 Outils Obligatoires

### **1. Terraform**

#### **Installation**
```bash
# macOS (Homebrew)
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Ubuntu/Debian
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Windows (Chocolatey)
choco install terraform

# Ou téléchargement direct
# https://developer.hashicorp.com/terraform/downloads
```

#### **Vérification**
```bash
terraform version
# Terraform v1.6.0 ou plus récent requis
```

### **2. AWS CLI**

#### **Installation**
```bash
# macOS
brew install awscli

# Ubuntu/Debian
sudo apt install awscli

# Windows
# Télécharger depuis : https://aws.amazon.com/cli/

# Installation via pip (universel)
pip install awscli
```

#### **Vérification**
```bash
aws --version
# aws-cli/2.0.0 ou plus récent requis
```

### **3. Git**

#### **Installation**
```bash
# macOS (intégré ou Homebrew)
brew install git

# Ubuntu/Debian
sudo apt install git

# Windows
# Télécharger depuis : https://git-scm.com/
```

#### **Configuration**
```bash
git config --global user.name "Votre Nom"
git config --global user.email "votre@email.com"
```

### **4. Outils Optionnels (Recommandés)**

#### **jq (JSON Processing)**
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq

# Utilisation
aws ec2 describe-instances | jq '.Reservations[].Instances[].InstanceId'
```

#### **curl (API Testing)**
```bash
# Généralement pré-installé
curl --version

# Test endpoint AccessWeaver
curl -f https://your-alb-dns/actuator/health
```

#### **Docker (Pour tests locaux)**
```bash
# macOS
brew install --cask docker

# Ubuntu
sudo apt install docker.io docker-compose

# Vérification
docker --version
docker-compose --version
```

---

## ⚙️ Configuration Initiale

### **1. Configuration AWS CLI**

#### **Méthode Interactive**
```bash
aws configure
# AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region name [None]: eu-west-1
# Default output format [None]: json
```

#### **Variables d'Environnement**
```bash
# Créer ~/.aws/credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="eu-west-1"

# Ou utiliser AWS profiles
aws configure --profile accessweaver
export AWS_PROFILE=accessweaver
```

#### **AWS SSO (Recommandé pour entreprise)**
```bash
# Configuration SSO
aws configure sso
# SSO start URL: https://your-org.awsapps.com/start
# SSO region: eu-west-1
# Account ID: 123456789012
# Role name: AccessWeaverAdministrator

# Utilisation
aws sso login --profile accessweaver-prod
export AWS_PROFILE=accessweaver-prod
```

### **2. Permissions IAM Minimales**

#### **Politique Terraform (Development)**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "ecs:*",
        "rds:*",
        "elasticache:*",
        "elasticloadbalancing:*",
        "iam:*",
        "route53:*",
        "acm:*",
        "logs:*",
        "cloudwatch:*",
        "application-autoscaling:*",
        "s3:*",
        "dynamodb:*",
        "secretsmanager:*",
        "kms:*"
      ],
      "Resource": "*"
    }
  ]
}
```

#### **Utilisateur IAM (Setup)**
```bash
# Créer utilisateur dédié Terraform
aws iam create-user --user-name terraform-accessweaver

# Attacher politique
aws iam attach-user-policy \
  --user-name terraform-accessweaver \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Créer access keys
aws iam create-access-key --user-name terraform-accessweaver
```

### **3. Structure des Dossiers**

#### **Workspace Local**
```bash
# Créer structure de travail
mkdir -p ~/accessweaver-workspace
cd ~/accessweaver-workspace

# Structure recommandée
accessweaver-workspace/
├── aw-infrastructure-as-code/     # Repository Terraform
├── aw-api-gateway/                # Repositories services
├── aw-pdp-service/
├── scripts/                       # Scripts personnalisés
├── docs/                          # Documentation locale
└── .env                          # Variables d'environnement
```

#### **Variables d'Environnement**
```bash
# Créer ~/.accessweaver/config
mkdir -p ~/.accessweaver

cat > ~/.accessweaver/config << EOF
# AccessWeaver Configuration
export AWS_PROFILE=accessweaver
export AWS_DEFAULT_REGION=eu-west-1
export PROJECT_NAME=accessweaver
export TERRAFORM_VERSION=1.6.0

# Development
export DEV_DOMAIN=dev.accessweaver.com
export DEV_ZONE_ID=Z1234567890ABCDEF012345

# Production
export PROD_DOMAIN=accessweaver.com
export PROD_ZONE_ID=Z1234567890ABCDEF012345
EOF

# Charger automatiquement
echo "source ~/.accessweaver/config" >> ~/.bashrc
source ~/.bashrc
```

---

## ✅ Vérifications

### **1. Test des Outils**

#### **Script de Vérification**
```bash
#!/bin/bash
# check-prerequisites.sh

echo "🔍 Vérification des prérequis AccessWeaver..."

# Terraform
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    echo "✅ Terraform: $TERRAFORM_VERSION"
else
    echo "❌ Terraform non installé"
    exit 1
fi

# AWS CLI
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
    echo "✅ AWS CLI: $AWS_VERSION"
else
    echo "❌ AWS CLI non installé"
    exit 1
fi

# Git
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | cut -d' ' -f3)
    echo "✅ Git: $GIT_VERSION"
else
    echo "❌ Git non installé"
    exit 1
fi

echo "🎉 Tous les outils sont installés !"
```

### **2. Test AWS Connectivity**

```bash
# Test authentification
aws sts get-caller-identity

# Test permissions de base
aws ec2 describe-regions --region eu-west-1

# Test création de ressources (nettoyage automatique)
aws ec2 create-vpc --cidr-block 10.99.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=test-connectivity}]'
# Nettoyer immédiatement
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=test-connectivity" --query 'Vpcs[0].VpcId' --output text)
aws ec2 delete-vpc --vpc-id $VPC_ID
```

### **3. Test Terraform Backend**

```bash
# Test création du backend S3
./scripts/setup-backend.sh test eu-west-1

# Test initialisation Terraform
cd environments/dev
terraform init
terraform validate
terraform plan -var-file="terraform.tfvars.example"
```

### **4. Benchmark Performance Réseau**

```bash
# Test latence vers AWS
ping -c 5 ec2.eu-west-1.amazonaws.com

# Test bande passante (upload vers S3)
aws s3 cp /dev/zero s3://your-test-bucket/speedtest --region eu-west-1 --cli-write-timeout 0 --cli-read-timeout 0 &
sleep 10 && kill $!
```

---

## 🚨 Dépannage

### **1. Problèmes AWS CLI**

#### **Erreur : Unable to locate credentials**
```bash
# Vérifier configuration
aws configure list
aws configure list-profiles

# Debug
AWS_DEBUG=1 aws sts get-caller-identity

# Solutions
export AWS_PROFILE=accessweaver
# Ou
aws configure --profile accessweaver
```

#### **Erreur : Access Denied**
```bash
# Vérifier les permissions
aws iam get-user
aws iam list-attached-user-policies --user-name $(aws sts get-caller-identity --query User.UserName --output text)

# Vérifier les limites
aws iam simulate-principal-policy \
  --policy-source-arn $(aws sts get-caller-identity --query Arn --output text) \
  --action-names ec2:DescribeInstances
```

### **2. Problèmes Terraform**

#### **Erreur : Backend initialization failed**
```bash
# Nettoyer et réinitialiser
rm -rf .terraform .terraform.lock.hcl
terraform init -reconfigure

# Vérifier le backend S3
aws s3 ls s3://accessweaver-terraform-state-dev/
```

#### **Erreur : Provider registry.terraform.io/hashicorp/aws**
```bash
# Nettoyer le cache
rm -rf .terraform
terraform init -upgrade

# Forcer la version
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### **3. Problèmes Réseau**

#### **Timeout lors des téléchargements**
```bash
# Configurer proxy si nécessaire
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
export NO_PROXY=localhost,127.0.0.1,.company.com

# Terraform avec proxy
terraform init -no-color
```

#### **DNS Resolution Issues**
```bash
# Vérifier résolution DNS
nslookup ec2.eu-west-1.amazonaws.com
dig ec2.eu-west-1.amazonaws.com

# Utiliser DNS publics si nécessaire
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

### **4. Problèmes de Quotas AWS**

#### **Service Limit Exceeded**
```bash
# Vérifier les quotas actuels
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-34B43A08

# Lister toutes les demandes en cours
aws service-quotas list-requested-service-quota-change-history

# Créer une demande d'augmentation
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-34B43A08 \
  --desired-value 50
```

---

## 📚 Ressources Additionnelles

### **Documentation Officielle**
- **[AWS CLI Configuration](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)**
- **[Terraform Installation](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)**
- **[AWS Service Quotas](https://docs.aws.amazon.com/general/latest/gr/aws_service_limits.html)**

### **Outils de Productivité**

#### **AWS CLI Aliases**
```bash
# Ajouter à ~/.aws/cli/alias
[toplevel]
whoami = sts get-caller-identity
regions = ec2 describe-regions --query Regions[].RegionName --output table
instances = ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType,Tags[?Key==`Name`].Value|[0]]' --output table
```

#### **Terraform Helpers**
```bash
# Alias utiles pour ~/.bashrc
alias tf='terraform'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tfi='terraform init'
alias tfv='terraform validate'
alias tff='terraform fmt'
alias tfs='terraform show'
```

#### **AWS Profile Switcher**
```bash
# Fonction pour switcher facilement
aws-profile() {
  export AWS_PROFILE=$1
  echo "AWS Profile set to: $1"
  aws sts get-caller-identity
}

# Usage
aws-profile accessweaver-dev
aws-profile accessweaver-prod
```

---

## ✅ Checklist Finale

Avant de passer au déploiement, vérifiez :

### **Outils**
- [ ] Terraform >= 1.6.0 installé et fonctionnel
- [ ] AWS CLI >= 2.0.0 installé et configuré
- [ ] Git installé et configuré
- [ ] jq installé (recommandé)
- [ ] Docker installé (optionnel pour tests locaux)

### **AWS Account**
- [ ] Compte AWS configuré avec carte de crédit
- [ ] Utilisateur IAM avec permissions appropriées
- [ ] AWS CLI authentifié (aws sts get-caller-identity fonctionne)
- [ ] Région eu-west-1 accessible
- [ ] Quotas de services vérifiés et suffisants

### **Configuration**
- [ ] Variables d'environnement configurées
- [ ] AWS Profile configuré et testé
- [ ] Workspace local structuré
- [ ] Backend S3/DynamoDB créé et testé
- [ ] Connectivité réseau validée

### **Tests**
- [ ] Script de vérification des prérequis exécuté avec succès
- [ ] Test de création/suppression VPC réussi
- [ ] Terraform init/validate/plan fonctionne
- [ ] Accès aux services AWS requis confirmé

---

**🎉 Prérequis Complétés !**

Une fois toutes ces vérifications terminées, vous êtes prêt pour le [Quick Start Guide](./quick-start.md) ou le [First Deployment](./first-deployment.md).

**Prochaine étape :** [Configuration du Premier Environnement](./environment-setup.md)