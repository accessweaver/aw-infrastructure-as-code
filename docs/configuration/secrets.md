# 🔐 Secrets par Environnement - AccessWeaver

Gestion sécurisée et automatisée des secrets pour chaque environnement AccessWeaver avec AWS Secrets Manager et intégration KMS.

## 🎯 Vue d'Ensemble

### Stratégie de Gestion des Secrets

AccessWeaver utilise une approche **zero-trust** pour la gestion des secrets :

```
🔒 Secrets Manager (AWS)
├── 🔑 Chiffrement KMS dédié par environnement
├── 🔄 Rotation automatique (30-90 jours)
├── 📋 Versioning automatique
└── 🎯 Injection directe dans ECS (pas d'env variables)
```

### Secrets par Environnement

| Type de Secret | Dev | Staging | Production |
|---------------|-----|---------|------------|
| **Database** | Statique | Auto-rotation 90j | Auto-rotation 30j |
| **Redis** | Généré | Auto-rotation 60j | Auto-rotation 30j |
| **JWT** | Statique | Rotation manuelle | Auto-rotation 30j |
| **API Keys** | Partagés | Dédiés | Dédiés + backup |
| **Certificates** | Self-signed | Let's Encrypt | Commercial CA |

## 🏗 Architecture des Secrets

### Structure Hiérarchique

```
🗂️ accessweaver/
├── 📁 dev/
│   ├── 🗄️ database/
│   │   ├── master-password
│   │   ├── app-username
│   │   └── app-password
│   ├── ⚡ redis/
│   │   └── auth-token
│   ├── 🔐 jwt/
│   │   ├── access-secret
│   │   ├── refresh-secret
│   │   └── expiration-config
│   └── 🌐 external-apis/
│       ├── smtp-credentials
│       └── monitoring-tokens
├── 📁 staging/ (structure identique)
└── 📁 prod/ (structure identique + secrets backup)
```

### Mapping Services → Secrets

| Service ECS | Secrets Requis | Injection Method |
|-------------|----------------|------------------|
| **aw-api-gateway** | JWT secrets, SMTP | Task Definition secrets |
| **aw-pdp-service** | Database, Redis | Task Definition secrets |
| **aw-pap-service** | Database, Redis | Task Definition secrets |
| **aw-tenant-service** | Database, JWT | Task Definition secrets |
| **aw-audit-service** | Database, S3 | Task Definition secrets |

## 🚀 Configuration Terraform

### Variables Secrets

```hcl
# variables.tf - Configuration secrets par environnement
variable "secrets_configuration" {
  description = "Configuration des secrets par environnement"
  type = map(object({
    auto_rotation_enabled = bool
    rotation_days        = number
    replica_regions      = list(string)
    recovery_window_days = number
  }))
  default = {
    dev = {
      auto_rotation_enabled = false
      rotation_days        = 365
      replica_regions      = []
      recovery_window_days = 7
    }
    staging = {
      auto_rotation_enabled = true
      rotation_days        = 90
      replica_regions      = []
      recovery_window_days = 30
    }
    prod = {
      auto_rotation_enabled = true
      rotation_days        = 30
      replica_regions      = ["eu-central-1"]
      recovery_window_days = 30
    }
  }
}

variable "external_secrets" {
  description = "Secrets externes (SMTP, monitoring, etc.)"
  type = map(object({
    description = string
    type       = string # "manual" ou "generated"
    rotation   = bool
  }))
  default = {
    smtp_credentials = {
      description = "SMTP pour notifications AccessWeaver"
      type       = "manual"
      rotation   = false
    }
    monitoring_webhook = {
      description = "Webhook pour alerting (Slack, Teams)"
      type       = "manual" 
      rotation   = false
    }
    backup_encryption_key = {
      description = "Clé pour chiffrement backups"
      type       = "generated"
      rotation   = true
    }
  }
}
```

### Module Secrets Principal

```hcl
# modules/secrets/main.tf
locals {
  # Configuration par environnement
  current_config = var.secrets_configuration[var.environment]
  
  # Secrets de base AccessWeaver
  core_secrets = {
    database = {
      path = "accessweaver/${var.environment}/database"
      secrets = {
        master-password = {
          description = "Mot de passe master PostgreSQL ${var.environment}"
          generate_random = var.master_password == null
          value = var.master_password
          auto_rotation = local.current_config.auto_rotation_enabled
        }
        app-username = {
          description = "Username application PostgreSQL ${var.environment}" 
          generate_random = false
          value = "aw_app_${var.environment}"
          auto_rotation = false
        }
        app-password = {
          description = "Mot de passe application PostgreSQL ${var.environment}"
          generate_random = true
          auto_rotation = local.current_config.auto_rotation_enabled
        }
      }
    }
    redis = {
      path = "accessweaver/${var.environment}/redis"
      secrets = {
        auth-token = {
          description = "Token d'authentification Redis ${var.environment}"
          generate_random = var.redis_auth_token == null
          value = var.redis_auth_token
          auto_rotation = local.current_config.auto_rotation_enabled
        }
      }
    }
    jwt = {
      path = "accessweaver/${var.environment}/jwt"
      secrets = {
        access-secret = {
          description = "Secret JWT pour tokens d'accès ${var.environment}"
          generate_random = true
          auto_rotation = local.current_config.auto_rotation_enabled
        }
        refresh-secret = {
          description = "Secret JWT pour tokens de refresh ${var.environment}"
          generate_random = true  
          auto_rotation = local.current_config.auto_rotation_enabled
        }
        expiration-config = {
          description = "Configuration expiration JWT ${var.environment}"
          generate_random = false
          value = jsonencode({
            access_token_ttl  = var.environment == "prod" ? 900 : 3600    # 15min prod, 1h dev
            refresh_token_ttl = var.environment == "prod" ? 86400 : 604800 # 1j prod, 7j dev
            remember_me_ttl   = 2592000 # 30 jours
          })
          auto_rotation = false
        }
      }
    }
  }
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Component   = "security"
    ManagedBy   = "terraform"
    Service     = "accessweaver-secrets"
  }
}

# Génération des mots de passe sécurisés
resource "random_password" "generated_secrets" {
  for_each = {
    for secret_group_key, secret_group in local.core_secrets :
    for secret_key, secret in secret_group.secrets :
    "${secret_group_key}_${secret_key}" => secret
    if secret.generate_random
  }
  
  length  = 32
  special = true
  
  # Éviter les caractères problématiques
  override_special = "!#$%&*()-_=+[]{}<>:?"
  
  # Critères de complexité
  min_lower   = 4
  min_upper   = 4  
  min_numeric = 4
  min_special = 2
}

# Secrets AWS Secrets Manager
resource "aws_secretsmanager_secret" "core_secrets" {
  for_each = {
    for secret_group_key, secret_group in local.core_secrets :
    for secret_key, secret in secret_group.secrets :
    "${secret_group_key}_${secret_key}" => {
      path   = "${secret_group.path}/${secret_key}"
      config = secret
      group  = secret_group_key
    }
  }
  
  name        = each.value.path
  description = each.value.config.description
  
  # KMS key dédiée secrets
  kms_key_id = var.kms_key_id != null ? var.kms_key_id : "alias/accessweaver-${var.environment}-secrets"
  
  # Configuration de récupération
  recovery_window_in_days = local.current_config.recovery_window_days
  
  # Réplication cross-region pour prod
  dynamic "replica" {
    for_each = local.current_config.replica_regions
    content {
      region     = replica.value
      kms_key_id = "alias/accessweaver-${var.environment}-secrets"
    }
  }
  
  tags = merge(local.common_tags, {
    Name = each.value.path
    Type = each.value.group
    AutoRotation = tostring(each.value.config.auto_rotation)
  })
}

# Valeurs des secrets
resource "aws_secretsmanager_secret_version" "core_secrets" {
  for_each = aws_secretsmanager_secret.core_secrets
  
  secret_id = each.value.id
  
  secret_string = local.core_secrets[split("_", each.key)[0]].secrets[split("_", each.key)[1]].generate_random ? 
    random_password.generated_secrets[each.key].result :
    local.core_secrets[split("_", each.key)[0]].secrets[split("_", each.key)[1]].value
  
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Configuration de rotation automatique
resource "aws_secretsmanager_secret_rotation" "auto_rotation" {
  for_each = {
    for k, v in aws_secretsmanager_secret.core_secrets :
    k => v if local.core_secrets[split("_", k)[0]].secrets[split("_", k)[1]].auto_rotation
  }
  
  secret_id           = each.value.id
  rotation_lambda_arn = aws_lambda_function.secret_rotation[split("_", each.key)[0]].arn
  
  rotation_rules {
    automatically_after_days = local.current_config.rotation_days
  }
  
  depends_on = [aws_lambda_permission.allow_secret_manager_call_Lambda]
}
```

### Lambda Functions pour Rotation

```hcl
# Lambda pour rotation des secrets database
resource "aws_lambda_function" "secret_rotation" {
  for_each = toset(["database", "redis", "jwt"])
  
  filename         = data.archive_file.rotation_lambda[each.key].output_path
  function_name    = "accessweaver-${var.environment}-${each.key}-rotation"
  role            = aws_iam_role.lambda_rotation_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.rotation_lambda[each.key].output_base64sha256
  runtime         = "python3.9"
  timeout         = 30
  
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda_rotation.id]
  }
  
  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${data.aws_region.current.name}.amazonaws.com"
      EXCLUDE_CHARACTERS       = "\"@/\\"
      ENVIRONMENT             = var.environment
      SERVICE_TYPE            = each.key
    }
  }
  
  tags = merge(local.common_tags, {
    Name = "accessweaver-${var.environment}-${each.key}-rotation"
    Type = "secret-rotation"
  })
}

# Code source Lambda (exemple pour database)
data "archive_file" "rotation_lambda" {
  for_each = toset(["database", "redis", "jwt"])
  
  type        = "zip"
  output_path = "/tmp/${each.key}_rotation_lambda.zip"
  
  source {
    content = templatefile("${path.module}/lambda/${each.key}_rotation.py", {
      environment = var.environment
    })
    filename = "lambda_function.py"
  }
}

# Permissions Lambda
resource "aws_lambda_permission" "allow_secret_manager_call_Lambda" {
  for_each = aws_lambda_function.secret_rotation
  
  statement_id  = "AllowExecutionFromSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "secretsmanager.amazonaws.com"
}

# IAM Role pour Lambda
resource "aws_iam_role" "lambda_rotation_role" {
  name = "accessweaver-${var.environment}-lambda-rotation-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}
```

### Intégration ECS Task Definitions

```hcl
# modules/ecs/secrets_integration.tf
locals {
  # Mapping des secrets pour chaque service
  service_secrets = {
    "aw-api-gateway" = [
      {
        name      = "JWT_ACCESS_SECRET"
        valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:accessweaver/${var.environment}/jwt/access-secret"
      },
      {
        name      = "JWT_REFRESH_SECRET"  
        valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:accessweaver/${var.environment}/jwt/refresh-secret"
      },
      {
        name      = "JWT_CONFIG"
        valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:accessweaver/${var.environment}/jwt/expiration-config"
      }
    ]
    
    "aw-pdp-service" = [
      {
        name      = "DATABASE_PASSWORD"
        valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:accessweaver/${var.environment}/database/app-password"
      },
      {
        name      = "REDIS_AUTH_TOKEN"
        valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:accessweaver/${var.environment}/redis/auth-token"
      }
    ]
    
    "aw-pap-service" = [
      {
        name      = "DATABASE_PASSWORD"
        valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:accessweaver/${var.environment}/database/app-password"
      },
      {
        name      = "REDIS_AUTH_TOKEN"
        valueFrom = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:accessweaver/${var.environment}/redis/auth-token"
      }
    ]
  }
}

# Task Definition avec secrets
resource "aws_ecs_task_definition" "services" {
  for_each = local.accessweaver_services
  
  family = "${var.project_name}-${var.environment}-${each.value.name}"
  # ... autres configurations ...
  
  container_definitions = jsonencode([
    {
      name  = each.value.name
      image = "${var.container_registry}/${each.value.name}:${var.image_tag}"
      
      # Variables d'environnement publiques
      environment = [
        for key, value in merge(
          var.common_environment_variables,
          each.value.environment_variables
        ) : {
          name  = key
          value = value
        }
      ]
      
      # Secrets depuis AWS Secrets Manager
      secrets = try(local.service_secrets[each.value.name], [])
      
      # ... autres configurations container ...
    }
  ])
}
```

## 🔄 Rotation des Secrets

### Stratégies par Type de Secret

#### Database Secrets (PostgreSQL)

```python
# lambda/database_rotation.py
import boto3
import json
import logging
import os
import psycopg2

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """Rotation automatique des mots de passe PostgreSQL"""
    
    client = boto3.client('secretsmanager')
    secret_arn = event['SecretId']
    token = event['ClientRequestToken']
    step = event['Step']
    
    # Récupérer les métadonnées du secret
    metadata = client.describe_secret(SecretId=secret_arn)
    
    if step == "createSecret":
        create_secret(client, secret_arn, token)
    elif step == "setSecret":
        set_secret(client, secret_arn, token)
    elif step == "testSecret":
        test_secret(client, secret_arn, token)
    elif step == "finishSecret":
        finish_secret(client, secret_arn, token)
    
    return {"message": f"Secret rotation {step} completed successfully"}

def create_secret(client, secret_arn, token):
    """Créer nouvelle version du secret"""
    try:
        client.get_secret_value(SecretId=secret_arn, VersionStage="AWSPENDING")
        logger.info("Secret already exists for AWSPENDING")
        return
    except client.exceptions.ResourceNotFoundException:
        pass
    
    # Générer nouveau mot de passe
    new_password = client.get_random_password(
        PasswordLength=32,
        ExcludeCharacters="\"@/\\",
        ExcludePunctuation=False
    )['RandomPassword']
    
    # Récupérer secret actuel
    current_secret = json.loads(
        client.get_secret_value(SecretId=secret_arn, VersionStage="AWSCURRENT")['SecretString']
    )
    
    # Créer nouvelle version
    new_secret = current_secret.copy()
    new_secret['password'] = new_password
    
    client.put_secret_value(
        SecretId=secret_arn,
        SecretString=json.dumps(new_secret),
        VersionStages=['AWSPENDING'],
        ClientRequestToken=token
    )
    
    logger.info("New secret created successfully")

def set_secret(client, secret_arn, token):
    """Appliquer le nouveau secret en base"""
    pending_secret = json.loads(
        client.get_secret_value(SecretId=secret_arn, VersionStage="AWSPENDING")['SecretString']
    )
    
    current_secret = json.loads(
        client.get_secret_value(SecretId=secret_arn, VersionStage="AWSCURRENT")['SecretString']
    )
    
    # Connexion avec ancien mot de passe
    conn = psycopg2.connect(
        host=current_secret['host'],
        port=current_secret['port'],
        dbname=current_secret['dbname'],
        user=current_secret['username'],
        password=current_secret['password']
    )
    
    # Changer le mot de passe
    with conn.cursor() as cursor:
        cursor.execute(
            "ALTER USER %s PASSWORD %s",
            (pending_secret['username'], pending_secret['password'])
        )
    
    conn.commit()
    conn.close()
    
    logger.info("Password updated in database")

def test_secret(client, secret_arn, token):
    """Tester la connexion avec nouveau secret"""
    pending_secret = json.loads(
        client.get_secret_value(SecretId=secret_arn, VersionStage="AWSPENDING")['SecretString']
    )
    
    # Test de connexion
    conn = psycopg2.connect(
        host=pending_secret['host'],
        port=pending_secret['port'],
        dbname=pending_secret['dbname'],
        user=pending_secret['username'],
        password=pending_secret['password']
    )
    
    # Test query simple
    with conn.cursor() as cursor:
        cursor.execute("SELECT 1")
        result = cursor.fetchone()
        
    conn.close()
    
    if result[0] != 1:
        raise Exception("Test query failed")
    
    logger.info("Secret tested successfully")

def finish_secret(client, secret_arn, token):
    """Finaliser la rotation"""
    client.update_secret_version_stage(
        SecretId=secret_arn,
        VersionStage="AWSCURRENT",
        ClientRequestToken=token,
        RemoveFromVersionId=client.describe_secret(SecretId=secret_arn)['VersionIdsToStages'].get('AWSCURRENT', [None])[0]
    )
    
    logger.info("Secret rotation completed")
```

#### Redis Auth Token Rotation

```python
# lambda/redis_rotation.py
import boto3
import json
import logging
import redis

def lambda_handler(event, context):
    """Rotation token Redis avec zero-downtime"""
    
    client = boto3.client('secretsmanager')
    secret_arn = event['SecretId']
    token = event['ClientRequestToken']
    step = event['Step']
    
    if step == "createSecret":
        create_redis_token(client, secret_arn, token)
    elif step == "setSecret":
        set_redis_token(client, secret_arn, token)
    elif step == "testSecret":
        test_redis_token(client, secret_arn, token)
    elif step == "finishSecret":
        finish_redis_rotation(client, secret_arn, token)

def create_redis_token(client, secret_arn, token):
    """Générer nouveau token Redis"""
    new_token = client.get_random_password(
        PasswordLength=64,
        ExcludeCharacters="\"'\\/@",
        ExcludePunctuation=False
    )['RandomPassword']
    
    current_secret = json.loads(
        client.get_secret_value(SecretId=secret_arn, VersionStage="AWSCURRENT")['SecretString']
    )
    
    new_secret = current_secret.copy()
    new_secret['auth_token'] = new_token
    
    client.put_secret_value(
        SecretId=secret_arn,
        SecretString=json.dumps(new_secret),
        VersionStages=['AWSPENDING'],
        ClientRequestToken=token
    )

def set_redis_token(client, secret_arn, token):
    """Configurer nouveau token sur ElastiCache"""
    # Note: Pour ElastiCache, la rotation nécessite 
    # un redémarrage du cluster (maintenance window)
    
    pending_secret = json.loads(
        client.get_secret_value(SecretId=secret_arn, VersionStage="AWSPENDING")['SecretString']
    )
    
    # Update ElastiCache auth token via boto3
    elasticache = boto3.client('elasticache')
    
    elasticache.modify_replication_group(
        ReplicationGroupId=pending_secret['cluster_id'],
        AuthToken=pending_secret['auth_token'],
        AuthTokenUpdateStrategy='ROTATE'  # Zero-downtime pour Redis 6.2+
    )
    
    # Attendre que la modification soit appliquée
    waiter = elasticache.get_waiter('replication_group_modified')
    waiter.wait(ReplicationGroupId=pending_secret['cluster_id'])
```

### Monitoring des Rotations

```hcl
# CloudWatch Alarms pour rotation
resource "aws_cloudwatch_metric_alarm" "secret_rotation_failed" {
  for_each = aws_secretsmanager_secret.core_secrets
  
  alarm_name          = "secret-rotation-failed-${replace(each.key, "_", "-")}-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RotationFailed"
  namespace           = "AWS/SecretsManager"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Secret rotation failed for ${each.value.name}"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    SecretName = each.value.name
  }
  
  alarm_actions = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  
  tags = local.common_tags
}

# Dashboard pour monitoring secrets
resource "aws_cloudwatch_dashboard" "secrets_monitoring" {
  dashboard_name = "AccessWeaver-Secrets-${var.environment}"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            for secret_name, secret in aws_secretsmanager_secret.core_secrets :
            ["AWS/SecretsManager", "SuccessfulRotations", "SecretName", secret.name]
          ]
          period = 3600
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Secret Rotations"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            for secret_name, secret in aws_secretsmanager_secret.core_secrets :
            ["AWS/SecretsManager", "RotationFailed", "SecretName", secret.name]
          ]
          period = 3600
          stat   = "Sum" 
          region = data.aws_region.current.name
          title  = "Failed Rotations"
        }
      }
    ]
  })
}
```

## 🏭 Configuration par Environnement

### Development

```hcl
# environments/dev/secrets.tf
module "secrets" {
  source = "../../modules/secrets"
  
  project_name = "accessweaver"
  environment  = "dev"
  
  # Configuration développement
  secrets_configuration = {
    dev = {
      auto_rotation_enabled = false  # Rotation manuelle
      rotation_days        = 365     # 1 an
      replica_regions      = []      # Pas de réplication
      recovery_window_days = 7       # Récupération rapide
    }
  }
  
  # Secrets statiques pour dev (facilite debug)
  master_password    = "DevPassword123!"
  redis_auth_token   = "DevRedisToken123456"
  
  # KMS key dédiée dev
  kms_key_id = module.kms.kms_key_arns["master"]
  
  # Pas d'alerting en dev
  sns_topic_arn = null
  
  tags = {
    CostCenter = "Development"
    Purpose    = "development-secrets"
  }
}
```

### Staging

```hcl
# environments/staging/secrets.tf
module "secrets" {
  source = "../../modules/secrets"
  
  project_name = "accessweaver"
  environment  = "staging"
  
  # Configuration staging - rotation modérée
  secrets_configuration = {
    staging = {
      auto_rotation_enabled = true
      rotation_days        = 90      # 3 mois
      replica_regions      = []      # Pas de réplication
      recovery_window_days = 30
    }
  }
  
  # Génération automatique
  master_password    = null  # Auto-généré
  redis_auth_token   = null  # Auto-généré
  
  # KMS key dédiée staging
  kms_key_id = module.kms.kms_key_arns["secrets"]
  
  # Alerting modéré
  sns_topic_arn = aws_sns_topic.staging_alerts.arn
  
  # Secrets externes pour tests
  external_secrets = {
    test_smtp = {
      description = "SMTP test pour staging"
      type       = "manual"
      rotation   = false
    }
  }
}
```

### Production

```hcl
# environments/prod/secrets.tf
module "secrets" {
  source = "../../modules/secrets"
  
  project_name = "accessweaver"
  environment  = "prod"
  
  # Configuration production - sécurité maximale
  secrets_configuration = {
    prod = {
      auto_rotation_enabled = true
      rotation_days        = 30       # 1 mois
      replica_regions      = ["eu-central-1", "us-west-2"]  # Backup multi-région
      recovery_window_days = 30
    }
  }
  
  # Génération automatique + haute entropie
  master_password    = null  # Auto-généré 32 chars
  redis_auth_token   = null  # Auto-généré 64 chars
  
  # KMS key dédiée avec rotation fréquente
  kms_key_id = module.kms.kms_key_arns["secrets"]
  
  # Alerting critique
  sns_topic_arn = aws_sns_topic.critical_alerts.arn
  
  # Secrets externes production
  external_secrets = {
    smtp_production = {
      description = "SMTP SendGrid production"
      type       = "manual"
      rotation   = true
    }
    backup_encryption_key = {
      description = "Clé chiffrement backups S3"
      type       = "generated"
      rotation   = true
    }
    api_gateway_certificates = {
      description = "Certificats API Gateway"
      type       = "manual"
      rotation   = true
    }
  }
  
  # Backup cross-account pour disaster recovery
  enable_cross_account_backup = true
  backup_account_id = "123456789012"
}
```

## 🔍 Utilisation dans le Code

### Configuration Spring Boot

```yaml
# application-{env}.yml - Configuration secrets
spring:
  datasource:
    primary:
      # Variables injectées par ECS depuis Secrets Manager
      url: jdbc:postgresql://${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_NAME}
      username: ${DATABASE_USERNAME}
      password: ${DATABASE_PASSWORD}  # Depuis Secrets Manager
      driver-class-name: org.postgresql.Driver
      
  redis:
    host: ${REDIS_HOST}
    port: ${REDIS_PORT}
    password: ${REDIS_AUTH_TOKEN}  # Depuis Secrets Manager
    
# Configuration JWT AccessWeaver
accessweaver:
  security:
    jwt:
      access:
        secret: ${JWT_ACCESS_SECRET}    # Depuis Secrets Manager
        expiration: ${JWT_ACCESS_TTL}   # Depuis config JSON
      refresh:
        secret: ${JWT_REFRESH_SECRET}   # Depuis Secrets Manager  
        expiration: ${JWT_REFRESH_TTL}  # Depuis config JSON
```

### Service Java pour Gestion Secrets

```java
@Service
@Slf4j
public class SecretsService {
    
    private final AWSSecretsManager secretsManager;
    private final ObjectMapper objectMapper;
    
    @Value("${accessweaver.environment}")
    private String environment;
    
    @Cacheable(value = "secrets", key = "#secretPath")
    public String getSecret(String secretPath) {
        try {
            GetSecretValueRequest request = new GetSecretValueRequest()
                .withSecretId(buildSecretArn(secretPath));
                
            GetSecretValueResult result = secretsManager.getSecretValue(request);
            return result.getSecretString();
            
        } catch (Exception e) {
            log.error("Failed to retrieve secret: {}", secretPath, e);
            throw new SecretRetrievalException("Cannot retrieve secret: " + secretPath);
        }
    }
    
    public JwtConfiguration getJwtConfiguration() {
        try {
            String configJson = getSecret("jwt/expiration-config");
            return objectMapper.readValue(configJson, JwtConfiguration.class);
        } catch (Exception e) {
            log.error("Failed to parse JWT configuration", e);
            throw new ConfigurationException("Invalid JWT configuration");
        }
    }
    
    @EventListener
    public void onSecretRotation(SecretRotationEvent event) {
        log.info("Secret rotated: {}, clearing cache", event.getSecretPath());
        cacheManager.getCache("secrets").evict(event.getSecretPath());
        
        // Notifier les services concernés
        applicationEventPublisher.publishEvent(
            new SecretUpdatedEvent(event.getSecretPath())
        );
    }
    
    private String buildSecretArn(String secretPath) {
        return String.format("accessweaver/%s/%s", environment, secretPath);
    }
}

@Data
public class JwtConfiguration {
    private int accessTokenTtl;
    private int refreshTokenTtl;  
    private int rememberMeTtl;
}
```

### Health Check avec Secrets

```java
@Component
public class SecretsHealthIndicator implements HealthIndicator {
    
    private final SecretsService secretsService;
    
    @Override
    public Health health() {
        try {
            // Test accès aux secrets critiques
            secretsService.getSecret("database/app-password");
            secretsService.getSecret("redis/auth-token");
            
            return Health.up()
                .withDetail("secrets", "accessible")
                .withDetail("lastCheck", Instant.now())
                .build();
                
        } catch (Exception e) {
            return Health.down()
                .withDetail("error", e.getMessage())
                .withDetail("secrets", "inaccessible")
                .build();
        }
    }
}
```

## 📊 Monitoring et Alerting

### Métriques Personnalisées

```java
@Component
public class SecretsMetrics {
    
    private final MeterRegistry meterRegistry;
    private final Counter secretRetrievalCounter;
    private final Timer secretRetrievalTimer;
    
    public SecretsMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
        this.secretRetrievalCounter = Counter.builder("accessweaver.secrets.retrieval")
            .description("Number of secret retrievals")
            .register(meterRegistry);
        this.secretRetrievalTimer = Timer.builder("accessweaver.secrets.retrieval.duration")
            .description("Secret retrieval duration")
            .register(meterRegistry);
    }
    
    @EventListener
    public void onSecretAccess(SecretAccessEvent event) {
        secretRetrievalCounter.increment(
            Tags.of(
                "secret_type", event.getSecretType(),
                "environment", event.getEnvironment(),
                "success", String.valueOf(event.isSuccess())
            )
        );
    }
    
    @Scheduled(fixedDelay = 300000) // 5 minutes
    public void collectSecretMetrics() {
        // Vérifier l'âge des secrets
        Arrays.asList("database", "redis", "jwt").forEach(secretType -> {
            try {
                String secretArn = String.format("accessweaver/%s/%s/master-password", 
                    environment, secretType);
                    
                DescribeSecretRequest request = new DescribeSecretRequest()
                    .withSecretId(secretArn);
                DescribeSecretResult result = secretsManager.describeSecret(request);
                
                Date lastRotated = result.getLastRotatedDate();
                if (lastRotated != null) {
                    long daysSinceRotation = ChronoUnit.DAYS.between(
                        lastRotated.toInstant(), Instant.now());
                        
                    Gauge.builder("accessweaver.secrets.days_since_rotation")
                        .description("Days since last secret rotation")
                        .tags("secret_type", secretType)
                        .register(meterRegistry, () -> daysSinceRotation);
                }
                
            } catch (Exception e) {
                log.warn("Failed to collect metrics for secret type: {}", secretType, e);
            }
        });
    }
}
```

### Alerting Avancé

```hcl
# Alertes personnalisées Secrets Manager
resource "aws_cloudwatch_metric_alarm" "secret_not_rotated" {
  for_each = aws_secretsmanager_secret.core_secrets
  
  alarm_name          = "secret-not-rotated-${replace(each.key, "_", "-")}-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  
  # Alarme si pas de rotation depuis X jours
  metric_query {
    id = "secret_age"
    
    metric {
      metric_name = "DaysSinceRotation"
      namespace   = "AWS/SecretsManager"
      period      = 86400  # 1 jour
      stat        = "Maximum"
      
      dimensions = {
        SecretName = each.value.name
      }
    }
  }
  
  threshold         = local.current_config.rotation_days + 7  # 7 jours de grâce
  alarm_description = "Secret ${each.value.name} not rotated for too long"
  alarm_actions     = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  
  tags = merge(local.common_tags, {
    AlertType = "SecretRotation"
    Severity  = "High"
  })
}

# Alarme accès suspects aux secrets
resource "aws_cloudwatch_log_metric_filter" "suspicious_secret_access" {
  name           = "accessweaver-${var.environment}-suspicious-secret-access"
  log_group_name = "/aws/lambda/accessweaver-${var.environment}-secret-rotation"
  
  pattern = "[timestamp, request_id, level=\"ERROR\", message=\"*authentication*failed*\"]"
  
  metric_transformation {
    name      = "SuspiciousSecretAccess"
    namespace = "AccessWeaver/Security"
    value     = "1"
    
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "suspicious_secret_access_alarm" {
  alarm_name          = "accessweaver-${var.environment}-suspicious-secret-access"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "SuspiciousSecretAccess"
  namespace           = "AccessWeaver/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Suspicious access attempts to secrets detected"
  treat_missing_data  = "notBreaching"
  
  alarm_actions = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  
  tags = merge(local.common_tags, {
    AlertType = "Security"
    Severity  = "Critical"
  })
}
```

## 💰 Optimisation des Coûts

### Tarification Secrets Manager

| Élément | Coût AWS | Impact AccessWeaver |
|---------|----------|-------------------|
| **Secret stocké** | $0.40/mois/secret | Dev: $2/mois, Prod: $8/mois |
| **Requêtes API** | $0.05/10k requêtes | ~$5-15/mois selon usage |
| **Rotation Lambda** | Coût Lambda standard | ~$1-5/mois |
| **Réplication cross-region** | +$0.40/secret/région | Prod uniquement |

### Stratégies d'Économies

```hcl
# Variables d'optimisation coût
variable "cost_optimization" {
  description = "Optimisations de coût pour Secrets Manager"
  type = object({
    reduce_dev_secrets     = bool
    disable_dev_rotation   = bool  
    shared_staging_secrets = bool
    lambda_memory_optimization = bool
  })
  default = {
    reduce_dev_secrets     = true
    disable_dev_rotation   = true
    shared_staging_secrets = false
    lambda_memory_optimization = true
  }
}

locals {
  # Secrets minimum en dev
  cost_optimized_secrets = var.cost_optimization.reduce_dev_secrets && var.environment == "dev" ? 
    {
      database = local.core_secrets.database
      redis    = local.core_secrets.redis  
    } : local.core_secrets
    
  # Pas de réplication en dev/staging
  replica_regions = var.environment == "prod" ? local.current_config.replica_regions : []
}

# Lambda avec mémoire optimisée
resource "aws_lambda_function" "secret_rotation_optimized" {
  for_each = local.cost_optimized_secrets
  
  memory_size = var.cost_optimization.lambda_memory_optimization ? 128 : 256
  timeout     = var.cost_optimization.lambda_memory_optimization ? 30 : 60
  
  # Reserved concurrency pour éviter les coûts de démarrage fréquents
  reserved_concurrent_executions = var.environment == "prod" ? 2 : 1
}
```

### Cache Local pour Réduire les Appels API

```java
@Configuration
@EnableCaching
public class SecretsCacheConfig {
    
    @Bean
    public CacheManager secretsCacheManager() {
        CaffeineCacheManager cacheManager = new CaffeineCacheManager("secrets");
        
        // Configuration adaptée à l'environnement
        int cacheTtlMinutes = getEnvironmentSpecificTtl();
        
        cacheManager.setCaffeine(Caffeine.newBuilder()
            .maximumSize(100)  // Max 100 secrets en cache
            .expireAfterWrite(Duration.ofMinutes(cacheTtlMinutes))
            .recordStats());
            
        return cacheManager;
    }
    
    private int getEnvironmentSpecificTtl() {
        String env = System.getenv("SPRING_PROFILES_ACTIVE");
        return switch (env) {
            case "prod" -> 5;      // 5 min en prod (sécurité)
            case "staging" -> 15;  // 15 min en staging
            default -> 60;        // 1h en dev (économique)
        };
    }
}
```

## 🛠 Scripts de Gestion

### Création des Secrets Initiaux

```bash
#!/bin/bash
# scripts/setup-secrets.sh - Initialisation des secrets par environnement

set -e

ENV=${1:-dev}
REGION=${2:-eu-west-1}
PROJECT="accessweaver"

echo "🔐 Setting up secrets for environment: $ENV"

# Function to create secret if not exists
create_secret_if_not_exists() {
    local secret_name=$1
    local secret_value=$2
    local description=$3
    
    if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$REGION" &>/dev/null; then
        echo "⚠️  Secret $secret_name already exists, skipping..."
    else
        echo "🆕 Creating secret: $secret_name"
        aws secretsmanager create-secret \
            --name "$secret_name" \
            --description "$description" \
            --secret-string "$secret_value" \
            --region "$REGION" \
            --kms-key-id "alias/$PROJECT-$ENV-secrets"
        echo "✅ Secret created: $secret_name"
    fi
}

# Database secrets
echo "📊 Setting up database secrets..."
if [ "$ENV" = "dev" ]; then
    DB_PASSWORD="DevPassword123!"
else
    DB_PASSWORD=$(openssl rand -base64 32)
fi

create_secret_if_not_exists \
    "$PROJECT/$ENV/database/master-password" \
    "$DB_PASSWORD" \
    "Master password for PostgreSQL $ENV environment"

create_secret_if_not_exists \
    "$PROJECT/$ENV/database/app-password" \
    "$(openssl rand -base64 32)" \
    "Application password for PostgreSQL $ENV environment"

# Redis secrets
echo "⚡ Setting up Redis secrets..."
if [ "$ENV" = "dev" ]; then
    REDIS_TOKEN="DevRedisToken123456"
else
    REDIS_TOKEN=$(openssl rand -base64 48)
fi

create_secret_if_not_exists \
    "$PROJECT/$ENV/redis/auth-token" \
    "$REDIS_TOKEN" \
    "Authentication token for Redis $ENV environment"

# JWT secrets
echo "🔑 Setting up JWT secrets..."
create_secret_if_not_exists \
    "$PROJECT/$ENV/jwt/access-secret" \
    "$(openssl rand -base64 64)" \
    "JWT access token secret for $ENV environment"

create_secret_if_not_exists \
    "$PROJECT/$ENV/jwt/refresh-secret" \
    "$(openssl rand -base64 64)" \
    "JWT refresh token secret for $ENV environment"

# JWT configuration
JWT_CONFIG=$(cat <<EOF
{
    "access_token_ttl": $([ "$ENV" = "prod" ] && echo 900 || echo 3600),
    "refresh_token_ttl": $([ "$ENV" = "prod" ] && echo 86400 || echo 604800),
    "remember_me_ttl": 2592000
}
EOF
)

create_secret_if_not_exists \
    "$PROJECT/$ENV/jwt/expiration-config" \
    "$JWT_CONFIG" \
    "JWT expiration configuration for $ENV environment"

echo "🎉 All secrets configured successfully for $ENV environment!"
echo ""
echo "📋 Next steps:"
echo "  1. Run: terraform apply"
echo "  2. Verify secrets: aws secretsmanager list-secrets --region $REGION"
echo "  3. Test ECS deployment with new secrets"
```

### Rotation Manuelle

```bash
#!/bin/bash
# scripts/rotate-secret.sh - Rotation manuelle d'un secret

SECRET_ARN=$1
ENVIRONMENT=$2

if [ -z "$SECRET_ARN" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <secret-arn> <environment>"
    exit 1
fi

echo "🔄 Starting manual rotation for: $SECRET_ARN"

# Déclencher la rotation
aws secretsmanager rotate-secret \
    --secret-id "$SECRET_ARN" \
    --rotation-lambda-arn "arn:aws:lambda:eu-west-1:$(aws sts get-caller-identity --query Account --output text):function:accessweaver-$ENVIRONMENT-database-rotation"

echo "✅ Rotation triggered successfully"
echo "⏳ Monitor rotation status with:"
echo "aws secretsmanager describe-secret --secret-id '$SECRET_ARN' --query 'RotationEnabled'"
```

### Backup Cross-Region

```bash
#!/bin/bash
# scripts/backup-secrets.sh - Backup des secrets vers autre région

SOURCE_REGION=${1:-eu-west-1}
BACKUP_REGION=${2:-eu-central-1}
ENVIRONMENT=${3:-prod}

echo "💾 Backing up secrets from $SOURCE_REGION to $BACKUP_REGION"

# Lister tous les secrets AccessWeaver
SECRETS=$(aws secretsmanager list-secrets \
    --region "$SOURCE_REGION" \
    --query "SecretList[?contains(Name, 'accessweaver/$ENVIRONMENT')].Name" \
    --output text)

for secret_name in $SECRETS; do
    echo "📦 Backing up: $secret_name"
    
    # Récupérer la valeur du secret
    SECRET_VALUE=$(aws secretsmanager get-secret-value \
        --secret-id "$secret_name" \
        --region "$SOURCE_REGION" \
        --query 'SecretString' \
        --output text)
    
    # Créer ou mettre à jour dans la région de backup
    BACKUP_SECRET_NAME="${secret_name}-backup"
    
    if aws secretsmanager describe-secret \
        --secret-id "$BACKUP_SECRET_NAME" \
        --region "$BACKUP_REGION" &>/dev/null; then
        
        aws secretsmanager update-secret \
            --secret-id "$BACKUP_SECRET_NAME" \
            --secret-string "$SECRET_VALUE" \
            --region "$BACKUP_REGION"
    else
        aws secretsmanager create-secret \
            --name "$BACKUP_SECRET_NAME" \
            --description "Backup of $secret_name from $SOURCE_REGION" \
            --secret-string "$SECRET_VALUE" \
            --region "$BACKUP_REGION"
    fi
    
    echo "✅ Backed up: $secret_name"
done

echo "🎉 All secrets backed up successfully to $BACKUP_REGION"
```

## 📚 Troubleshooting

### Problèmes Courants

#### 1. ECS Task ne peut pas accéder aux secrets

```bash
# Vérifier les permissions IAM de la task execution role
aws iam get-role-policy \
    --role-name accessweaver-prod-ecs-task-execution-role \
    --policy-name SecretsManagerAccess

# Vérifier que le secret existe
aws secretsmanager describe-secret \
    --secret-id "accessweaver/prod/database/app-password"

# Tester l'accès depuis une tâche ECS
aws ecs execute-command \
    --cluster accessweaver-prod-cluster \
    --task TASK_ID \
    --container aw-api-gateway \
    --interactive \
    --command "echo \$DATABASE_PASSWORD"
```

#### 2. Rotation échoue

```bash
# Vérifier les logs Lambda de rotation
aws logs tail /aws/lambda/accessweaver-prod-database-rotation --follow

# Vérifier le statut de rotation
aws secretsmanager describe-secret \
    --secret-id "accessweaver/prod/database/master-password" \
    --query 'RotationEnabled'

# Redéclencher manuellement
aws secretsmanager rotate-secret \
    --secret-id "accessweaver/prod/database/master-password" \
    --force-rotate-immediately
```

#### 3. Performance dégradée (trop d'appels Secrets Manager)

```java
// Analyser les métriques cache
@Component
public class SecretsCacheAnalyzer {
    
    @Autowired
    private CacheManager cacheManager;
    
    @Scheduled(fixedDelay = 60000)
    public void analyzeCachePerformance() {
        Cache secretsCache = cacheManager.getCache("secrets");
        if (secretsCache instanceof CaffeineCache) {
            com.github.benmanes.caffeine.cache.Cache<Object, Object> nativeCache = 
                ((CaffeineCache) secretsCache).getNativeCache();
                
            CacheStats stats = nativeCache.stats();
            
            log.info("Secrets cache stats - Hit rate: {}, Request count: {}", 
                stats.hitRate(), stats.requestCount());
                
            // Alarme si hit rate < 80%
            if (stats.hitRate() < 0.8) {
                log.warn("Low cache hit rate detected: {}", stats.hitRate());
            }
        }
    }
}
```

## ⚠️ Bonnes Pratiques

### ✅ À Faire
- ✅ **Toujours** chiffrer avec KMS dédié par environnement
- ✅ **Utiliser** rotation automatique en staging/prod
- ✅ **Configurer** des réplicas cross-region pour prod
- ✅ **Monitorer** les accès suspects et échecs de rotation
- ✅ **Tester** régulièrement les procédures de récupération
- ✅ **Cacher** les secrets pour réduire les appels API

### ❌ À Éviter
- ❌ **Jamais** stocker de secrets dans variables d'environnement
- ❌ **Jamais** logger les valeurs des secrets
- ❌ **Éviter** de partager secrets entre environnements
- ❌ **Ne pas** désactiver la rotation en production
- ❌ **Éviter** les secrets trop longs (> 64KB)
- ❌ **Ne jamais** commit des secrets dans le code

---

## 📞 Support

- **🔧 Issues Techniques** : [GitHub Issues](https://github.com/accessweaver/aw-infrastructure-as-code/issues)
- **📧 Contact Sécurité** : security@accessweaver.com
- **📖 Documentation AWS** : [AWS Secrets Manager Documentation](https://docs.aws.amazon.com/secretsmanager/)

---

**⚠️ Note Critique** : La gestion des secrets est au cœur de la sécurité d'AccessWeaver. Toute modification en production doit être validée par l'équipe sécurité et testée en staging.