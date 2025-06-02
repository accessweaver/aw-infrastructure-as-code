# 🗃️ State Management - AccessWeaver

Gestion complète du state Terraform pour AccessWeaver : backend S3, locking, versioning et stratégies de récupération.

---

## 🎯 Vue d'Ensemble

Le state Terraform est le cœur de la gestion d'infrastructure. Ce document couvre la configuration, la sécurisation et la maintenance du state AccessWeaver stocké dans AWS S3 avec DynamoDB pour le locking.

### 🏗 Architecture du State

```
Backend S3 Terraform State
├── accessweaver-terraform-state-dev-123456789012/
│   ├── dev/terraform.tfstate
│   ├── dev/terraform.tfstate.backup
│   └── .terraform/
│       └── terraform.tfstate (local cache)
├── accessweaver-terraform-state-staging-123456789012/
│   └── staging/terraform.tfstate
└── accessweaver-terraform-state-prod-123456789012/
    └── prod/terraform.tfstate

DynamoDB Lock Tables
├── accessweaver-terraform-locks-dev
├── accessweaver-terraform-locks-staging
└── accessweaver-terraform-locks-prod
```

### 🔐 Principes de Sécurité

- **🔒 Isolation** : State séparé par environnement et account AWS
- **🔐 Chiffrement** : AES-256 sur S3 + TLS en transit
- **🔑 Authentification** : IAM roles et policies restrictives
- **📝 Versioning** : Historique complet des changements
- **🚫 Locking** : Prévention des modifications concurrentes

---

## 🏗 Configuration Backend

### Setup Initial Automatique

Le script `setup-backend.sh` configure automatiquement tout le backend :

```bash
# Initialisation complète du backend pour un environnement
./scripts/setup-backend.sh prod eu-west-1

# Résultat :
# ✅ S3 bucket: accessweaver-terraform-state-prod-123456789012
# ✅ DynamoDB table: accessweaver-terraform-locks-prod
# ✅ Backend config: environments/prod/backend.tf
# ✅ Sécurité: chiffrement + versioning + lifecycle
```

### Configuration Backend Générée

```hcl
# environments/prod/backend.tf (généré automatiquement)
terraform {
  backend "s3" {
    bucket         = "accessweaver-terraform-state-prod-123456789012"
    key            = "prod/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "accessweaver-terraform-locks-prod"
    encrypt        = true

    # Validation et sécurité
    skip_region_validation      = false
    skip_credentials_validation = false
    skip_metadata_api_check     = false
    force_path_style           = false
    
    # Profil AWS (optionnel)
    # profile = "accessweaver-prod"
    
    # Assume role pour cross-account (optionnel)
    # role_arn = "arn:aws:iam::PROD-ACCOUNT:role/TerraformExecutionRole"
  }
}
```

---

## 🔐 Sécurité du State

### Bucket S3 Sécurisé

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyPublicAccess",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::accessweaver-terraform-state-prod-*",
        "arn:aws:s3:::accessweaver-terraform-state-prod-*/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    },
    {
      "Sid": "AllowTerraformAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/TerraformExecutionRole"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::accessweaver-terraform-state-prod-*",
        "arn:aws:s3:::accessweaver-terraform-state-prod-*/*"
      ]
    }
  ]
}
```

### Politique IAM Terraform

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
        "s3:GetBucketVersioning"
      ],
      "Resource": [
        "arn:aws:s3:::accessweaver-terraform-state-*",
        "arn:aws:s3:::accessweaver-terraform-state-*/*"
      ]
    },
    {
      "Sid": "DynamoDBLockAccess",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/accessweaver-terraform-locks-*"
    }
  ]
}
```

### Chiffrement KMS (Optionnel)

```hcl
# Pour chiffrement avancé avec KMS
resource "aws_kms_key" "terraform_state" {
  description = "KMS key for AccessWeaver Terraform state encryption"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableTerraformAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::123456789012:role/TerraformExecutionRole"
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "accessweaver-terraform-state-key"
    Environment = "prod"
    Purpose     = "terraform-state-encryption"
  }
}

# Configuration backend avec KMS
terraform {
  backend "s3" {
    bucket     = "accessweaver-terraform-state-prod-123456789012"
    key        = "prod/terraform.tfstate"
    region     = "eu-west-1"
    encrypt    = true
    kms_key_id = "arn:aws:kms:eu-west-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  }
}
```

---

## 🔄 Lifecycle Management

### Versioning S3

```json
{
  "Rules": [
    {
      "ID": "terraform-state-lifecycle",
      "Status": "Enabled",
      "Filter": {
        "Prefix": ""
      },
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 90
      },
      "AbortIncompleteMultipartUpload": {
        "DaysAfterInitiation": 7
      }
    }
  ]
}
```

### Monitoring des Versions

```bash
# Script de monitoring des versions
#!/bin/bash
# scripts/state-versions.sh

BUCKET="accessweaver-terraform-state-prod-123456789012"
KEY="prod/terraform.tfstate"

echo "📊 Versions du state Terraform pour $KEY"
echo "=================================================="

aws s3api list-object-versions \
  --bucket "$BUCKET" \
  --prefix "$KEY" \
  --query 'Versions[?Key==`'$KEY'`].[VersionId,LastModified,Size]' \
  --output table

echo ""
echo "📈 Statistiques:"
TOTAL_VERSIONS=$(aws s3api list-object-versions \
  --bucket "$BUCKET" \
  --prefix "$KEY" \
  --query 'length(Versions[?Key==`'$KEY'`])')

echo "   Total versions: $TOTAL_VERSIONS"

LATEST_SIZE=$(aws s3api head-object \
  --bucket "$BUCKET" \
  --key "$KEY" \
  --query 'ContentLength' \
  --output text)

echo "   Taille actuelle: $(($LATEST_SIZE / 1024)) KB"
```

---

## 🔒 Locking avec DynamoDB

### Configuration Table DynamoDB

```bash
# Création automatique via script
aws dynamodb create-table \
  --table-name accessweaver-terraform-locks-prod \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region eu-west-1 \
  --tags Key=Project,Value=AccessWeaver Key=Environment,Value=prod
```

### Gestion des Locks

```bash
# Voir les locks actifs
aws dynamodb scan \
  --table-name accessweaver-terraform-locks-prod \
  --select ALL_ATTRIBUTES

# Structure d'un lock
{
  "LockID": "accessweaver-terraform-state-prod-123456789012/prod/terraform.tfstate-md5",
  "Info": "{\"ID\":\"abc123\",\"Operation\":\"OperationTypeApply\",\"Info\":\"\",\"Who\":\"user@domain.com\",\"Version\":\"1.5.0\",\"Created\":\"2024-01-15T10:30:00Z\",\"Path\":\"prod/terraform.tfstate\"}",
  "Created": "2024-01-15T10:30:00Z",
  "Who": "user@domain.com"
}
```

### Résolution des Locks Bloqués

```bash
# Script de déblocage d'urgence
#!/bin/bash
# scripts/unlock-state.sh

ENV=${1:-prod}
FORCE=${2:-false}

echo "⚠️  Tentative de déblocage du state $ENV"

if [ "$FORCE" != "true" ]; then
  echo "❌ Confirmer avec: $0 $ENV true"
  exit 1
fi

# Forcer le déblocage
terraform force-unlock \
  -force \
  $(aws dynamodb scan \
    --table-name "accessweaver-terraform-locks-$ENV" \
    --query 'Items[0].LockID.S' \
    --output text)

echo "✅ State débloqué pour $ENV"
```

---

## 🔄 Backup et Récupération

### Stratégie de Backup

```bash
# Script de backup automatique
#!/bin/bash
# scripts/backup-state.sh

ENV=${1:-prod}
BACKUP_BUCKET="accessweaver-terraform-backups-123456789012"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

SOURCE_BUCKET="accessweaver-terraform-state-$ENV-123456789012"
SOURCE_KEY="$ENV/terraform.tfstate"

BACKUP_KEY="backups/$ENV/$TIMESTAMP/terraform.tfstate"

echo "💾 Backup du state $ENV vers $BACKUP_KEY"

# Copie avec métadonnées
aws s3 cp \
  "s3://$SOURCE_BUCKET/$SOURCE_KEY" \
  "s3://$BACKUP_BUCKET/$BACKUP_KEY" \
  --metadata "source-env=$ENV,backup-time=$TIMESTAMP"

# Vérification
if aws s3 ls "s3://$BACKUP_BUCKET/$BACKUP_KEY" > /dev/null; then
  echo "✅ Backup réussi: $BACKUP_KEY"
else
  echo "❌ Échec du backup"
  exit 1
fi
```

### Stratégie de Récupération

```bash
# Script de restauration
#!/bin/bash
# scripts/restore-state.sh

ENV=${1}
BACKUP_DATE=${2}

if [ -z "$ENV" ] || [ -z "$BACKUP_DATE" ]; then
  echo "Usage: $0 <env> <backup-date>"
  echo "Exemple: $0 prod 20240115-103000"
  exit 1
fi

BACKUP_BUCKET="accessweaver-terraform-backups-123456789012"
STATE_BUCKET="accessweaver-terraform-state-$ENV-123456789012"

BACKUP_KEY="backups/$ENV/$BACKUP_DATE/terraform.tfstate"
STATE_KEY="$ENV/terraform.tfstate"

echo "⚠️  ATTENTION: Restauration du state $ENV depuis $BACKUP_DATE"
read -p "Continuer ? (yes/NO): " confirm

if [ "$confirm" != "yes" ]; then
  echo "❌ Restauration annulée"
  exit 1
fi

# Backup du state actuel avant restauration
CURRENT_BACKUP="backups/$ENV/before-restore-$(date +%Y%m%d-%H%M%S)/terraform.tfstate"
aws s3 cp \
  "s3://$STATE_BUCKET/$STATE_KEY" \
  "s3://$BACKUP_BUCKET/$CURRENT_BACKUP"

echo "💾 State actuel sauvegardé dans: $CURRENT_BACKUP"

# Restauration
aws s3 cp \
  "s3://$BACKUP_BUCKET/$BACKUP_KEY" \
  "s3://$STATE_BUCKET/$STATE_KEY"

echo "✅ State restauré depuis: $BACKUP_KEY"
echo "🔄 Exécuter 'terraform refresh' pour synchroniser"
```

---

## 🛠 Opérations State

### Migration de State

```bash
# Migration d'un environnement vers un nouveau backend
terraform state pull > terraform.tfstate.backup

# Reconfiguration du backend
terraform init -migrate-state \
  -backend-config="bucket=new-bucket-name" \
  -backend-config="key=new/path/terraform.tfstate"

# Vérification
terraform plan
```

### Import de Ressources

```bash
# Import de ressources existantes dans le state
terraform import module.vpc.aws_vpc.main vpc-12345678
terraform import module.rds.aws_db_instance.main accessweaver-prod-postgres
terraform import module.redis.aws_elasticache_replication_group.main accessweaver-prod-redis

# Vérification après import
terraform plan
```

### Manipulation du State

```bash
# Lister les ressources du state
terraform state list

# Voir une ressource spécifique
terraform state show module.vpc.aws_vpc.main

# Déplacer une ressource dans le state
terraform state mv \
  module.old_vpc.aws_vpc.main \
  module.new_vpc.aws_vpc.main

# Supprimer une ressource du state (sans détruire)
terraform state rm module.vpc.aws_nat_gateway.unused

# Remplacer une ressource
terraform apply -replace="module.ecs.aws_ecs_service.api_gateway"
```

---

## 📊 Monitoring et Alertes

### Métriques CloudWatch

```bash
# Script de monitoring des opérations state
#!/bin/bash
# scripts/monitor-state.sh

ENV=${1:-prod}
BUCKET="accessweaver-terraform-state-$ENV-123456789012"

echo "📊 Monitoring du state $ENV"
echo "================================"

# Dernière modification
LAST_MODIFIED=$(aws s3api head-object \
  --bucket "$BUCKET" \
  --key "$ENV/terraform.tfstate" \
  --query 'LastModified' \
  --output text)

echo "Dernière modification: $LAST_MODIFIED"

# Taille du state
SIZE=$(aws s3api head-object \
  --bucket "$BUCKET" \
  --key "$ENV/terraform.tfstate" \
  --query 'ContentLength' \
  --output text)

echo "Taille: $(($SIZE / 1024)) KB"

# Vérifier les locks
LOCKS=$(aws dynamodb scan \
  --table-name "accessweaver-terraform-locks-$ENV" \
  --select COUNT \
  --query 'Count')

if [ "$LOCKS" -gt 0 ]; then
  echo "⚠️  Locks actifs: $LOCKS"
else
  echo "✅ Aucun lock actif"
fi
```

### Alertes CloudWatch

```json
{
  "AlarmName": "AccessWeaver-Terraform-State-Changes",
  "AlarmDescription": "Alerte sur les modifications du state Terraform",
  "MetricName": "NumberOfObjects",
  "Namespace": "AWS/S3",
  "Statistic": "Average",
  "Dimensions": [
    {
      "Name": "BucketName",
      "Value": "accessweaver-terraform-state-prod-123456789012"
    }
  ],
  "Period": 300,
  "EvaluationPeriods": 1,
  "Threshold": 1,
  "ComparisonOperator": "GreaterThanThreshold",
  "AlarmActions": [
    "arn:aws:sns:eu-west-1:123456789012:terraform-state-changes"
  ]
}
```

---

## 🚨 Troubleshooting

### Problèmes Courants

#### 1. State Lock Bloqué

```bash
# Symptôme
Error: Error acquiring the state lock

# Diagnostic
aws dynamodb scan --table-name accessweaver-terraform-locks-prod

# Solution
terraform force-unlock <LOCK_ID>

# Ou suppression manuelle
aws dynamodb delete-item \
  --table-name accessweaver-terraform-locks-prod \
  --key '{"LockID":{"S":"<LOCK_ID>"}}'
```

#### 2. State Corrompu

```bash
# Symptôme
Error: state data in S3 does not have the expected content

# Solution - Restauration depuis backup
aws s3 cp \
  s3://backup-bucket/backups/prod/20240115/terraform.tfstate \
  s3://state-bucket/prod/terraform.tfstate

# Puis refresh
terraform refresh
```

#### 3. Conflit de Versions

```bash
# Symptôme
Error: state snapshot was created by Terraform v1.5.0, which is newer than current v1.4.0

# Solution - Mise à jour Terraform
terraform version
tfenv install 1.5.0
tfenv use 1.5.0
```

### Scripts de Diagnostic

```bash
# Diagnostic complet du state
#!/bin/bash
# scripts/diagnose-state.sh

ENV=${1:-prod}

echo "🔍 Diagnostic du state $ENV"
echo "=========================="

# 1. Vérifier l'accès S3
BUCKET="accessweaver-terraform-state-$ENV-123456789012"
if aws s3 ls "s3://$BUCKET/" > /dev/null 2>&1; then
  echo "✅ Accès S3 OK"
else
  echo "❌ Échec accès S3"
  exit 1
fi

# 2. Vérifier l'existence du state
if aws s3 ls "s3://$BUCKET/$ENV/terraform.tfstate" > /dev/null 2>&1; then
  echo "✅ State file existe"
else
  echo "❌ State file introuvable"
  exit 1
fi

# 3. Vérifier DynamoDB
TABLE="accessweaver-terraform-locks-$ENV"
if aws dynamodb describe-table --table-name "$TABLE" > /dev/null 2>&1; then
  echo "✅ Table DynamoDB OK"
else
  echo "❌ Table DynamoDB introuvable"
  exit 1
fi

# 4. Vérifier les locks
LOCKS=$(aws dynamodb scan --table-name "$TABLE" --select COUNT --query 'Count')
echo "ℹ️  Locks actifs: $LOCKS"

# 5. Informations state
SIZE=$(aws s3api head-object \
  --bucket "$BUCKET" \
  --key "$ENV/terraform.tfstate" \
  --query 'ContentLength' \
  --output text 2>/dev/null)

if [ -n "$SIZE" ]; then
  echo "ℹ️  Taille state: $(($SIZE / 1024)) KB"
fi

echo "✅ Diagnostic terminé"
```

---

## 📋 Best Practices

### 🔐 Sécurité

- **Chiffrement obligatoire** : Toujours activer `encrypt = true`
- **Accès minimal** : IAM policies restrictives par environnement
- **Versioning activé** : Permettre la récupération en cas d'erreur
- **Logs d'audit** : CloudTrail pour tracer les accès au state

### 🔄 Opérations

- **Backups réguliers** : Automatiser les backups quotidiens
- **Tests de restauration** : Valider les procédures de recovery
- **Monitoring** : Alerter sur les changements inattendus
- **Documentation** : Maintenir les runbooks à jour

### 🚀 Performance

- **Région proche** : Backend dans la même région que l'infrastructure
- **Compression** : State files importants peuvent être compressés
- **Nettoyage** : Supprimer les anciennes versions régulièrement

---

## 🎯 Commandes de Référence

```bash
# State operations courantes
terraform state list                          # Lister les ressources
terraform state show <resource>               # Détails d'une ressource
terraform state pull > state.json            # Télécharger le state
terraform state push state.json              # Uploader le state
terraform refresh                            # Synchroniser avec AWS
terraform import <resource> <aws-id>         # Importer une ressource

# Backend operations
terraform init                               # Initialiser le backend
terraform init -migrate-state               # Migrer vers nouveau backend
terraform init -reconfigure                 # Reconfigurer le backend

# Lock operations
terraform force-unlock <lock-id>            # Débloquer le state
terraform apply -lock=false                 # Ignorer le locking (dangereux)

# Workspace operations (si utilisé)
terraform workspace list                    # Lister les workspaces
terraform workspace select prod             # Changer de workspace
terraform workspace new staging             # Créer nouveau workspace
```

---

**📝 Note :** La gestion du state est critique pour AccessWeaver. Toujours tester les procédures de backup/restore en environnement non-critique avant de les appliquer en production. En cas de doute, créer un backup manuel avant toute opération sur le state.