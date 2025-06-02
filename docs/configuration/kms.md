# 🔐 Configuration KMS - AccessWeaver

Gestion centralisée du chiffrement et des clés pour l'infrastructure AccessWeaver avec AWS Key Management Service.

## 🎯 Vue d'Ensemble

### Stratégie de Chiffrement AccessWeaver

AccessWeaver utilise une approche **defense-in-depth** avec chiffrement à tous les niveaux :

```
🏢 Données Métier (Policies, Permissions, Users)
    ↓ Chiffrement Application (JWT, Tokens)
🔒 Chiffrement Transit (TLS 1.3)
    ↓ 
💾 Chiffrement Stockage (KMS)
    ↓
🗄️ Infrastructure (EBS, S3, RDS, Redis)
```

### Clés KMS par Environnement

| Environnement | Clés Dédiées | Rotation | Utilisation |
|---------------|--------------|----------|-------------|
| **Dev** | 2 clés | 365 jours | RDS + Redis |
| **Staging** | 4 clés | 90 jours | Tous services |
| **Prod** | 6 clés | 30 jours | Granularité maximale |

## 🏗 Architecture des Clés KMS

### Structure Hiérarchique

```
🔑 accessweaver-{env}-master-key (Clé Primaire)
├── 🗄️ accessweaver-{env}-rds-key (PostgreSQL)
├── ⚡ accessweaver-{env}-redis-key (ElastiCache)
├── 📦 accessweaver-{env}-ecs-key (Containers/Logs)
├── 🌐 accessweaver-{env}-s3-key (Backups/Logs)
├── 💿 accessweaver-{env}-ebs-key (Volumes ECS)
└── 🔒 accessweaver-{env}-secrets-key (Secrets Manager)
```

### Policies par Service

| Service | Permissions Requises | Principal |
|---------|---------------------|-----------|
| **RDS** | `kms:Encrypt`, `kms:Decrypt`, `kms:ReEncrypt` | `rds.amazonaws.com` |
| **ElastiCache** | `kms:Encrypt`, `kms:Decrypt`, `kms:GenerateDataKey` | `elasticache.amazonaws.com` |
| **ECS** | `kms:Decrypt`, `kms:DescribeKey` | Task Execution Role |
| **Secrets Manager** | `kms:Encrypt`, `kms:Decrypt`, `kms:GenerateDataKey` | `secretsmanager.amazonaws.com` |

## 🚀 Configuration Terraform

### Variables KMS

```hcl
# variables.tf - Configuration KMS
variable "kms_key_rotation_enabled" {
  description = "Active la rotation automatique des clés KMS"
  type        = bool
  default     = true
}

variable "kms_key_deletion_window" {
  description = "Fenêtre de suppression en jours (7-30)"
  type        = number
  default     = 30
  
  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "La fenêtre de suppression doit être entre 7 et 30 jours."
  }
}

variable "kms_key_usage_policies" {
  description = "Policies d'utilisation des clés par service"
  type = map(object({
    enable_cross_account_access = bool
    allowed_services           = list(string)
    admin_arns                = list(string)
  }))
  default = {}
}
```

### Module KMS Principal

```hcl
# modules/kms/main.tf
locals {
  # Configuration par environnement
  kms_config = {
    dev = {
      keys_to_create = ["master", "rds", "redis"]
      rotation_days  = 365
      deletion_window = 30
    }
    staging = {
      keys_to_create = ["master", "rds", "redis", "ecs", "s3"]
      rotation_days  = 90
      deletion_window = 30
    }
    prod = {
      keys_to_create = ["master", "rds", "redis", "ecs", "s3", "ebs", "secrets"]
      rotation_days  = 30
      deletion_window = 30
    }
  }
  
  current_config = local.kms_config[var.environment]
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Component   = "security"
    ManagedBy   = "terraform"
    Service     = "accessweaver-kms"
  }
}

# Clé Master (obligatoire)
resource "aws_kms_key" "master" {
  description             = "AccessWeaver ${var.environment} Master Encryption Key"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = var.kms_key_rotation_enabled
  
  tags = merge(local.common_tags, {
    Name = "accessweaver-${var.environment}-master-key"
    Type = "master-key"
  })
}

resource "aws_kms_alias" "master" {
  name          = "alias/accessweaver-${var.environment}-master"
  target_key_id = aws_kms_key.master.key_id
}

# Clés spécialisées par service
resource "aws_kms_key" "service_keys" {
  for_each = toset(local.current_config.keys_to_create)
  
  description             = "AccessWeaver ${var.environment} ${each.key} Encryption Key"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = var.kms_key_rotation_enabled
  
  # Policy spécifique selon le service
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      # Administration par les admins Terraform
      {
        Sid    = "EnableAdminAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ], 
    # Policies spécifiques par service
    each.key == "rds" ? [
      {
        Sid    = "AllowRDSAccess"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ] : each.key == "redis" ? [
      {
        Sid    = "AllowElastiCacheAccess"
        Effect = "Allow"
        Principal = {
          Service = "elasticache.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ] : each.key == "ecs" ? [
      {
        Sid    = "AllowECSAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ecs_task_execution_role.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ] : each.key == "secrets" ? [
      {
        Sid    = "AllowSecretsManagerAccess"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ] : [])
  })
  
  tags = merge(local.common_tags, {
    Name = "accessweaver-${var.environment}-${each.key}-key"
    Type = "${each.key}-key"
  })
}

# Alias pour chaque clé service
resource "aws_kms_alias" "service_keys" {
  for_each = aws_kms_key.service_keys
  
  name          = "alias/accessweaver-${var.environment}-${each.key}"
  target_key_id = each.value.key_id
}
```

### Integration avec les Services

#### RDS PostgreSQL

```hcl
# modules/rds/main.tf - Integration KMS
resource "aws_db_instance" "main" {
  # ... autres configurations ...
  
  storage_encrypted = true
  kms_key_id       = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.service_keys["rds"].arn
  
  # Performance Insights avec KMS
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_kms_key_id      = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.service_keys["rds"].arn
  performance_insights_retention_period = 7
}
```

#### ElastiCache Redis

```hcl
# modules/redis/main.tf - Integration KMS
resource "aws_elasticache_replication_group" "main" {
  # ... autres configurations ...
  
  at_rest_encryption_enabled = true
  kms_key_id                = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.service_keys["redis"].arn
  
  transit_encryption_enabled = true
  auth_token                = var.auth_token != null ? var.auth_token : random_password.auth_token[0].result
}
```

#### ECS Fargate avec CloudWatch Logs

```hcl
# modules/ecs/main.tf - Integration KMS
resource "aws_cloudwatch_log_group" "service_logs" {
  for_each = local.accessweaver_services
  
  name              = "/ecs/${var.project_name}-${var.environment}/${each.value.name}"
  retention_in_days = var.log_retention_days
  kms_key_id       = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.service_keys["ecs"].arn
  
  tags = merge(local.common_tags, {
    Service = each.value.name
  })
}
```

## 🔄 Rotation des Clés

### Stratégie de Rotation

```hcl
# Rotation automatique activée par défaut
resource "aws_kms_key" "auto_rotate" {
  enable_key_rotation = true
  
  # Custom rotation schedule pour prod
  rotation_period_in_days = var.environment == "prod" ? 30 : 90
}

# Monitoring des rotations
resource "aws_cloudwatch_metric_alarm" "key_rotation" {
  for_each = aws_kms_key.service_keys
  
  alarm_name          = "kms-key-rotation-${each.key}-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NumberOfRotations"
  namespace           = "AWS/KMS"
  period              = "86400"  # 24 heures
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "KMS key ${each.key} rotation alert"
  
  dimensions = {
    KeyId = each.value.key_id
  }
  
  alarm_actions = [var.sns_topic_arn]
}
```

### Impact de la Rotation

| Service | Impact Rotation | Action Requise |
|---------|----------------|----------------|
| **RDS** | ✅ Transparent | Aucune |
| **ElastiCache** | ✅ Transparent | Aucune |
| **ECS Logs** | ✅ Transparent | Aucune |
| **Secrets Manager** | ⚠️ Redéploiement | Restart services |

## 🛡 Sécurité et Compliance

### Contrôles d'Accès

```hcl
# IAM Policy pour accès KMS développeurs
resource "aws_iam_policy" "developer_kms_access" {
  name = "AccessWeaverDeveloperKMSAccess-${var.environment}"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:DescribeKey",
          "kms:ListKeys",
          "kms:ListAliases"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "rds.${data.aws_region.current.name}.amazonaws.com",
              "elasticache.${data.aws_region.current.name}.amazonaws.com"
            ]
          }
        }
      },
      # Accès decrypt uniquement pour dev
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = aws_kms_key.master.arn
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = data.aws_region.current.name
          }
        }
      }
    ]
  })
}

# Role pour operations équipe
resource "aws_iam_role" "ops_kms_admin" {
  count = var.environment == "prod" ? 1 : 0
  
  name = "AccessWeaverOpsKMSAdmin-${var.environment}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "AccessWeaverOps2024"
          }
        }
      }
    ]
  })
  
  tags = local.common_tags
}
```

### Audit et Logging

```hcl
# CloudTrail pour audit KMS
resource "aws_cloudtrail" "kms_audit" {
  count = var.environment == "prod" ? 1 : 0
  
  name                         = "accessweaver-${var.environment}-kms-audit"
  s3_bucket_name              = aws_s3_bucket.cloudtrail[0].bucket
  include_global_service_events = true
  is_multi_region_trail       = true
  enable_log_file_validation  = true
  
  # Focus sur les événements KMS
  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    exclude_management_event_sources = []
    
    data_resource {
      type   = "AWS::KMS::Key"
      values = ["${aws_kms_key.master.arn}/*"]
    }
  }
  
  tags = merge(local.common_tags, {
    Name = "accessweaver-${var.environment}-kms-audit"
    Type = "security-audit"
  })
}

# S3 Bucket pour CloudTrail
resource "aws_s3_bucket" "cloudtrail" {
  count = var.environment == "prod" ? 1 : 0
  
  bucket        = "accessweaver-${var.environment}-cloudtrail-${random_string.bucket_suffix.result}"
  force_destroy = false
  
  tags = merge(local.common_tags, {
    Name = "accessweaver-${var.environment}-cloudtrail"
    Type = "audit-logs"
  })
}
```

## 📊 Monitoring et Alerting

### Métriques KMS Critiques

```hcl
# Dashboard CloudWatch pour KMS
resource "aws_cloudwatch_dashboard" "kms" {
  dashboard_name = "AccessWeaver-KMS-${var.environment}"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/KMS", "NumberOfRequestsSucceeded", "KeyId", aws_kms_key.master.key_id],
            [".", "NumberOfRequestsFailed", ".", "."],
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "KMS API Requests"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            for key_name, key in aws_kms_key.service_keys : 
            ["AWS/KMS", "NumberOfRequestsSucceeded", "KeyId", key.key_id, { "label" = key_name }]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Service Keys Usage"
        }
      }
    ]
  })
}

# Alarmes critiques
resource "aws_cloudwatch_metric_alarm" "kms_api_errors" {
  alarm_name          = "accessweaver-${var.environment}-kms-api-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NumberOfRequestsFailed"
  namespace           = "AWS/KMS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "KMS API errors are too high"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  
  dimensions = {
    KeyId = aws_kms_key.master.key_id
  }
  
  tags = local.common_tags
}
```

## 💰 Optimisation des Coûts

### Tarification KMS

| Élément | Coût AWS | Impact AccessWeaver |
|---------|----------|-------------------|
| **Clé Customer Managed** | $1/mois/clé | Dev: $2/mois, Prod: $6/mois |
| **Requêtes API** | $0.03/10k requêtes | ~$5-20/mois selon usage |
| **Rotation** | Gratuite | Incluse |

### Stratégies d'Économies

```hcl
# Variables pour optimisation coûts
variable "cost_optimization_enabled" {
  description = "Active les optimisations de coût KMS"
  type        = bool
  default     = true
}

locals {
  # Réduire le nombre de clés en dev
  cost_optimized_keys = var.cost_optimization_enabled && var.environment == "dev" ? 
    ["master", "rds"] : local.current_config.keys_to_create
    
  # Rotation moins fréquente en dev
  rotation_period = var.cost_optimization_enabled && var.environment == "dev" ? 
    365 : local.current_config.rotation_days
}

# Politique de suppression plus courte en dev
resource "aws_kms_key" "cost_optimized" {
  deletion_window_in_days = var.environment == "dev" && var.cost_optimization_enabled ? 7 : 30
}
```

## 🚀 Déploiement et Utilisation

### Configuration par Environnement

```hcl
# environments/dev/main.tf
module "kms" {
  source = "../../modules/kms"
  
  project_name  = "accessweaver"
  environment   = "dev"
  
  # Configuration économique dev
  kms_key_deletion_window = 7
  cost_optimization_enabled = true
  
  sns_topic_arn = null  # Pas d'alerting en dev
}

# environments/prod/main.tf
module "kms" {
  source = "../../modules/kms"
  
  project_name  = "accessweaver"
  environment   = "prod"
  
  # Configuration sécurisée prod
  kms_key_deletion_window = 30
  cost_optimization_enabled = false
  
  # Monitoring complet
  sns_topic_arn = aws_sns_topic.critical_alerts.arn
  
  # Backup des clés (disaster recovery)
  enable_cross_region_backup = true
  backup_regions = ["eu-central-1", "us-west-2"]
}
```

### Outputs pour Intégration

```hcl
# modules/kms/outputs.tf
output "kms_key_arns" {
  description = "ARNs de toutes les clés KMS créées"
  value = merge(
    { master = aws_kms_key.master.arn },
    { for k, v in aws_kms_key.service_keys : k => v.arn }
  )
}

output "kms_key_ids" {
  description = "IDs de toutes les clés KMS créées"
  value = merge(
    { master = aws_kms_key.master.key_id },
    { for k, v in aws_kms_key.service_keys : k => v.key_id }
  )
}

output "kms_aliases" {
  description = "Alias de toutes les clés KMS"
  value = merge(
    { master = aws_kms_alias.master.name },
    { for k, v in aws_kms_alias.service_keys : k => v.name }
  )
}

output "integration_config" {
  description = "Configuration prête pour intégration services"
  value = {
    rds_kms_key_id    = try(aws_kms_key.service_keys["rds"].arn, aws_kms_key.master.arn)
    redis_kms_key_id  = try(aws_kms_key.service_keys["redis"].arn, aws_kms_key.master.arn)
    ecs_kms_key_id    = try(aws_kms_key.service_keys["ecs"].arn, aws_kms_key.master.arn)
    secrets_kms_key_id = try(aws_kms_key.service_keys["secrets"].arn, aws_kms_key.master.arn)
  }
}
```

## 📚 Commandes Utiles

### AWS CLI - Gestion KMS

```bash
# Lister les clés AccessWeaver
aws kms list-aliases --query 'Aliases[?contains(AliasName, `accessweaver`)]'

# Vérifier la rotation d'une clé
aws kms describe-key --key-id alias/accessweaver-prod-master --query 'KeyMetadata.KeyRotationStatus'

# Créer un snapshot manual d'une clé (backup)
aws kms create-key-backup --key-id alias/accessweaver-prod-master --backup-name "manual-backup-$(date +%Y%m%d)"

# Audit des utilisations récentes
aws logs filter-log-events \
  --log-group-name /aws/cloudtrail \
  --filter-pattern "{ $.eventSource = kms.amazonaws.com }" \
  --start-time $(date -d '1 hour ago' +%s)000
```

### Terraform - Commandes KMS

```bash
# Déployer uniquement les clés KMS
terraform apply -target=module.kms

# Vérifier la configuration des clés
terraform show | grep -A 20 "aws_kms_key"

# Récupérer les ARNs des clés
terraform output kms_key_arns
```

## ⚠️ Bonnes Pratiques

### ✅ À Faire
- ✅ **Toujours** activer la rotation automatique
- ✅ **Utiliser** des clés dédiées par service en production
- ✅ **Monitorer** les métriques d'utilisation KMS
- ✅ **Sauvegarder** les clés critiques (cross-region)
- ✅ **Tester** les procédures de recovery régulièrement

### ❌ À Éviter
- ❌ **Jamais** partager une clé entre environnements
- ❌ **Jamais** désactiver CloudTrail pour KMS en production
- ❌ **Éviter** de créer trop de clés en dev (coût)
- ❌ **Ne pas** donner accès administrateur KMS aux applications
- ❌ **Éviter** les suppressions de clés sans période de grâce

### 🔧 Troubleshooting

#### Problème: Service ne peut pas décrypter

```bash
# 1. Vérifier la policy de la clé
aws kms get-key-policy --key-id alias/accessweaver-prod-rds --policy-name default

# 2. Vérifier les permissions du service
aws iam get-role-policy --role-name AccessWeaverECSTaskExecutionRole --policy-name KMSAccess

# 3. Tester l'accès direct
aws kms decrypt --ciphertext-blob fileb://encrypted-file --output text --query Plaintext | base64 --decode
```

#### Problème: Rotation bloquée

```bash
# Vérifier le status de rotation
aws kms describe-key --key-id alias/accessweaver-prod-master --query 'KeyMetadata.{KeyRotationStatus: KeyRotationStatus, NextRotationDate: NextRotationDate}'

# Forcer une rotation (si autorisé)
aws kms rotate-key --key-id alias/accessweaver-prod-master
```

---

## 📞 Support

- **🔧 Issues Techniques** : [GitHub Issues](https://github.com/accessweaver/aw-infrastructure-as-code/issues)
- **📧 Contact Sécurité** : security@accessweaver.com
- **📖 Documentation AWS KMS** : [AWS KMS Documentation](https://docs.aws.amazon.com/kms/)

---

**⚠️ Note Importante** : La gestion des clés KMS est critique pour la sécurité d'AccessWeaver. En cas de doute, consultez l'équipe sécurité avant toute modification en production.