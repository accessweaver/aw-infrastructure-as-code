# 📋 Audit et Conformité - AccessWeaver Infrastructure

**Version :** 1.0  
**Date :** Juin 2025  
**Module :** security/audit  
**Responsable :** Équipe Sécurité AccessWeaver

---

## Table des Matières

1. [Vue d'Ensemble](#-vue-densemble)
   - [Objectif du Module d'Audit](#objectif-du-module-daudit)
   - [Principes Fondamentaux](#principes-fondamentaux)
   - [Architecture Globale](#architecture-globale)
2. [Journalisation AWS Cloud](#-journalisation-aws-cloud)
   - [Configuration CloudTrail](#configuration-cloudtrail)
   - [AWS Config](#aws-config)
   - [Intégration GuardDuty](#intégration-guardduty)
3. [Journalisation Réseau](#-journalisation-réseau)
   - [VPC Flow Logs](#vpc-flow-logs)
   - [WAF Logs](#waf-logs)
   - [Route53 DNS Query Logs](#route53-dns-query-logs)
4. [Journalisation des Applications](#-journalisation-des-applications)
   - [Logs des Conteneurs](#logs-des-conteneurs)
   - [Configuration Logback pour Java](#configuration-logback-pour-java)
   - [Traitement des Logs Applicatifs](#traitement-des-logs-applicatifs)
5. [Centralisation des Journaux d'Audit](#-centralisation-des-journaux-daudit)
   - [Architecture de Centralisation](#architecture-de-centralisation)
   - [Configuration Kinesis Firehose](#configuration-kinesis-firehose)
   - [OpenSearch pour l'Analyse des Logs](#opensearch-pour-lanalyse-des-logs)
6. [Alertes et Détection](#-alertes-et-détection)
   - [Configuration des Alertes](#configuration-des-alertes)
   - [Détection des Événements Critiques](#détection-des-événements-critiques)
   - [Métriques et Alarmes CloudWatch](#métriques-et-alarmes-cloudwatch)
7. [Tableaux de Bord et Visualisation](#-tableaux-de-bord-et-visualisation)
   - [OpenSearch Dashboards](#opensearch-dashboards)
   - [CloudWatch Dashboards](#cloudwatch-dashboards)
   - [QuickSight pour le Reporting](#quicksight-pour-le-reporting)
8. [Conformité Réglementaire](#-conformité-réglementaire)
   - [Cadres de Conformité](#cadres-de-conformité)
   - [AWS Config Rules](#aws-config-rules)
   - [Security Hub](#security-hub)
   - [Rapports Automatisés de Conformité](#rapports-automatisés-de-conformité)
9. [Investigation des Incidents de Sécurité](#-investigation-des-incidents-de-sécurité)
   - [Processus d'Investigation](#processus-dinvestigation)
   - [Outils d'Investigation](#outils-dinvestigation)
   - [Protocole de Réponse aux Incidents](#protocole-de-réponse-aux-incidents)
   - [Meilleures Pratiques](#meilleures-pratiques-pour-linvestigation)
10. [Conclusion](#-conclusion)

---

## 🎯 Vue d'Ensemble

### Objectif du Module d'Audit

Ce document présente l'architecture et l'implémentation du système d'audit et de conformité d'AccessWeaver. L'objectif est de fournir une visibilité complète sur toutes les activités au sein de l'infrastructure et des applications, d'assurer la traçabilité des actions, et de garantir la conformité avec les réglementations applicables.

Un système d'audit robuste est essentiel pour AccessWeaver, car il permet de :

1. Détecter les activités suspectes ou non autorisées
2. Répondre aux exigences de conformité réglementaire
3. Fournir des preuves lors d'investigations de sécurité
4. Assurer la non-répudiation des actions utilisateur
5. Permettre l'analyse post-incident et l'amélioration continue

### Principes Fondamentaux

Le système d'audit d'AccessWeaver repose sur plusieurs principes clés :

| Principe | Description | Implémentation |
|----------|-------------|----------------|
| **Exhaustivité** | Capture de toutes les actions significatives | Journalisation à tous les niveaux (infrastructure, application, données) |
| **Intégrité** | Protection contre la modification non autorisée | Stockage immuable, signatures numériques |
| **Confidentialité** | Protection des informations sensibles | Chiffrement, contrôle d'accès, anonymisation |
| **Disponibilité** | Accès fiable aux journaux d'audit | Réplication, archivage sécurisé |
| **Corrélation** | Capacité à relier des événements connexes | Identifiants de corrélation, format standardisé |
| **Rétention** | Conservation appropriée des données d'audit | Politiques de rétention basées sur la criticité |

### Architecture Globale

L'architecture d'audit d'AccessWeaver adopte une approche en couches pour garantir la capture complète de tous les événements pertinents :

```
┌──────────────────────────────────────────────────────────────────────┐
│                   Architecture d'Audit AccessWeaver                   │
│                                                                       │
│  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐  │
│  │  Niveau AWS/Cloud │  │  Niveau Réseau    │  │  Niveau Système   │  │
│  │                   │  │                   │  │                   │  │
│  │ • CloudTrail      │  │ • VPC Flow Logs   │  │ • CloudWatch Logs │  │
│  │ • Config          │  │ • WAF Logs        │  │ • Logs Systèmes   │  │
│  │ • GuardDuty       │  │ • Route53 Logs    │  │ • Container Logs  │  │
│  └─────────┬─────────┘  └─────────┬─────────┘  └─────────┬─────────┘  │
│            │                      │                      │            │
│            └──────────────────────┼──────────────────────┘            │
│                                   │                                    │
│                        ┌──────────▼──────────┐                         │
│                        │  Collecte Centralisée│                        │
│                        │                      │                        │
│                        │ • Firehose          │                        │
│                        │ • CloudWatch Logs   │                        │
│                        │ • Lambda Processors │                        │
│                        └──────────┬──────────┘                         │
│                                   │                                    │
│                        ┌──────────▼──────────┐                         │
│                        │  Stockage Sécurisé   │                        │
│                        │                      │                        │
│                        │ • S3 (Immutable)    │                        │
│                        │ • Chiffrement KMS   │                        │
│                        │ • Contrôle d'accès  │                        │
│                        └──────────┬──────────┘                         │
│                                   │                                    │
│           ┌─────────────┬─────────▼─────────┬─────────────┐            │
│           │             │                   │             │            │
│  ┌────────▼─────────┐ ┌─▼──────────────────▼─┐ ┌─────────▼────────┐   │
│  │ Analyse & Alertes│ │ Recherche & Reporting │ │ Archivage Long   │   │
│  │                  │ │                       │ │ Terme             │   │
│  │ • CloudWatch     │ │ • OpenSearch         │ │                   │   │
│  │ • Security Hub   │ │ • Athena             │ │ • S3 Glacier      │   │
│  │ • SNS/Lambda     │ │ • QuickSight         │ │ • Lifecycle       │   │
│  └──────────────────┘ └───────────────────────┘ └──────────────────┘   │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

## 📝 Journalisation AWS Cloud

La journalisation au niveau de l'infrastructure cloud constitue la première couche du système d'audit d'AccessWeaver. Elle permet de capturer toutes les actions administratives, les modifications de configuration et les événements de sécurité dans l'environnement AWS.

### Configuration CloudTrail

AWS CloudTrail est le fondement de la stratégie d'audit d'AccessWeaver, enregistrant toutes les activités dans l'infrastructure AWS.

#### CloudTrail Multi-Régions avec Stockage Centralisé

```hcl
# Organisation-wide CloudTrail in Security Account
resource "aws_cloudtrail" "organization_trail" {
  name                          = "accessweaver-${var.environment}-org-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_organization_trail         = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.cloudtrail.arn
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true
    
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }
    
    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda"]
    }
    
    data_resource {
      type   = "AWS::DynamoDB::Table"
      values = ["arn:aws:dynamodb"]
    }
  }
  
  insight_selector {
    insight_type = "ApiCallRateInsight"
  }
  
  insight_selector {
    insight_type = "ApiErrorRateInsight"
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-org-trail"
    Environment = var.environment
    Service     = "audit"
  }
}

# Bucket S3 sécurisé pour les logs CloudTrail
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "accessweaver-${var.environment}-cloudtrail-logs"
  
  tags = {
    Name        = "accessweaver-${var.environment}-cloudtrail-logs"
    Environment = var.environment
    Service     = "audit"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_encryption" {
  bucket = aws_s3_bucket.cloudtrail.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_lifecycle" {
  bucket = aws_s3_bucket.cloudtrail.id
  
  rule {
    id      = "audit-retention"
    status  = "Enabled"
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    expiration {
      days = var.environment == "production" ? 2555 : 395  # Production: 7 ans, Autres: 13 mois
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_public_access_block" {
  bucket = aws_s3_bucket.cloudtrail.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail_policy" {
  bucket = aws_s3_bucket.cloudtrail.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.cloudtrail.id}"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudtrail:${var.region}:${data.aws_organizations_organization.current.master_account_id}:trail/accessweaver-${var.environment}-org-trail"
          }
        }
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.cloudtrail.id}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "aws:SourceArn" = "arn:aws:cloudtrail:${var.region}:${data.aws_organizations_organization.current.master_account_id}:trail/accessweaver-${var.environment}-org-trail"
          }
        }
      },
      {
        Sid       = "DenyNonSSLRequests"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          "arn:aws:s3:::${aws_s3_bucket.cloudtrail.id}",
          "arn:aws:s3:::${aws_s3_bucket.cloudtrail.id}/*"
        ],
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

# KMS key pour chiffrer les logs CloudTrail
resource "aws_kms_key" "cloudtrail" {
  description             = "KMS key pour chiffrer les logs CloudTrail"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "Allow CloudTrail to encrypt logs"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = ["kms:GenerateDataKey*", "kms:Decrypt"]
        Resource  = "*"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudtrail:${var.region}:${data.aws_organizations_organization.current.master_account_id}:trail/accessweaver-${var.environment}-org-trail"
          }
        }
      },
      {
        Sid       = "Allow CloudWatch to decrypt logs"
        Effect    = "Allow"
        Principal = { Service = "logs.${var.region}.amazonaws.com" }
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource  = "*"
      }
    ]
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-cloudtrail-key"
    Environment = var.environment
    Service     = "audit"
  }
}

resource "aws_kms_alias" "cloudtrail" {
  name          = "alias/accessweaver-${var.environment}-cloudtrail"
  target_key_id = aws_kms_key.cloudtrail.key_id
}
```

### Configuration d'AWS Config

AWS Config fournit un inventaire détaillé des ressources AWS et de leur configuration, permettant d'assurer la conformité continue et l'auditabilité des changements de configuration.

```hcl
# Configuration recorder AWS Config
resource "aws_config_configuration_recorder" "main" {
  name     = "accessweaver-${var.environment}-config-recorder"
  role_arn = aws_iam_role.config_recorder.arn
  
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "accessweaver-${var.environment}-config-delivery"
  s3_bucket_name = aws_s3_bucket.config.bucket
  s3_key_prefix  = "aws-config"
  sns_topic_arn  = aws_sns_topic.config_notifications.arn
  
  snapshot_delivery_properties {
    delivery_frequency = "Six_Hours"
  }
  
  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true
  
  depends_on = [aws_config_delivery_channel.main]
}

# Bucket S3 pour AWS Config
resource "aws_s3_bucket" "config" {
  bucket = "accessweaver-${var.environment}-config-logs"
  
  tags = {
    Name        = "accessweaver-${var.environment}-config-logs"
    Environment = var.environment
    Service     = "audit"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config_encryption" {
  bucket = aws_s3_bucket.config.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "config_lifecycle" {
  bucket = aws_s3_bucket.config.id
  
  rule {
    id      = "config-retention"
    status  = "Enabled"
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    expiration {
      days = var.environment == "production" ? 2555 : 395  # Production: 7 ans, Autres: 13 mois
    }
  }
}

resource "aws_s3_bucket_public_access_block" "config_public_access_block" {
  bucket = aws_s3_bucket.config.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "config_policy" {
  bucket = aws_s3_bucket.config.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowConfigBucketAcl"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.config.id}"
      },
      {
        Sid       = "AllowConfigPutObject"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.config.id}/aws-config/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid       = "DenyNonSSLRequests"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          "arn:aws:s3:::${aws_s3_bucket.config.id}",
          "arn:aws:s3:::${aws_s3_bucket.config.id}/*"
        ],
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

# Topic SNS pour les notifications AWS Config
resource "aws_sns_topic" "config_notifications" {
  name              = "accessweaver-${var.environment}-config-notifications"
  kms_master_key_id = aws_kms_key.sns.id
  
  tags = {
    Name        = "accessweaver-${var.environment}-config-notifications"
    Environment = var.environment
    Service     = "audit"
  }
}

# Rôle IAM pour AWS Config
resource "aws_iam_role" "config_recorder" {
  name = "accessweaver-${var.environment}-config-recorder"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-config-recorder"
    Environment = var.environment
    Service     = "audit"
  }
}

resource "aws_iam_role_policy_attachment" "config_managed_policy" {
  role       = aws_iam_role.config_recorder.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3_delivery" {
  name   = "accessweaver-${var.environment}-config-s3-delivery"
  role   = aws_iam_role.config_recorder.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ],
        Resource = "arn:aws:s3:::${aws_s3_bucket.config.id}/aws-config/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*",
        Condition = {
          StringLike = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = "s3:GetBucketAcl",
        Resource = "arn:aws:s3:::${aws_s3_bucket.config.id}"
      }
    ]
  })
}

# AWS Config Rules pour la conformité
resource "aws_config_config_rule" "iam_password_policy" {
  name        = "accessweaver-${var.environment}-iam-password-policy"
  description = "Vérifie que la politique de mot de passe IAM répond aux exigences"
  
  source {
    owner             = "AWS"
    source_identifier = "IAM_PASSWORD_POLICY"
  }
  
  input_parameters = jsonencode({
    RequireUppercaseCharacters = "true"
    RequireLowercaseCharacters = "true"
    RequireSymbols             = "true"
    RequireNumbers             = "true"
    MinimumPasswordLength      = "14"
    PasswordReusePrevention    = "24"
    MaxPasswordAge             = "90"
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-iam-password-policy"
    Environment = var.environment
    Service     = "audit"
  }
}

resource "aws_config_config_rule" "cloudtrail_enabled" {
  name        = "accessweaver-${var.environment}-cloudtrail-enabled"
  description = "Vérifie que CloudTrail est activé et configuré correctement"
  
  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-cloudtrail-enabled"
    Environment = var.environment
    Service     = "audit"
  }
}

resource "aws_config_config_rule" "encrypted_volumes" {
  name        = "accessweaver-${var.environment}-encrypted-volumes"
  description = "Vérifie que les volumes EBS attachés sont chiffrés"
  
  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-encrypted-volumes"
    Environment = var.environment
    Service     = "audit"
  }
}

resource "aws_config_config_rule" "s3_bucket_public_write_prohibited" {
  name        = "accessweaver-${var.environment}-s3-public-write-prohibited"
  description = "Vérifie qu'aucun bucket S3 n'est ouvert en écriture publique"
  
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-s3-public-write-prohibited"
    Environment = var.environment
    Service     = "audit"
  }
}

resource "aws_config_config_rule" "s3_bucket_public_read_prohibited" {
  name        = "accessweaver-${var.environment}-s3-public-read-prohibited"
  description = "Vérifie qu'aucun bucket S3 n'est ouvert en lecture publique"
  
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-s3-public-read-prohibited"
    Environment = var.environment
    Service     = "audit"
  }
}

resource "aws_config_config_rule" "root_account_mfa_enabled" {
  name        = "accessweaver-${var.environment}-root-account-mfa-enabled"
  description = "Vérifie que l'authentification MFA est activée pour le compte root"
  
  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-root-account-mfa-enabled"
    Environment = var.environment
    Service     = "audit"
  }
}

resource "aws_config_config_rule" "vpc_flow_logs_enabled" {
  name        = "accessweaver-${var.environment}-vpc-flow-logs-enabled"
  description = "Vérifie que les VPC Flow Logs sont activés"
  
  source {
    owner             = "AWS"
    source_identifier = "VPC_FLOW_LOGS_ENABLED"
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-vpc-flow-logs-enabled"
    Environment = var.environment
    Service     = "audit"
  }
}

resource "aws_config_config_rule" "vpc_sg_open_only_to_authorized_ports" {
  name        = "accessweaver-${var.environment}-vpc-sg-authorized-ports"
  description = "Vérifie que les groupes de sécurité n'ouvrent que les ports autorisés"
  
  source {
    owner             = "AWS"
    source_identifier = "VPC_SG_OPEN_ONLY_TO_AUTHORIZED_PORTS"
  }
  
  input_parameters = jsonencode({
    authorizedTcpPorts = "443,80,22"
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-vpc-sg-authorized-ports"
    Environment = var.environment
    Service     = "audit"
  }
}

# Règle personnalisée AWS Config pour détecter les ressources sans tags obligatoires
resource "aws_config_config_rule" "required_tags_check" {
  name        = "accessweaver-${var.environment}-required-tags"
  description = "Vérifie que les ressources ont les tags obligatoires (Environment, Service, Name)"
  
  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }
  
  input_parameters = jsonencode({
    tag1Key = "Environment"
    tag2Key = "Service"
    tag3Key = "Name"
  })
  
  scope {
    compliance_resource_types = [
      "AWS::EC2::Instance",
      "AWS::EC2::Volume",
      "AWS::S3::Bucket",
      "AWS::RDS::DBInstance",
      "AWS::DynamoDB::Table",
      "AWS::Lambda::Function"
    ]
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-required-tags"
    Environment = var.environment
    Service     = "audit"
  }
}
```
## 📝 Journalisation Réseau

La journalisation au niveau réseau permet de surveiller tout le trafic entrant et sortant de l'infrastructure AccessWeaver, offrant une visibilité essentielle pour la détection des menaces et l'analyse forensique.

### VPC Flow Logs

La capture et l'analyse du trafic réseau sont essentielles pour la détection des activités suspectes et l'investigation des incidents de sécurité.

```hcl
# VPC Flow Logs
resource "aws_flow_log" "main" {
  log_destination      = aws_s3_bucket.vpc_flow_logs.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
  
  log_format = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${vpc-id} $${subnet-id} $${instance-id} $${tcp-flags} $${type} $${pkt-srcaddr} $${pkt-dstaddr} $${region} $${az-id} $${sublocation-type} $${sublocation-id}"
  
  tags = {
    Name        = "accessweaver-${var.environment}-vpc-flow-logs"
    Environment = var.environment
    Service     = "network-audit"
  }
}

# Bucket S3 pour les VPC Flow Logs
resource "aws_s3_bucket" "vpc_flow_logs" {
  bucket = "accessweaver-${var.environment}-vpc-flow-logs"
  
  tags = {
    Name        = "accessweaver-${var.environment}-vpc-flow-logs"
    Environment = var.environment
    Service     = "network-audit"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vpc_flow_logs_encryption" {
  bucket = aws_s3_bucket.vpc_flow_logs.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "vpc_flow_logs_lifecycle" {
  bucket = aws_s3_bucket.vpc_flow_logs.id
  
  rule {
    id      = "vpc-flow-logs-retention"
    status  = "Enabled"
    
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    expiration {
      days = var.environment == "production" ? 365 : 180
    }
  }
}

resource "aws_s3_bucket_public_access_block" "vpc_flow_logs_public_access_block" {
  bucket = aws_s3_bucket.vpc_flow_logs.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# WAF Logs
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  log_destination_configs = [aws_s3_bucket.waf_logs.arn]
  resource_arn            = aws_wafv2_web_acl.main.arn
  redacted_fields {
    single_header {
      name = "authorization"
    }
    single_header {
      name = "cookie"
    }
  }
}

# Bucket S3 pour les logs WAF
resource "aws_s3_bucket" "waf_logs" {
  bucket = "accessweaver-${var.environment}-waf-logs"
  
  tags = {
    Name        = "accessweaver-${var.environment}-waf-logs"
    Environment = var.environment
    Service     = "waf-audit"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "waf_logs_encryption" {
  bucket = aws_s3_bucket.waf_logs.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "waf_logs_lifecycle" {
  bucket = aws_s3_bucket.waf_logs.id
  
  rule {
    id      = "waf-logs-retention"
    status  = "Enabled"
    
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    expiration {
      days = var.environment == "production" ? 365 : 180
    }
  }
}

resource "aws_s3_bucket_public_access_block" "waf_logs_public_access_block" {
  bucket = aws_s3_bucket.waf_logs.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Route53 Query Logs
resource "aws_route53_query_log" "main" {
  depends_on = [aws_s3_bucket_policy.route53_logs_policy]
  
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.route53.arn
  zone_id                  = aws_route53_zone.main.zone_id
}

resource "aws_cloudwatch_log_group" "route53" {
  name              = "/aws/route53/${var.environment}-dns-queries"
  retention_in_days = var.environment == "production" ? 30 : 14
  kms_key_id        = aws_kms_key.logs.arn
  
  tags = {
    Name        = "accessweaver-${var.environment}-route53-logs"
    Environment = var.environment
    Service     = "dns-audit"
  }
}

# CloudWatch Logs Subscription Filter pour Route53 vers S3
resource "aws_cloudwatch_log_subscription_filter" "route53_to_s3" {
  name            = "accessweaver-${var.environment}-route53-to-s3"
  log_group_name  = aws_cloudwatch_log_group.route53.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.route53_logs.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
}

# Firehose pour Route53 Logs vers S3
resource "aws_kinesis_firehose_delivery_stream" "route53_logs" {
  name        = "accessweaver-${var.environment}-route53-logs"
  destination = "extended_s3"
  
  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_to_s3.arn
    bucket_arn         = aws_s3_bucket.route53_logs.arn
    prefix             = "route53-logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "route53-logs-errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/!{firehose:error-output-type}/"
    buffer_size        = 5
    buffer_interval    = 300
    
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_route53.name
      log_stream_name = "S3Delivery"
    }
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-route53-logs-firehose"
    Environment = var.environment
    Service     = "dns-audit"
  }
}

resource "aws_cloudwatch_log_group" "firehose_route53" {
  name              = "/aws/firehose/accessweaver-${var.environment}-route53-logs"
  retention_in_days = 7
  
  tags = {
    Name        = "accessweaver-${var.environment}-firehose-route53-logs"
    Environment = var.environment
    Service     = "dns-audit"
  }
}

# S3 pour Route53 Logs
resource "aws_s3_bucket" "route53_logs" {
  bucket = "accessweaver-${var.environment}-route53-logs"
  
  tags = {
    Name        = "accessweaver-${var.environment}-route53-logs"
    Environment = var.environment
    Service     = "dns-audit"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "route53_logs_encryption" {
  bucket = aws_s3_bucket.route53_logs.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "route53_logs_lifecycle" {
  bucket = aws_s3_bucket.route53_logs.id
  
  rule {
    id      = "route53-logs-retention"
    status  = "Enabled"
    
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    expiration {
      days = var.environment == "production" ? 180 : 90
    }
  }
}

resource "aws_s3_bucket_policy" "route53_logs_policy" {
  bucket = aws_s3_bucket.route53_logs.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowFirehoseDelivery"
        Effect    = "Allow"
        Principal = { Service = "firehose.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.route53_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid       = "DenyNonSSLRequests"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          aws_s3_bucket.route53_logs.arn,
          "${aws_s3_bucket.route53_logs.arn}/*"
        ],
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "route53_logs_public_access_block" {
  bucket = aws_s3_bucket.route53_logs.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

## 📝 Journalisation des Applications

La journalisation au niveau applicatif complète les couches précédentes en fournissant des informations détaillées sur le comportement des applications, les actions des utilisateurs et les erreurs potentielles.

### Logs des Conteneurs

Les applications AccessWeaver sont déployées en conteneurs sur ECS. Une stratégie de journalisation cohérente est essentielle pour assurer la visibilité sur les opérations applicatives.

```hcl
# Groupe de logs CloudWatch pour les applications AccessWeaver
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ecs/accessweaver-${var.environment}-apps"
  retention_in_days = var.environment == "production" ? 90 : 30
  kms_key_id        = aws_kms_key.logs.arn
  
  tags = {
    Name        = "accessweaver-${var.environment}-app-logs"
    Environment = var.environment
    Service     = "application-audit"
  }
}

# Définition de tâche ECS avec configuration de logs
resource "aws_ecs_task_definition" "app" {
  family                   = "accessweaver-${var.environment}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  
  container_definitions = jsonencode([
    {
      name      = "accessweaver-app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true
      
      # Configuration des logs
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app_logs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "app"
        }
      }
      
      # Variables d'environnement pour la journalisation
      environment = [
        {
          name  = "LOGGING_LEVEL_ROOT"
          value = var.environment == "production" ? "INFO" : "DEBUG"
        },
        {
          name  = "LOGGING_LEVEL_COM_ACCESSWEAVER"
          value = var.environment == "production" ? "INFO" : "DEBUG"
        },
        {
          name  = "LOG_FORMAT"
          value = "json"
        },
        {
          name  = "CORRELATION_ID_HEADER"
          value = "X-Correlation-ID"
        },
        {
          name  = "APP_NAME"
          value = "accessweaver-app"
        },
        {
          name  = "APP_ENV"
          value = var.environment
        }
      ]
      
      # Configuration des ports et de la santé
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
  
  tags = {
    Name        = "accessweaver-${var.environment}-app"
    Environment = var.environment
    Service     = "application"
  }
}

# Abonnement pour transférer les logs d'application vers S3
resource "aws_cloudwatch_log_subscription_filter" "app_logs_to_s3" {
  name            = "accessweaver-${var.environment}-app-logs-to-s3"
  log_group_name  = aws_cloudwatch_log_group.app_logs.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.app_logs.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
}

# Firehose pour les logs d'application vers S3
resource "aws_kinesis_firehose_delivery_stream" "app_logs" {
  name        = "accessweaver-${var.environment}-app-logs"
  destination = "extended_s3"
  
  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_to_s3.arn
    bucket_arn         = aws_s3_bucket.app_logs.arn
    prefix             = "app-logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "app-logs-errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/!{firehose:error-output-type}/"
    buffer_size        = 5
    buffer_interval    = 300
    
    processing_configuration {
      enabled = true
      
      processors {
        type = "Lambda"
        
        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = aws_lambda_function.log_processor.arn
        }
        
        parameters {
          parameter_name  = "BufferSizeInMBs"
          parameter_value = "3"
        }
        
        parameters {
          parameter_name  = "BufferIntervalInSeconds"
          parameter_value = "60"
        }
      }
    }
    
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_app_logs.name
      log_stream_name = "S3Delivery"
    }
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-app-logs-firehose"
    Environment = var.environment
    Service     = "application-audit"
  }
}

# Lambda pour traiter les logs d'application
resource "aws_lambda_function" "log_processor" {
  function_name = "accessweaver-${var.environment}-log-processor"
  role          = aws_iam_role.log_processor.arn
  runtime       = "java21"
  handler       = "com.accessweaver.audit.LogProcessorHandler"
  timeout       = 60
  memory_size   = 512
  
  environment {
    variables = {
      ENVIRONMENT     = var.environment
      MASK_PII        = "true"
      FIELDS_TO_MASK  = "email,user_id,ip_address,session_token"
      MASK_PATTERN    = "****"
    }
  }
  
  filename         = "${path.module}/lambda/log-processor.jar"
  source_code_hash = filebase64sha256("${path.module}/lambda/log-processor.jar")
  
  tags = {
    Name        = "accessweaver-${var.environment}-log-processor"
    Environment = var.environment
    Service     = "application-audit"
  }
}

# S3 Bucket pour les logs d'application
resource "aws_s3_bucket" "app_logs" {
  bucket = "accessweaver-${var.environment}-app-logs"
  
  tags = {
    Name        = "accessweaver-${var.environment}-app-logs"
    Environment = var.environment
    Service     = "application-audit"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_logs_encryption" {
  bucket = aws_s3_bucket.app_logs.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "app_logs_lifecycle" {
  bucket = aws_s3_bucket.app_logs.id
  
  rule {
    id      = "app-logs-retention"
    status  = "Enabled"
    
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    expiration {
      days = var.environment == "production" ? 365 : 180
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app_logs_public_access_block" {
  bucket = aws_s3_bucket.app_logs.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudwatch_log_group" "firehose_app_logs" {
  name              = "/aws/firehose/accessweaver-${var.environment}-app-logs"
  retention_in_days = 7
  
  tags = {
    Name        = "accessweaver-${var.environment}-firehose-app-logs"
    Environment = var.environment
    Service     = "application-audit"
  }
}
```

### Configuration Logback pour les Applications Java

```xml
<!-- logback-spring.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <springProperty scope="context" name="appName" source="spring.application.name"/>
    <springProperty scope="context" name="appEnv" source="spring.profiles.active"/>
    <springProperty scope="context" name="logFormat" source="logging.format" defaultValue="json"/>
    
    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder class="net.logstash.logback.encoder.LogstashEncoder">
            <includeMdcKeyName>correlationId</includeMdcKeyName>
            <includeMdcKeyName>userId</includeMdcKeyName>
            <includeMdcKeyName>tenantId</includeMdcKeyName>
            <includeMdcKeyName>requestId</includeMdcKeyName>
            <includeMdcKeyName>sourceIp</includeMdcKeyName>
            <includeMdcKeyName>userAgent</includeMdcKeyName>
            <customFields>{"app":"${appName}","environment":"${appEnv}"}</customFields>
        </encoder>
    </appender>
    
    <appender name="ASYNC" class="ch.qos.logback.classic.AsyncAppender">
        <appender-ref ref="CONSOLE" />
        <queueSize>512</queueSize>
        <discardingThreshold>0</discardingThreshold>
        <includeCallerData>true</includeCallerData>
        <neverBlock>true</neverBlock>
    </appender>
    
    <!-- Niveaux de log par environnement -->
    <springProfile name="production">
        <root level="INFO">
            <appender-ref ref="ASYNC" />
        </root>
        <logger name="com.accessweaver" level="INFO" />
    </springProfile>
    
    <springProfile name="staging">
        <root level="INFO">
            <appender-ref ref="ASYNC" />
        </root>
        <logger name="com.accessweaver" level="DEBUG" />
    </springProfile>
    
    <springProfile name="development">
        <root level="INFO">
            <appender-ref ref="ASYNC" />
        </root>
        <logger name="com.accessweaver" level="DEBUG" />
    </springProfile>
</configuration>
```
## 🔄 Centralisation des Journaux d'Audit

La centralisation des journaux est essentielle pour permettre une analyse efficace, une corrélation des événements et une conservation sécurisée à long terme des données d'audit.

### Architecture de Centralisation

AccessWeaver utilise une architecture centralisée pour la collecte et l'analyse des journaux d'audit à travers tous les composants et environnements.

```
┌───────────────────────────────────────────────────────────────────────┐
│               Architecture de Centralisation des Logs                  │
│                                                                       │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    │
│  │   Compte Dev    │    │  Compte Staging  │    │  Compte Prod    │    │
│  │                 │    │                  │    │                 │    │
│  │  • CloudTrail   │    │  • CloudTrail    │    │  • CloudTrail   │    │
│  │  • VPC Flow Logs│    │  • VPC Flow Logs │    │  • VPC Flow Logs│    │
│  │  • App Logs     │    │  • App Logs      │    │  • App Logs     │    │
│  └────────┬────────┘    └────────┬─────────┘    └────────┬────────┘    │
│           │                      │                       │             │
│           │                      │                       │             │
│           └──────────────────────┼───────────────────────┘             │
│                                  │                                     │
│                      ┌───────────▼───────────┐                         │
│                      │                       │                         │
│                      │    Compte Sécurité    │                         │
│                      │                       │                         │
│                      └───────────┬───────────┘                         │
│                                  │                                     │
│                      ┌───────────▼───────────┐                         │
│                      │  Kinesis Firehose     │                         │
│                      │    Centralisation     │                         │
│                      └───────────┬───────────┘                         │
│                                  │                                     │
│                                  │                                     │
│           ┌──────────────────────┼──────────────────────┐             │
│           │                      │                      │             │
│  ┌────────▼────────┐    ┌────────▼────────┐    ┌────────▼────────┐    │
│  │                 │    │                 │    │                 │    │
│  │  S3 Stockage    │    │  OpenSearch     │    │  CloudWatch     │    │
│  │  Long-terme     │    │  Analyse        │    │  Alertes        │    │
│  │                 │    │                 │    │                 │    │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘    │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

### Configuration Kinesis Firehose

Kinesis Firehose est utilisé comme pipeline principal pour la collecte et le traitement des journaux avant leur stockage dans les destinations finales.

```hcl
# Firehose pour la centralisation des logs
resource "aws_kinesis_firehose_delivery_stream" "central_logs" {
  name        = "accessweaver-${var.environment}-central-logs"
  destination = "elasticsearch"
  
  elasticsearch_configuration {
    domain_arn            = aws_elasticsearch_domain.logs.arn
    role_arn              = aws_iam_role.firehose_elasticsearch.arn
    index_name            = "accessweaver-logs"
    type_name             = "_doc"
    index_rotation_period = "OneDay"
    
    s3_backup_mode = "AllDocuments"
    
    processing_configuration {
      enabled = true
      
      processors {
        type = "Lambda"
        
        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = aws_lambda_function.log_enrichment.arn
        }
      }
    }
    
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_elasticsearch.name
      log_stream_name = "ElasticsearchDelivery"
    }
  }
  
  s3_configuration {
    role_arn           = aws_iam_role.firehose_s3.arn
    bucket_arn         = aws_s3_bucket.central_logs.arn
    prefix             = "central-logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/!{firehose:error-output-type}/"
    buffer_size        = 5
    buffer_interval    = 300
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-central-logs"
    Environment = var.environment
    Service     = "audit"
  }
}

# Lambda pour l'enrichissement des logs
resource "aws_lambda_function" "log_enrichment" {
  function_name = "accessweaver-${var.environment}-log-enrichment"
  role          = aws_iam_role.log_enrichment.arn
  runtime       = "java21"
  handler       = "com.accessweaver.audit.LogEnrichmentHandler"
  timeout       = 60
  memory_size   = 512
  
  environment {
    variables = {
      ENVIRONMENT     = var.environment
      ADD_METADATA    = "true"
      SERVICE_MAPPING = jsonencode({
        "s3"         = "Storage",
        "dynamodb"   = "Database",
        "lambda"     = "Compute",
        "ec2"        = "Compute",
        "rds"        = "Database",
        "apigateway" = "API"
      })
    }
  }
  
  filename         = "${path.module}/lambda/log-enrichment.jar"
  source_code_hash = filebase64sha256("${path.module}/lambda/log-enrichment.jar")
  
  tags = {
    Name        = "accessweaver-${var.environment}-log-enrichment"
    Environment = var.environment
    Service     = "audit"
  }
}

# OpenSearch Domain pour l'analyse des logs
resource "aws_elasticsearch_domain" "logs" {
  domain_name           = "accessweaver-${var.environment}-logs"
  elasticsearch_version = "OpenSearch_2.5"
  
  cluster_config {
    instance_type            = var.environment == "production" ? "r6g.large.elasticsearch" : "t3.medium.elasticsearch"
    instance_count           = var.environment == "production" ? 3 : 1
    dedicated_master_enabled = var.environment == "production" ? true : false
    dedicated_master_type    = var.environment == "production" ? "r6g.large.elasticsearch" : null
    dedicated_master_count   = var.environment == "production" ? 3 : null
    zone_awareness_enabled   = var.environment == "production" ? true : false
    
    zone_awareness_config {
      availability_zone_count = var.environment == "production" ? 3 : null
    }
  }
  
  ebs_options {
    ebs_enabled = true
    volume_size = var.environment == "production" ? 100 : 20
    volume_type = "gp3"
  }
  
  encrypt_at_rest {
    enabled = true
    kms_key_id = aws_kms_key.elasticsearch.arn
  }
  
  node_to_node_encryption {
    enabled = true
  }
  
  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
    
    custom_endpoint_enabled         = true
    custom_endpoint                 = "logs.${var.domain_name}"
    custom_endpoint_certificate_arn = aws_acm_certificate.logs.arn
  }
  
  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    
    master_user_options {
      master_user_name     = "admin"
      master_user_password = random_password.elasticsearch_admin.result
    }
  }
  
  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.firehose_elasticsearch.arn }
        Action    = [
          "es:ESHttpPost",
          "es:ESHttpPut"
        ]
        Resource  = "arn:aws:es:${var.region}:${data.aws_caller_identity.current.account_id}:domain/accessweaver-${var.environment}-logs/*"
      },
      {
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.logs_reader.arn }
        Action    = [
          "es:ESHttpGet",
          "es:ESHttpPost"
        ]
        Resource  = "arn:aws:es:${var.region}:${data.aws_caller_identity.current.account_id}:domain/accessweaver-${var.environment}-logs/*"
      }
    ]
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-logs"
    Environment = var.environment
    Service     = "audit"
  }
}

# CloudWatch Log Group pour Firehose
resource "aws_cloudwatch_log_group" "firehose_elasticsearch" {
  name              = "/aws/firehose/accessweaver-${var.environment}-elasticsearch"
  retention_in_days = 7
  
  tags = {
    Name        = "accessweaver-${var.environment}-firehose-elasticsearch"
    Environment = var.environment
    Service     = "audit"
  }
}

# S3 Bucket pour les logs centralisés
resource "aws_s3_bucket" "central_logs" {
  bucket = "accessweaver-${var.environment}-central-logs"
  
  tags = {
    Name        = "accessweaver-${var.environment}-central-logs"
    Environment = var.environment
    Service     = "audit"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "central_logs_encryption" {
  bucket = aws_s3_bucket.central_logs.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "central_logs_lifecycle" {
  bucket = aws_s3_bucket.central_logs.id
  
  rule {
    id      = "central-logs-retention"
    status  = "Enabled"
    
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
    
    expiration {
      days = var.environment == "production" ? 2555 : 730
    }
  }
}

resource "aws_s3_bucket_public_access_block" "central_logs_public_access_block" {
  bucket = aws_s3_bucket.central_logs.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

## 🚨 Alertes et Détection

Un système d'alerte efficace est crucial pour identifier rapidement les incidents de sécurité potentiels et y répondre avant qu'ils ne causent des dommages significatifs.

### Configuration des Alertes

AccessWeaver implémente un système d'alerte complet pour identifier rapidement les activités suspectes ou les problèmes de sécurité.

```hcl
# Topic SNS pour les alertes de sécurité
resource "aws_sns_topic" "security_alerts" {
  name              = "accessweaver-${var.environment}-security-alerts"
  kms_master_key_id = aws_kms_key.sns.id
  
  tags = {
    Name        = "accessweaver-${var.environment}-security-alerts"
    Environment = var.environment
    Service     = "audit"
  }
}

# Abonnement par e-mail pour l'équipe de sécurité
resource "aws_sns_topic_subscription" "security_team_email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = "security-team@accessweaver.com"
}

# Abonnement à un webhook Slack pour les alertes critiques
resource "aws_sns_topic_subscription" "security_slack" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "https"
  endpoint  = var.slack_webhook_url
  
  delivery_policy = jsonencode({
    healthyRetryPolicy = {
      minDelayTarget    = 20
      maxDelayTarget    = 20
      numRetries        = 3
      numMaxDelayRetries = 0
      numNoDelayRetries = 0
      numMinDelayRetries = 0
      backoffFunction   = "linear"
    }
  })
}

# Lambda pour formater les alertes Slack
resource "aws_lambda_function" "slack_alerter" {
  function_name = "accessweaver-${var.environment}-slack-alerter"
  role          = aws_iam_role.slack_alerter.arn
  runtime       = "java21"
  handler       = "com.accessweaver.audit.SlackAlerterHandler"
  timeout       = 30
  memory_size   = 256
  
  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
      ENVIRONMENT       = var.environment
    }
  }
  
  filename         = "${path.module}/lambda/slack-alerter.jar"
  source_code_hash = filebase64sha256("${path.module}/lambda/slack-alerter.jar")
  
  tags = {
    Name        = "accessweaver-${var.environment}-slack-alerter"
    Environment = var.environment
    Service     = "audit-alerting"
  }
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_alerter.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.security_alerts.arn
}

# Règles CloudWatch Events pour la détection des activités suspectes
resource "aws_cloudwatch_event_rule" "root_account_usage" {
  name        = "accessweaver-${var.environment}-root-account-usage"
  description = "Détecte l'utilisation du compte root"
  
  event_pattern = jsonencode({
    source      = ["aws.signin"],
    detail-type = ["AWS Console Sign In via CloudTrail"],
    detail = {
      userIdentity = {
        type = ["Root"]
      }
    }
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-root-account-usage"
    Environment = var.environment
    Service     = "audit-alerting"
  }
}

resource "aws_cloudwatch_event_target" "root_account_usage" {
  rule      = aws_cloudwatch_event_rule.root_account_usage.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
  
  input_transformer {
    input_paths = {
      account = "$.account"
      time    = "$.time"
      region  = "$.region"
      source  = "$.source"
    }
    
    input_template = "\"[ALERTE CRITIQUE] Connexion du compte root détectée pour le compte <account> à <time> dans la région <region>\""
  }
}

# Alerte pour les modifications de politique IAM
resource "aws_cloudwatch_event_rule" "iam_policy_changes" {
  name        = "accessweaver-${var.environment}-iam-policy-changes"
  description = "Détecte les modifications des politiques IAM"
  
  event_pattern = jsonencode({
    source      = ["aws.iam"],
    detail-type = ["AWS API Call via CloudTrail"],
    detail = {
      eventName = [
        "CreatePolicy",
        "DeletePolicy",
        "CreatePolicyVersion",
        "DeletePolicyVersion",
        "AttachRolePolicy",
        "DetachRolePolicy",
        "AttachUserPolicy",
        "DetachUserPolicy",
        "AttachGroupPolicy",
        "DetachGroupPolicy"
      ]
    }
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-iam-policy-changes"
    Environment = var.environment
    Service     = "audit-alerting"
  }
}

resource "aws_cloudwatch_event_target" "iam_policy_changes" {
  rule      = aws_cloudwatch_event_rule.iam_policy_changes.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}

# Alerte pour les modifications de groupe de sécurité
resource "aws_cloudwatch_event_rule" "security_group_changes" {
  name        = "accessweaver-${var.environment}-security-group-changes"
  description = "Détecte les modifications des groupes de sécurité"
  
  event_pattern = jsonencode({
    source      = ["aws.ec2"],
    detail-type = ["AWS API Call via CloudTrail"],
    detail = {
      eventName = [
        "AuthorizeSecurityGroupIngress",
        "AuthorizeSecurityGroupEgress",
        "RevokeSecurityGroupIngress",
        "RevokeSecurityGroupEgress",
        "CreateSecurityGroup",
        "DeleteSecurityGroup"
      ]
    }
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-security-group-changes"
    Environment = var.environment
    Service     = "audit-alerting"
  }
}

resource "aws_cloudwatch_event_target" "security_group_changes" {
  rule      = aws_cloudwatch_event_rule.security_group_changes.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}

# Métriques et alarmes CloudWatch pour les activités d'audit
resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "accessweaver-${var.environment}-unauthorized-api-calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnauthorizedAttemptCount"
  namespace           = "CloudTrailMetrics"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Cette alarme surveille les tentatives d'appels API non autorisés"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  
  tags = {
    Name        = "accessweaver-${var.environment}-unauthorized-api-calls"
    Environment = var.environment
    Service     = "audit-alerting"
  }
}

# Filtre métrique pour détecter les appels API non autorisés
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  name           = "accessweaver-${var.environment}-unauthorized-api-calls"
  pattern        = "{ $.errorCode = \"*UnauthorizedOperation\" || $.errorCode = \"AccessDenied*\" }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  
  metric_transformation {
    name      = "UnauthorizedAttemptCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/accessweaver-${var.environment}"
  retention_in_days = 14
  kms_key_id        = aws_kms_key.logs.arn
  
  tags = {
    Name        = "accessweaver-${var.environment}-cloudtrail-logs"
    Environment = var.environment
    Service     = "audit"
  }
}
```
## 📊 Tableaux de Bord et Visualisation

La visualisation efficace des données d'audit permet aux équipes de sécurité et de conformité d'identifier rapidement les tendances, les anomalies et les problèmes potentiels.

### OpenSearch Dashboards

AccessWeaver implémente un système complet de tableaux de bord pour la visualisation et l'analyse des données d'audit.

```
┌───────────────────────────────────────────────────────────────────────┐
│                    Visualisation des Données d'Audit                   │
│                                                                       │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    │
│  │                 │    │                 │    │                 │    │
│  │  OpenSearch     │    │  CloudWatch     │    │  QuickSight     │    │
│  │  Dashboards     │    │  Dashboards     │    │  Rapports       │    │
│  │                 │    │                 │    │                 │    │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘    │
│           │                      │                      │             │
│           └──────────┬───────────┴──────────┬───────────┘             │
│                      │                      │                         │
│                      │                      │                         │
│              ┌───────▼──────────────────────▼───────┐                 │
│              │                                      │                 │
│              │        Système de Gouvernance        │                 │
│              │                                      │                 │
│              └──────────────────┬───────────────────┘                 │
│                                 │                                     │
│                       ┌─────────▼─────────┐                           │
│                       │                   │                           │
│                       │  Équipe Sécurité  │                           │
│                       │  Équipe Audit     │                           │
│                       │                   │                           │
│                       └───────────────────┘                           │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

#### Configuration des Dashboards OpenSearch

OpenSearch (anciennement Elasticsearch) est utilisé pour créer des tableaux de bord riches et interactifs pour l'analyse des données d'audit.

```hcl
# Module Terraform pour les tableaux de bord OpenSearch
module "opensearch_dashboards" {
  source = "./modules/opensearch-dashboards"
  
  domain_name        = aws_elasticsearch_domain.logs.domain_name
  kibana_endpoint    = aws_elasticsearch_domain.logs.kibana_endpoint
  dashboard_config   = [
    {
      id          = "security-overview"
      title       = "Aperçu de Sécurité"
      description = "Tableau de bord principal pour la surveillance de sécurité"
      panels      = [
        {
          id    = "auth-failures"
          type  = "visualization"
          title = "Échecs d'Authentification"
          size_x = 6
          size_y = 4
          col    = 1
          row    = 1
        },
        {
          id    = "api-activity"
          type  = "visualization"
          title = "Activité API par Service"
          size_x = 6
          size_y = 4
          col    = 7
          row    = 1
        },
        {
          id    = "geo-map"
          type  = "visualization"
          title = "Carte des Connexions"
          size_x = 12
          size_y = 5
          col    = 1
          row    = 5
        }
      ]
    },
    {
      id          = "compliance-dashboard"
      title       = "Tableau de Bord de Conformité"
      description = "Suivi des métriques de conformité réglementaire"
      panels      = [
        {
          id    = "compliance-score"
          type  = "visualization"
          title = "Score de Conformité"
          size_x = 4
          size_y = 3
          col    = 1
          row    = 1
        },
        {
          id    = "failed-checks"
          type  = "visualization"
          title = "Contrôles Échoués"
          size_x = 8
          size_y = 3
          col    = 5
          row    = 1
        },
        {
          id    = "compliance-trend"
          type  = "visualization"
          title = "Tendance de Conformité"
          size_x = 12
          size_y = 4
          col    = 1
          row    = 4
        }
      ]
    },
    {
      id          = "iam-activity"
      title       = "Activité IAM"
      description = "Surveillance des changements et activités IAM"
      panels      = [
        {
          id    = "iam-changes"
          type  = "visualization"
          title = "Modifications IAM"
          size_x = 6
          size_y = 4
          col    = 1
          row    = 1
        },
        {
          id    = "privilege-usage"
          type  = "visualization"
          title = "Utilisation des Privilèges"
          size_x = 6
          size_y = 4
          col    = 7
          row    = 1
        },
        {
          id    = "role-assumption"
          type  = "visualization"
          title = "Assumption de Rôles"
          size_x = 12
          size_y = 4
          col    = 1
          row    = 5
        }
      ]
    }
  ]
  
  index_patterns = [
    {
      id          = "cloudtrail-pattern"
      title       = "cloudtrail-*"
      time_field  = "eventTime"
    },
    {
      id          = "vpc-flow-pattern"
      title       = "vpc-flow-*"
      time_field  = "start"
    },
    {
      id          = "waf-logs-pattern"
      title       = "waf-*"
      time_field  = "timestamp"
    },
    {
      id          = "app-logs-pattern"
      title       = "app-logs-*"
      time_field  = "@timestamp"
    }
  ]
  
  saved_searches = [
    {
      id          = "root-login-search"
      title       = "Connexions Utilisateur Root"
      description = "Détecte les connexions avec le compte root"
      search_source = jsonencode({
        query = {
          bool = {
            must = [
              { match = { "userIdentity.type" = "Root" } },
              { match = { "eventName" = "ConsoleLogin" } }
            ]
          }
        }
      })
    },
    {
      id          = "security-group-changes-search"
      title       = "Modifications des Groupes de Sécurité"
      description = "Surveille les modifications apportées aux groupes de sécurité"
      search_source = jsonencode({
        query = {
          bool = {
            should = [
              { match = { "eventName" = "AuthorizeSecurityGroupIngress" } },
              { match = { "eventName" = "AuthorizeSecurityGroupEgress" } },
              { match = { "eventName" = "RevokeSecurityGroupIngress" } },
              { match = { "eventName" = "RevokeSecurityGroupEgress" } },
              { match = { "eventName" = "CreateSecurityGroup" } },
              { match = { "eventName" = "DeleteSecurityGroup" } }
            ],
            minimum_should_match = 1
          }
        }
      })
    }
  ]
  
  visualization_objects = [
    {
      id          = "auth-failures"
      title       = "Échecs d'Authentification"
      description = "Visualisation des échecs d'authentification par service"
      visualization_type = "bar"
      search_source = jsonencode({
        query = {
          bool = {
            must = [
              { match = { "eventName" = "ConsoleLogin" } },
              { match = { "responseElements.ConsoleLogin" = "Failure" } }
            ]
          }
        },
        aggs = {
          time_buckets = {
            date_histogram = {
              field = "eventTime",
              interval = "day"
            }
          }
        }
      })
    },
    {
      id          = "api-activity"
      title       = "Activité API par Service"
      description = "Distribution des appels API par service AWS"
      visualization_type = "pie"
      search_source = jsonencode({
        query = { match_all = {} },
        aggs = {
          services = {
            terms = {
              field = "eventSource",
              size = 10
            }
          }
        }
      })
    }
  ]
  
  environment = var.environment
  region      = var.region
  tags        = local.common_tags
}

# Lambda pour rafraîchir périodiquement les tableaux de bord
resource "aws_lambda_function" "dashboard_refresher" {
  function_name = "accessweaver-${var.environment}-dashboard-refresher"
  role          = aws_iam_role.dashboard_refresher.arn
  runtime       = "java21"
  handler       = "com.accessweaver.audit.DashboardRefresherHandler"
  timeout       = 300
  memory_size   = 512
  
  environment {
    variables = {
      ELASTICSEARCH_ENDPOINT = "https://${aws_elasticsearch_domain.logs.endpoint}",
      REGION                 = var.region,
      ENVIRONMENT            = var.environment
    }
  }
  
  filename         = "${path.module}/lambda/dashboard-refresher.jar"
  source_code_hash = filebase64sha256("${path.module}/lambda/dashboard-refresher.jar")
  
  tags = {
    Name        = "accessweaver-${var.environment}-dashboard-refresher"
    Environment = var.environment
    Service     = "audit-dashboards"
  }
}

# Événement CloudWatch pour déclencher le rafraîchissement des tableaux de bord
resource "aws_cloudwatch_event_rule" "dashboard_refresh" {
  name                = "accessweaver-${var.environment}-dashboard-refresh"
  description         = "Déclenche le rafraîchissement des tableaux de bord OpenSearch"
  schedule_expression = "rate(1 hour)"
  
  tags = {
    Name        = "accessweaver-${var.environment}-dashboard-refresh"
    Environment = var.environment
    Service     = "audit-dashboards"
  }
}

resource "aws_cloudwatch_event_target" "dashboard_refresh" {
  rule      = aws_cloudwatch_event_rule.dashboard_refresh.name
  target_id = "RefreshDashboards"
  arn       = aws_lambda_function.dashboard_refresher.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dashboard_refresher.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.dashboard_refresh.arn
}
```

### Tableaux de Bord CloudWatch

CloudWatch offre une solution intégrée pour la surveillance des métriques d'audit et la création de tableaux de bord.

```hcl
# Tableau de bord CloudWatch pour la surveillance de sécurité
resource "aws_cloudwatch_dashboard" "security_monitoring" {
  dashboard_name = "accessweaver-${var.environment}-security-monitoring"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["CloudTrailMetrics", "UnauthorizedAttemptCount", { stat = "Sum", period = 300 }],
          ]
          view    = "timeSeries"
          stacked = false
          title   = "Tentatives d'Accès Non Autorisées"
          region  = var.region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.log_processor.function_name, { stat = "Sum", period = 300 }],
            ["AWS/Lambda", "Throttles", "FunctionName", aws_lambda_function.log_processor.function_name, { stat = "Sum", period = 300 }]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "Erreurs de Traitement des Logs"
          region  = var.region
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "BucketName", aws_s3_bucket.cloudtrail.id, "StorageType", "StandardStorage", { stat = "Maximum", period = 86400 }],
            ["AWS/S3", "BucketSizeBytes", "BucketName", aws_s3_bucket.config.id, "StorageType", "StandardStorage", { stat = "Maximum", period = 86400 }],
            ["AWS/S3", "BucketSizeBytes", "BucketName", aws_s3_bucket.vpc_flow_logs.id, "StorageType", "StandardStorage", { stat = "Maximum", period = 86400 }],
            ["AWS/S3", "BucketSizeBytes", "BucketName", aws_s3_bucket.waf_logs.id, "StorageType", "StandardStorage", { stat = "Maximum", period = 86400 }],
            ["AWS/S3", "BucketSizeBytes", "BucketName", aws_s3_bucket.app_logs.id, "StorageType", "StandardStorage", { stat = "Maximum", period = 86400 }]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "Taille des Buckets de Logs"
          region  = var.region
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/CloudTrail", "Events", { stat = "Sum", period = 3600 }]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "Événements CloudTrail"
          region  = var.region
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 12
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/Firehose", "DeliveryToS3.Success", "DeliveryStreamName", aws_kinesis_firehose_delivery_stream.central_logs.name, { stat = "Sum", period = 300 }],
            ["AWS/Firehose", "DeliveryToS3.Error", "DeliveryStreamName", aws_kinesis_firehose_delivery_stream.central_logs.name, { stat = "Sum", period = 300 }]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "Livraison Firehose"
          region  = var.region
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 12
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ES", "CPUUtilization", "DomainName", aws_elasticsearch_domain.logs.domain_name, "ClientId", data.aws_caller_identity.current.account_id, { stat = "Average", period = 300 }],
            ["AWS/ES", "JVMMemoryPressure", "DomainName", aws_elasticsearch_domain.logs.domain_name, "ClientId", data.aws_caller_identity.current.account_id, { stat = "Average", period = 300 }]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "Performance OpenSearch"
          region  = var.region
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 18
        width  = 24
        height = 6
        properties = {
          query   = "SOURCE '/aws/cloudtrail/accessweaver-${var.environment}' | fields @timestamp, eventName, userIdentity.arn, errorCode, errorMessage\n| filter errorCode != ''\n| sort @timestamp desc\n| limit 20"
          region  = var.region
          title   = "Erreurs API Récentes"
          view    = "table"
        }
      }
    ]
  })
}

# Tableau de bord CloudWatch pour le suivi de conformité
resource "aws_cloudwatch_dashboard" "compliance_monitoring" {
  dashboard_name = "accessweaver-${var.environment}-compliance-monitoring"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/Config", "ConfigRuleEvaluations", "RuleName", "required-tags", { stat = "Sum", period = 3600 }],
            ["AWS/Config", "ConfigRuleEvaluations", "RuleName", "encrypted-volumes", { stat = "Sum", period = 3600 }],
            ["AWS/Config", "ConfigRuleEvaluations", "RuleName", "s3-bucket-public-read-prohibited", { stat = "Sum", period = 3600 }],
            ["AWS/Config", "ConfigRuleEvaluations", "RuleName", "root-account-mfa-enabled", { stat = "Sum", period = 3600 }],
            ["AWS/Config", "ConfigRuleEvaluations", "RuleName", "cloudtrail-enabled", { stat = "Sum", period = 3600 }]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "Évaluations des Règles Config"
          region  = var.region
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Config", "ConfigHistoryItemRecordingCount", { stat = "Sum", period = 86400 }]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "Éléments d'historique Config"
          region  = var.region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Config", "MemberAccountStatusCount", "Status", "COMPLIANT", { stat = "Sum", period = 86400 }],
            ["AWS/Config", "MemberAccountStatusCount", "Status", "NON_COMPLIANT", { stat = "Sum", period = 86400 }]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "Statut de Conformité des Comptes"
          region  = var.region
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 8
        properties = {
          query   = "SOURCE '/aws/config/configuration-items' | fields @timestamp, resourceType, resourceId, configurationItemStatus, resourceDeleted\n| sort @timestamp desc\n| limit 20"
          region  = var.region
          title   = "Changements de Configuration Récents"
          view    = "table"
        }
      }
    ]
  })
}
```

### Visualisations et Rapports QuickSight

AWS QuickSight permet de créer des rapports interactifs et des visualisations avancées basées sur les données d'audit.

```hcl
# Jeu de données QuickSight pour l'analyse d'audit
resource "aws_quicksight_data_source" "audit_logs" {
  name                = "accessweaver-${var.environment}-audit-logs"
  type                = "S3"
  aws_account_id      = data.aws_caller_identity.current.account_id
  
  parameters {
    s3 {
      manifest_file_location {
        bucket = aws_s3_bucket.central_logs.id
        key    = "quicksight/audit-logs-manifest.json"
      }
    }
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-audit-logs"
    Environment = var.environment
    Service     = "audit-visualization"
  }
}

# Création du manifeste S3 pour QuickSight
resource "aws_s3_object" "quicksight_manifest" {
  bucket  = aws_s3_bucket.central_logs.id
  key     = "quicksight/audit-logs-manifest.json"
  content = jsonencode({
    fileLocations = [
      {
        URIPrefixes = [
          "s3://${aws_s3_bucket.central_logs.id}/central-logs/"
        ]
      }
    ],
    globalUploadSettings = {
      format          = "JSON",
      delimiter       = ",",
      textqualifier   = "'",
      containsHeader  = "true"
    }
  })
  
  content_type = "application/json"
  
  tags = {
    Name        = "accessweaver-${var.environment}-quicksight-manifest"
    Environment = var.environment
    Service     = "audit-visualization"
  }
}

# Jeu de données QuickSight
resource "aws_quicksight_data_set" "audit_analysis" {
  name          = "accessweaver-${var.environment}-audit-analysis"
  aws_account_id = data.aws_caller_identity.current.account_id
  data_source_id = aws_quicksight_data_source.audit_logs.id
  
  physical_table_map {
    physical_table_map_id = "audit_logs_table"
    s3_source {
      data_source_arn = aws_quicksight_data_source.audit_logs.arn
      upload_settings {
        format = "JSON"
        start_from_row = 1
        contains_header = true
      }
      input_columns = [
        {
          name = "eventTime"
          type = "DATETIME"
        },
        {
          name = "eventSource"
          type = "STRING"
        },
        {
          name = "eventName"
          type = "STRING"
        },
        {
          name = "awsRegion"
          type = "STRING"
        },
        {
          name = "sourceIPAddress"
          type = "STRING"
        },
        {
          name = "userIdentity.type"
          type = "STRING"
        },
        {
          name = "userIdentity.principalId"
          type = "STRING"
        },
        {
          name = "userIdentity.arn"
          type = "STRING"
        },
        {
          name = "errorCode"
          type = "STRING"
        },
        {
          name = "errorMessage"
          type = "STRING"
        }
      ]
    }
  }
  
  logical_table_map {
    logical_table_map_id = "audit_logs_logical"
    alias = "audit_logs"
    source {
      physical_table_id = "audit_logs_table"
    }
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-audit-analysis"
    Environment = var.environment
    Service     = "audit-visualization"
  }
}
```
## 📜 Conformité Réglementaire

Le système d'audit d'AccessWeaver est conçu pour répondre aux exigences de diverses réglementations et normes de sécurité, garantissant que l'organisation peut démontrer sa conformité lors d'audits externes. Cette section décrit comment AccessWeaver implémente les contrôles nécessaires pour satisfaire aux exigences réglementaires.

### Cadres de Conformité

AccessWeaver est conçu pour répondre aux exigences de multiples cadres réglementaires et normes de sécurité, notamment :

| Réglementation | Description | Impact sur l'Audit |
|----------------|-------------|-------------------|
| RGPD | Règlement Général sur la Protection des Données | Journalisation des accès aux données personnelles, traçabilité des modifications, droit à l'oubli |
| PCI-DSS | Payment Card Industry Data Security Standard | Audit des accès aux systèmes de paiement, journalisation des événements, revue des logs quotidienne |
| SOC 2 | Service Organization Control 2 | Traçabilité des actions, preuves de contrôles, surveillance continue |
| ISO 27001 | Norme internationale de sécurité de l'information | Documentation des contrôles, évaluation des risques, amélioration continue |
| HIPAA | Health Insurance Portability and Accountability Act | Protection des données de santé, journalisation des accès, chiffrement |

### Configuration AWS Config pour la Conformité

```hcl
# Règles AWS Config pour la conformité réglementaire
resource "aws_config_rule" "compliance_rules" {
  for_each = {
    # Règles RGPD
    "s3-default-encryption-kms" = {
      description      = "S'assure que tous les buckets S3 sont chiffrés avec KMS"
      source_identifier = "S3_DEFAULT_ENCRYPTION_KMS"
      tags             = merge(local.common_tags, { Compliance = "RGPD,PCI-DSS" })
    },
    "kms-cmk-not-scheduled-for-deletion" = {
      description      = "Vérifie que les clés KMS ne sont pas programmées pour suppression"
      source_identifier = "KMS_CMK_NOT_SCHEDULED_FOR_DELETION"
      tags             = merge(local.common_tags, { Compliance = "RGPD,PCI-DSS,SOC2" })
    },
    "vpc-flow-logs-enabled" = {
      description      = "Vérifie que VPC Flow Logs est activé dans tous les VPCs"
      source_identifier = "VPC_FLOW_LOGS_ENABLED"
      tags             = merge(local.common_tags, { Compliance = "RGPD,PCI-DSS,SOC2,ISO27001" })
    },
    "cloudtrail-security-trail-enabled" = {
      description      = "Vérifie qu'un trail CloudTrail multi-régions est activé"
      source_identifier = "CLOUD_TRAIL_SECURITY_TRAIL_ENABLED"
      tags             = merge(local.common_tags, { Compliance = "RGPD,PCI-DSS,SOC2,ISO27001,HIPAA" })
    },
    
    # Règles PCI-DSS
    "restricted-ssh" = {
      description      = "Vérifie que les groupes de sécurité n'autorisent pas l'accès SSH illimité"
      source_identifier = "RESTRICTED_INCOMING_TRAFFIC"
      input_parameters  = jsonencode({
        blockedPort1 = "22"
      })
      tags             = merge(local.common_tags, { Compliance = "PCI-DSS,SOC2,ISO27001" })
    },
    "acm-certificate-expiration-check" = {
      description      = "Vérifie l'expiration des certificats ACM"
      source_identifier = "ACM_CERTIFICATE_EXPIRATION_CHECK"
      input_parameters  = jsonencode({
        daysToExpiration = "30"
      })
      tags             = merge(local.common_tags, { Compliance = "PCI-DSS,SOC2" })
    },
    "iam-password-policy" = {
      description      = "Vérifie que la politique de mot de passe IAM répond aux exigences PCI-DSS"
      source_identifier = "IAM_PASSWORD_POLICY"
      input_parameters  = jsonencode({
        RequireUppercaseCharacters = "true"
        RequireLowercaseCharacters = "true"
        RequireSymbols = "true"
        RequireNumbers = "true"
        MinimumPasswordLength = "14"
        PasswordReusePrevention = "24"
        MaxPasswordAge = "90"
      })
      tags             = merge(local.common_tags, { Compliance = "PCI-DSS,SOC2,ISO27001" })
    },
    
    # Règles SOC 2
    "cloudwatch-alarm-action-check" = {
      description      = "Vérifie que les alarmes CloudWatch ont des actions configurées"
      source_identifier = "CLOUDWATCH_ALARM_ACTION_CHECK"
      tags             = merge(local.common_tags, { Compliance = "SOC2,ISO27001" })
    },
    "elasticsearch-logs-to-cloudwatch" = {
      description      = "Vérifie que les logs Elasticsearch sont envoyés à CloudWatch"
      source_identifier = "ELASTICSEARCH_LOGS_TO_CLOUDWATCH"
      tags             = merge(local.common_tags, { Compliance = "SOC2" })
    },
    
    # Règles ISO 27001
    "rds-storage-encrypted" = {
      description      = "Vérifie que les instances RDS sont chiffrées"
      source_identifier = "RDS_STORAGE_ENCRYPTED"
      tags             = merge(local.common_tags, { Compliance = "ISO27001,RGPD,PCI-DSS,HIPAA" })
    },
    "guardduty-enabled-centralized" = {
      description      = "Vérifie que GuardDuty est activé"
      source_identifier = "GUARDDUTY_ENABLED_CENTRALIZED"
      tags             = merge(local.common_tags, { Compliance = "ISO27001,SOC2" })
    },
    
    # Règles HIPAA
    "dynamodb-table-encrypted-kms" = {
      description      = "Vérifie que les tables DynamoDB sont chiffrées avec KMS"
      source_identifier = "DYNAMODB_TABLE_ENCRYPTED_KMS"
      tags             = merge(local.common_tags, { Compliance = "HIPAA,RGPD" })
    },
    "encrypted-volumes" = {
      description      = "Vérifie que les volumes EBS sont chiffrés"
      source_identifier = "ENCRYPTED_VOLUMES"
      tags             = merge(local.common_tags, { Compliance = "HIPAA,RGPD,PCI-DSS" })
    }
  }
  
  name        = each.key
  description = each.value.description
  
  source {
    owner             = "AWS"
    source_identifier = each.value.source_identifier
  }
  
  input_parameters = lookup(each.value, "input_parameters", null)
  
  tags = lookup(each.value, "tags", local.common_tags)
}

# Règle Config personnalisée pour vérifier la rotation des logs d'audit
resource "aws_config_rule" "audit_log_rotation_check" {
  name        = "audit-log-rotation-check"
  description = "Vérifie que les politiques de cycle de vie sont configurées pour les buckets de logs d'audit"
  
  source {
    owner             = "CUSTOM_LAMBDA"
    source_identifier = aws_lambda_function.audit_log_rotation_check.arn
  }
  
  scope {
    compliance_resource_types = ["AWS::S3::Bucket"]
  }
  
  depends_on = [aws_lambda_permission.config_invoke_audit_log_rotation_check]
  
  tags = merge(local.common_tags, {
    Compliance = "RGPD,PCI-DSS,SOC2,ISO27001,HIPAA"
  })
}

resource "aws_lambda_function" "audit_log_rotation_check" {
  function_name = "accessweaver-${var.environment}-audit-log-rotation-check"
  role          = aws_iam_role.config_lambda.arn
  runtime       = "java21"
  handler       = "com.accessweaver.audit.compliance.AuditLogRotationCheckHandler"
  timeout       = 60
  memory_size   = 256
  
  filename         = "${path.module}/lambda/audit-log-rotation-check.jar"
  source_code_hash = filebase64sha256("${path.module}/lambda/audit-log-rotation-check.jar")
  
  environment {
    variables = {
      LOG_BUCKET_PREFIXES = "accessweaver-${var.environment}-"
      MIN_TRANSITION_DAYS = "30"
      MIN_EXPIRATION_DAYS = var.environment == "production" ? "365" : "180"
    }
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-audit-log-rotation-check"
    Environment = var.environment
    Service     = "audit-compliance"
  }
}

resource "aws_lambda_permission" "config_invoke_audit_log_rotation_check" {
  statement_id  = "AllowExecutionFromConfig"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.audit_log_rotation_check.function_name
  principal     = "config.amazonaws.com"
}

# Pack de conformité AWS Config
resource "aws_config_conformance_pack" "accessweaver_compliance" {
  name            = "accessweaver-${var.environment}-compliance-pack"
  delivery_s3_bucket = aws_s3_bucket.config.id
  
  template_body = <<EOF
Resources:
  IAMUserMFAEnabled:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: iam-user-mfa-enabled
      Description: Vérifie que les utilisateurs IAM ont l'authentification MFA activée
      Source:
        Owner: AWS
        SourceIdentifier: IAM_USER_MFA_ENABLED
      
  IAMRootMFAEnabled:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: root-account-mfa-enabled
      Description: Vérifie que l'utilisateur root a l'authentification MFA activée
      Source:
        Owner: AWS
        SourceIdentifier: ROOT_ACCOUNT_MFA_ENABLED
  
  CloudTrailCloudWatchLogsEnabled:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: cloudtrail-cloudwatch-logs-enabled
      Description: Vérifie que CloudTrail envoie les logs à CloudWatch Logs
      Source:
        Owner: AWS
        SourceIdentifier: CLOUDTRAIL_CLOUDWATCH_LOGS_ENABLED
  
  ElasticsearchEncryptedAtRest:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: elasticsearch-encrypted-at-rest
      Description: Vérifie que les domaines Elasticsearch sont chiffrés au repos
      Source:
        Owner: AWS
        SourceIdentifier: ELASTICSEARCH_ENCRYPTED_AT_REST
  
  RDSSnapshotsPublicProhibited:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: rds-snapshots-public-prohibited
      Description: Vérifie que les snapshots RDS ne sont pas publics
      Source:
        Owner: AWS
        SourceIdentifier: RDS_SNAPSHOTS_PUBLIC_PROHIBITED
  
  S3BucketPublicReadProhibited:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: s3-bucket-public-read-prohibited
      Description: Vérifie que les buckets S3 n'autorisent pas l'accès public en lecture
      Source:
        Owner: AWS
        SourceIdentifier: S3_BUCKET_PUBLIC_READ_PROHIBITED
  
  S3BucketPublicWriteProhibited:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: s3-bucket-public-write-prohibited
      Description: Vérifie que les buckets S3 n'autorisent pas l'accès public en écriture
      Source:
        Owner: AWS
        SourceIdentifier: S3_BUCKET_PUBLIC_WRITE_PROHIBITED
  
  S3BucketReplicationEnabled:
    Type: AWS::Config::ConfigRule
    Properties:
      ConfigRuleName: s3-bucket-replication-enabled
      Description: Vérifie que les buckets S3 ont la réplication activée
      Source:
        Owner: AWS
        SourceIdentifier: S3_BUCKET_REPLICATION_ENABLED
EOF
  
  depends_on = [aws_config_configuration_recorder.main]
}

# AWS Security Hub pour la vue agrégée de conformité
resource "aws_securityhub_account" "main" {}

# Activation des standards de sécurité
resource "aws_securityhub_standards_subscription" "pci_dss" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${var.region}::standards/pci-dss/v/3.2.1"
}

resource "aws_securityhub_standards_subscription" "cis" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${var.region}::standards/cis-aws-foundations-benchmark/v/1.2.0"
}

resource "aws_securityhub_standards_subscription" "aws_foundational" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${var.region}::standards/aws-foundational-security-best-practices/v/1.0.0"
}
```

### Rapports de Conformité Automatisés

AccessWeaver génère automatiquement des rapports de conformité pour faciliter les audits et les revues.

```hcl
# Lambda pour la génération de rapports de conformité
resource "aws_lambda_function" "compliance_reporter" {
  function_name = "accessweaver-${var.environment}-compliance-reporter"
  role          = aws_iam_role.compliance_reporter.arn
  runtime       = "java21"
  handler       = "com.accessweaver.audit.compliance.ComplianceReporterHandler"
  timeout       = 300
  memory_size   = 512
  
  filename         = "${path.module}/lambda/compliance-reporter.jar"
  source_code_hash = filebase64sha256("${path.module}/lambda/compliance-reporter.jar")
  
  environment {
    variables = {
      REPORT_BUCKET       = aws_s3_bucket.compliance_reports.id
      REPORT_PREFIX       = "compliance-reports/"
      SECURITYHUB_ENABLED = "true"
      CONFIG_ENABLED      = "true"
      SNS_TOPIC_ARN       = aws_sns_topic.compliance_reports.arn
      ENVIRONMENT         = var.environment
    }
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-compliance-reporter"
    Environment = var.environment
    Service     = "audit-compliance"
  }
}

# Bucket S3 pour les rapports de conformité
resource "aws_s3_bucket" "compliance_reports" {
  bucket = "accessweaver-${var.environment}-compliance-reports"
  
  tags = {
    Name        = "accessweaver-${var.environment}-compliance-reports"
    Environment = var.environment
    Service     = "audit-compliance"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "compliance_reports_encryption" {
  bucket = aws_s3_bucket.compliance_reports.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "compliance_reports_lifecycle" {
  bucket = aws_s3_bucket.compliance_reports.id
  
  rule {
    id      = "compliance-reports-retention"
    status  = "Enabled"
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    expiration {
      days = var.environment == "production" ? 2555 : 730  # 7 ans pour la production, 2 ans pour les autres
    }
  }
}

resource "aws_s3_bucket_public_access_block" "compliance_reports_public_access_block" {
  bucket = aws_s3_bucket.compliance_reports.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Événement CloudWatch pour déclencher le rapport périodique
resource "aws_cloudwatch_event_rule" "compliance_report_scheduler" {
  name                = "accessweaver-${var.environment}-compliance-report-scheduler"
  description         = "Génère des rapports de conformité périodiques"
  schedule_expression = "cron(0 1 1 * ? *)"  # Premier jour de chaque mois à 1h du matin
  
  tags = {
    Name        = "accessweaver-${var.environment}-compliance-report-scheduler"
    Environment = var.environment
    Service     = "audit-compliance"
  }
}

resource "aws_cloudwatch_event_target" "compliance_report_scheduler" {
  rule      = aws_cloudwatch_event_rule.compliance_report_scheduler.name
  target_id = "GenerateComplianceReport"
  arn       = aws_lambda_function.compliance_reporter.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_compliance_reporter" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.compliance_reporter.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.compliance_report_scheduler.arn
}

# Topic SNS pour les notifications de rapports de conformité
resource "aws_sns_topic" "compliance_reports" {
  name              = "accessweaver-${var.environment}-compliance-reports"
  kms_master_key_id = aws_kms_key.sns.id
  
  tags = {
    Name        = "accessweaver-${var.environment}-compliance-reports"
    Environment = var.environment
    Service     = "audit-compliance"
  }
}

# Abonnements SNS pour les notifications de conformité
resource "aws_sns_topic_subscription" "compliance_reports_email" {
  topic_arn = aws_sns_topic.compliance_reports.arn
  protocol  = "email"
  endpoint  = "compliance-team@accessweaver.com"
}
```

### Code Java pour le Générateur de Rapports de Conformité

Voici un exemple de la classe Java utilisée par la fonction Lambda pour générer les rapports de conformité :

```java
package com.accessweaver.audit.compliance;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.ScheduledEvent;
import com.amazonaws.services.securityhub.AWSSecurityHub;
import com.amazonaws.services.securityhub.AWSSecurityHubClientBuilder;
import com.amazonaws.services.securityhub.model.GetInsightsRequest;
import com.amazonaws.services.securityhub.model.GetInsightsResult;
import com.amazonaws.services.config.AmazonConfig;
import com.amazonaws.services.config.AmazonConfigClientBuilder;
import com.amazonaws.services.config.model.DescribeComplianceByConfigRuleRequest;
import com.amazonaws.services.config.model.DescribeComplianceByConfigRuleResult;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.sns.AmazonSNS;
import com.amazonaws.services.sns.AmazonSNSClientBuilder;
import com.amazonaws.services.sns.model.PublishRequest;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.csv.CsvMapper;
import com.fasterxml.jackson.dataformat.csv.CsvSchema;

import java.io.ByteArrayInputStream;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

public class ComplianceReporterHandler implements RequestHandler<ScheduledEvent, String> {
    
    private final AmazonConfig configClient;
    private final AWSSecurityHub securityHubClient;
    private final AmazonS3 s3Client;
    private final AmazonSNS snsClient;
    private final String reportBucket;
    private final String reportPrefix;
    private final String snsTopicArn;
    private final String environment;
    private final boolean securityHubEnabled;
    private final boolean configEnabled;
    private final ObjectMapper jsonMapper = new ObjectMapper();
    private final CsvMapper csvMapper = new CsvMapper();
    
    public ComplianceReporterHandler() {
        this.configClient = AmazonConfigClientBuilder.defaultClient();
        this.securityHubClient = AWSSecurityHubClientBuilder.defaultClient();
        this.s3Client = AmazonS3ClientBuilder.defaultClient();
        this.snsClient = AmazonSNSClientBuilder.defaultClient();
        
        this.reportBucket = System.getenv("REPORT_BUCKET");
        this.reportPrefix = System.getenv("REPORT_PREFIX");
        this.snsTopicArn = System.getenv("SNS_TOPIC_ARN");
        this.environment = System.getenv("ENVIRONMENT");
        this.securityHubEnabled = Boolean.parseBoolean(System.getenv("SECURITYHUB_ENABLED"));
        this.configEnabled = Boolean.parseBoolean(System.getenv("CONFIG_ENABLED"));
    }
    
    @Override
    public String handleRequest(ScheduledEvent event, Context context) {
        try {
            LocalDateTime now = LocalDateTime.now();
            String reportDate = now.format(DateTimeFormatter.ISO_LOCAL_DATE);
            
            // Génération du rapport
            Map<String, Object> complianceReport = new HashMap<>();
            complianceReport.put("reportDate", reportDate);
            complianceReport.put("environment", environment);
            
            if (configEnabled) {
                List<Map<String, Object>> configRulesCompliance = getConfigRulesCompliance();
                complianceReport.put("configRules", configRulesCompliance);
                
                // Générer CSV pour Config Rules
                String configCsvReport = generateCsvReport(configRulesCompliance, "ConfigRules");
                uploadReport(configCsvReport, reportDate, "config_rules_compliance.csv");
            }
            
            if (securityHubEnabled) {
                List<Map<String, Object>> securityHubFindings = getSecurityHubFindings();
                complianceReport.put("securityHubFindings", securityHubFindings);
                
                // Générer CSV pour Security Hub
                String securityHubCsvReport = generateCsvReport(securityHubFindings, "SecurityHub");
                uploadReport(securityHubCsvReport, reportDate, "security_hub_findings.csv");
            }
            
            // Générer rapport JSON complet
            String jsonReport = jsonMapper.writeValueAsString(complianceReport);
            uploadReport(jsonReport, reportDate, "compliance_report.json");
            
            // Notification de génération de rapport
            String reportUrl = String.format("https://s3.console.aws.amazon.com/s3/buckets/%s/%s%s/", 
                reportBucket, reportPrefix, reportDate);
            
            String message = String.format("Rapport de conformité généré pour l'environnement %s le %s.\n\n" +
                "URL du rapport: %s", environment, reportDate, reportUrl);
            
            PublishRequest publishRequest = new PublishRequest()
                .withTopicArn(snsTopicArn)
                .withSubject(String.format("Rapport de conformité AccessWeaver %s - %s", environment, reportDate))
                .withMessage(message);
            
            snsClient.publish(publishRequest);
            
            return "Rapport de conformité généré avec succès: " + reportUrl;
            
        } catch (Exception e) {
            context.getLogger().log("Erreur lors de la génération du rapport: " + e.getMessage());
            throw new RuntimeException("Échec de génération du rapport de conformité", e);
        }
    }
    
    private List<Map<String, Object>> getConfigRulesCompliance() {
        List<Map<String, Object>> results = new ArrayList<>();
        
        DescribeComplianceByConfigRuleRequest request = new DescribeComplianceByConfigRuleRequest();
        DescribeComplianceByConfigRuleResult result = configClient.describeComplianceByConfigRule(request);
        
        result.getComplianceByConfigRules().forEach(rule -> {
            Map<String, Object> ruleMap = new HashMap<>();
            ruleMap.put("ruleName", rule.getConfigRuleName());
            ruleMap.put("compliance", rule.getComplianceType());
            
            // Ajouter les détails de conformité
            List<Map<String, String>> complianceDetails = rule.getComplianceByResource().stream()
                .map(resource -> {
                    Map<String, String> resourceMap = new HashMap<>();
                    resourceMap.put("resourceId", resource.getResourceId());
                    resourceMap.put("resourceType", resource.getResourceType());
                    resourceMap.put("compliance", resource.getComplianceType());
                    return resourceMap;
                })
                .collect(Collectors.toList());
            
            ruleMap.put("resources", complianceDetails);
            results.add(ruleMap);
        });
        
        return results;
    }
    
    private List<Map<String, Object>> getSecurityHubFindings() {
        List<Map<String, Object>> results = new ArrayList<>();
        
        GetInsightsRequest request = new GetInsightsRequest();
        GetInsightsResult result = securityHubClient.getInsights(request);
        
        result.getInsights().forEach(insight -> {
            Map<String, Object> insightMap = new HashMap<>();
            insightMap.put("insightName", insight.getName());
            insightMap.put("insightArn", insight.getInsightArn());
            insightMap.put("groupByAttribute", insight.getGroupByAttribute());
            
            // Filtres associés à l'insight
            if (insight.getFilters() != null) {
                insightMap.put("filters", insight.getFilters());
            }
            
            results.add(insightMap);
        });
        
        return results;
    }
    
    private String generateCsvReport(List<Map<String, Object>> data, String type) throws Exception {
        CsvSchema.Builder schemaBuilder = CsvSchema.builder();
        
        // Définir les colonnes selon le type de rapport
        if ("ConfigRules".equals(type)) {
            schemaBuilder.addColumn("ruleName")
                         .addColumn("compliance");
        } else if ("SecurityHub".equals(type)) {
            schemaBuilder.addColumn("insightName")
                         .addColumn("insightArn")
                         .addColumn("groupByAttribute");
        }
        
        CsvSchema schema = schemaBuilder.build().withHeader();
        return csvMapper.writer(schema).writeValueAsString(data);
    }
    
    private void uploadReport(String content, String reportDate, String fileName) {
        String key = reportPrefix + reportDate + "/" + fileName;
        
        s3Client.putObject(
            reportBucket,
            key,
            new ByteArrayInputStream(content.getBytes()),
            null
        );
    }
}
```
## 🔍 Investigation des Incidents de Sécurité

Même avec les meilleures pratiques de sécurité en place, des incidents peuvent survenir. AccessWeaver a mis en place un processus structuré et des outils spécialisés pour l'investigation rapide et efficace des incidents de sécurité détectés par le système d'audit.

### Processus d'Investigation

AccessWeaver a mis en place un processus structuré pour l'investigation des incidents de sécurité détectés par le système d'audit.

┌───────────────────────────────────────────────────────────────────────┐ │ Processus d'Investigation │ │ │ │ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │ │ │ │ │ │ │ │ │ │ │ Détection │────►│ Triage │────►│ Analyse │ │ │ │ │ │ │ │ │ │ │ └─────────────┘ └─────────────┘ └──────┬──────┘ │ │ │ │ │ ▼ │ │ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │ │ │ │ │ │ │ │ │ │ │ Rapport │◄────│ Remédiation │◄────│ Containment │ │ │ │ │ │ │ │ │ │ │ └─────────────┘ └─────────────┘ └─────────────┘ │ │ │ └───────────────────────────────────────────────────────────────────────┘



### Outils d'Investigation

AccessWeaver utilise une combinaison d'outils natifs AWS et de solutions personnalisées pour l'investigation des incidents de sécurité.

```hcl
# Lambda pour l'investigation des incidents de sécurité
resource "aws_lambda_function" "incident_investigator" {
  function_name = "accessweaver-${var.environment}-incident-investigator"
  role          = aws_iam_role.incident_investigator.arn
  runtime       = "java21"
  handler       = "com.accessweaver.audit.incident.IncidentInvestigatorHandler"
  timeout       = 300
  memory_size   = 1024
  
  environment {
    variables = {
      CLOUDTRAIL_BUCKET = aws_s3_bucket.cloudtrail.id
      VPC_FLOW_LOGS_BUCKET = aws_s3_bucket.vpc_flow_logs.id
      WAF_LOGS_BUCKET = aws_s3_bucket.waf_logs.id
      APP_LOGS_BUCKET = aws_s3_bucket.app_logs.id
      SNS_TOPIC_ARN = aws_sns_topic.security_alerts.arn
      ENVIRONMENT = var.environment
    }
  }
  
  filename         = "${path.module}/lambda/incident-investigator.jar"
  source_code_hash = filebase64sha256("${path.module}/lambda/incident-investigator.jar")
  
  tags = {
    Name        = "accessweaver-${var.environment}-incident-investigator"
    Environment = var.environment
    Service     = "audit-incident"
  }
}

# API Gateway pour déclencher l'investigation
resource "aws_api_gateway_rest_api" "incident_api" {
  name        = "accessweaver-${var.environment}-incident-api"
  description = "API pour l'investigation des incidents"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-incident-api"
    Environment = var.environment
    Service     = "audit-incident"
  }
}

resource "aws_api_gateway_resource" "investigate" {
  rest_api_id = aws_api_gateway_rest_api.incident_api.id
  parent_id   = aws_api_gateway_rest_api.incident_api.root_resource_id
  path_part   = "investigate"
}

resource "aws_api_gateway_method" "investigate_post" {
  rest_api_id   = aws_api_gateway_rest_api.incident_api.id
  resource_id   = aws_api_gateway_resource.investigate.id
  http_method   = "POST"
  authorization_type = "AWS_IAM"
}

resource "aws_api_gateway_integration" "investigate_lambda" {
  rest_api_id = aws_api_gateway_rest_api.incident_api.id
  resource_id = aws_api_gateway_resource.investigate.id
  http_method = aws_api_gateway_method.investigate_post.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.incident_investigator.invoke_arn
}

# Journalisation des requêtes d'investigation
resource "aws_cloudwatch_log_group" "incident_api_logs" {
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.incident_api.name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
  
  tags = {
    Name        = "accessweaver-${var.environment}-incident-api-logs"
    Environment = var.environment
    Service     = "audit-incident"
  }
}

# Modèle de données pour l'incident
resource "aws_api_gateway_model" "incident_model" {
  rest_api_id  = aws_api_gateway_rest_api.incident_api.id
  name         = "IncidentModel"
  description  = "Modèle de données pour les incidents"
  content_type = "application/json"
  
  schema = jsonencode({
    "$schema" = "[http://json-schema.org/draft-04/schema#"](http://json-schema.org/draft-04/schema#")
    title = "IncidentModel"
    type = "object"
    properties = {
      incidentId = {
        type = "string"
      }
      incidentType = {
        type = "string"
        enum = ["UNAUTHORIZED_ACCESS", "DATA_EXFILTRATION", "COMPROMISED_CREDENTIALS", "MALWARE", "CONFIGURATION_CHANGE", "POLICY_VIOLATION", "OTHER"]
      }
      severity = {
        type = "string"
        enum = ["LOW", "MEDIUM", "HIGH", "CRITICAL"]
      }
      sourceIp = {
        type = "string"
      }
      resourceId = {
        type = "string"
      }
      timestamp = {
        type = "string"
        format = "date-time"
      }
      region = {
        type = "string"
      }
      accountId = {
        type = "string"
      }
      additionalDetails = {
        type = "object"
      }
    }
    required = ["incidentId", "incidentType", "severity", "timestamp"]
  })
}

# Bucket S3 pour les rapports d'investigation
resource "aws_s3_bucket" "incident_reports" {
  bucket = "accessweaver-${var.environment}-incident-reports"
  
  tags = {
    Name        = "accessweaver-${var.environment}-incident-reports"
    Environment = var.environment
    Service     = "audit-incident"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "incident_reports_encryption" {
  bucket = aws_s3_bucket.incident_reports.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "incident_reports_lifecycle" {
  bucket = aws_s3_bucket.incident_reports.id
  
  rule {
    id      = "incident-reports-retention"
    status  = "Enabled"
    
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
    
    transition {
      days          = 365
      storage_class = "GLACIER"
    }
    
    expiration {
      days = var.environment == "production" ? 2555 : 730  # 7 ans pour la production, 2 ans pour les autres
    }
  }
}

resource "aws_s3_bucket_public_access_block" "incident_reports_public_access_block" {
  bucket = aws_s3_bucket.incident_reports.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

```

### Code Java pour l'Investigateur d'Incidents
Voici un exemple de la classe Java utilisée par la fonction Lambda pour l'investigation des incidents :

```java
package com.accessweaver.audit.incident;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.GetObjectRequest;
import com.amazonaws.services.s3.model.ListObjectsV2Request;
import com.amazonaws.services.s3.model.ListObjectsV2Result;
import com.amazonaws.services.s3.model.S3Object;
import com.amazonaws.services.sns.AmazonSNS;
import com.amazonaws.services.sns.AmazonSNSClientBuilder;
import com.amazonaws.services.sns.model.PublishRequest;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.InputStreamReader;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.zip.GZIPInputStream;

public class IncidentInvestigatorHandler implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {
    
    private final AmazonS3 s3Client;
    private final AmazonSNS snsClient;
    private final String cloudtrailBucket;
    private final String vpcFlowLogsBucket;
    private final String wafLogsBucket;
    private final String appLogsBucket;
    private final String snsTopicArn;
    private final String environment;
    private final ObjectMapper objectMapper = new ObjectMapper();
    
    public IncidentInvestigatorHandler() {
        this.s3Client = AmazonS3ClientBuilder.defaultClient();
        this.snsClient = AmazonSNSClientBuilder.defaultClient();
        
        this.cloudtrailBucket = System.getenv("CLOUDTRAIL_BUCKET");
        this.vpcFlowLogsBucket = System.getenv("VPC_FLOW_LOGS_BUCKET");
        this.wafLogsBucket = System.getenv("WAF_LOGS_BUCKET");
        this.appLogsBucket = System.getenv("APP_LOGS_BUCKET");
        this.snsTopicArn = System.getenv("SNS_TOPIC_ARN");
        this.environment = System.getenv("ENVIRONMENT");
    }
    
    @Override
    public APIGatewayProxyResponseEvent handleRequest(APIGatewayProxyRequestEvent input, Context context) {
        try {
            // Analyser la demande d'investigation
            Incident incident = objectMapper.readValue(input.getBody(), Incident.class);
            
            // Valider l'incident
            if (incident.getIncidentId() == null || incident.getTimestamp() == null) {
                return createResponse(400, "ID d'incident et timestamp sont requis");
            }
            
            context.getLogger().log("Début de l'investigation pour l'incident: " + incident.getIncidentId());
            
            // Calculer la fenêtre temporelle pour la recherche (30 minutes avant et après l'incident)
            Instant incidentTime = Instant.parse(incident.getTimestamp());
            Instant startTime = incidentTime.minusSeconds(1800); // 30 minutes avant
            Instant endTime = incidentTime.plusSeconds(1800);    // 30 minutes après
            
            LocalDateTime startDateTime = LocalDateTime.ofInstant(startTime, ZoneId.systemDefault());
            LocalDateTime endDateTime = LocalDateTime.ofInstant(endTime, ZoneId.systemDefault());
            
            // Créer le rapport d'investigation
            Map<String, Object> investigationReport = new HashMap<>();
            investigationReport.put("incidentId", incident.getIncidentId());
            investigationReport.put("incidentType", incident.getIncidentType());
            investigationReport.put("severity", incident.getSeverity());
            investigationReport.put("timestamp", incident.getTimestamp());
            investigationReport.put("investigationStartTime", LocalDateTime.now().toString());
            
            // Collecter les journaux pertinents
            List<Map<String, Object>> cloudtrailEvents = collectCloudTrailEvents(startDateTime, endDateTime, incident);
            List<Map<String, Object>> vpcFlowLogs = collectVpcFlowLogs(startDateTime, endDateTime, incident);
            List<Map<String, Object>> wafLogs = collectWafLogs(startDateTime, endDateTime, incident);
            List<Map<String, Object>> appLogs = collectAppLogs(startDateTime, endDateTime, incident);
            
            investigationReport.put("cloudtrailEvents", cloudtrailEvents);
            investigationReport.put("vpcFlowLogs", vpcFlowLogs);
            investigationReport.put("wafLogs", wafLogs);
            investigationReport.put("appLogs", appLogs);
            
            // Analyser les données collectées
            Map<String, Object> analysis = analyzeData(cloudtrailEvents, vpcFlowLogs, wafLogs, appLogs, incident);
            investigationReport.put("analysis", analysis);
            
            // Générer les recommandations
            List<String> recommendations = generateRecommendations(analysis, incident);
            investigationReport.put("recommendations", recommendations);
            
            // Enregistrer le rapport d'investigation
            String reportKey = String.format("incidents/%s/%s_investigation.json", 
                                            incident.getIncidentId(),
                                            LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
            
            s3Client.putObject(
                "accessweaver-" + environment + "-incident-reports",
                reportKey,
                new ByteArrayInputStream(objectMapper.writeValueAsString(investigationReport).getBytes()),
                null
            );
            
            // Envoyer une notification
            String reportUrl = String.format("https://s3.console.aws.amazon.com/s3/object/%s/%s",
                                            "accessweaver-" + environment + "-incident-reports",
                                            reportKey);
            
            String message = String.format("Investigation terminée pour l'incident %s de type %s (sévérité %s).\n\n" +
                                          "Rapport disponible à: %s", 
                                          incident.getIncidentId(),
                                          incident.getIncidentType(),
                                          incident.getSeverity(),
                                          reportUrl);
            
            PublishRequest publishRequest = new PublishRequest()
                .withTopicArn(snsTopicArn)
                .withSubject(String.format("Investigation terminée - Incident %s", incident.getIncidentId()))
                .withMessage(message);
            
            snsClient.publish(publishRequest);
            
            // Répondre avec l'URL du rapport
            Map<String, String> responseBody = new HashMap<>();
            responseBody.put("message", "Investigation terminée avec succès");
            responseBody.put("reportUrl", reportUrl);
            
            return createResponse(200, objectMapper.writeValueAsString(responseBody));
            
        } catch (Exception e) {
            context.getLogger().log("Erreur lors de l'investigation: " + e.getMessage());
            return createResponse(500, "Erreur lors de l'investigation: " + e.getMessage());
        }
    }
    
    private List<Map<String, Object>> collectCloudTrailEvents(LocalDateTime startTime, LocalDateTime endTime, Incident incident) {
        // Logique pour collecter les événements CloudTrail pertinents
        List<Map<String, Object>> events = new ArrayList<>();
        
        // Implémenter la logique de recherche dans les logs CloudTrail
        // Utiliser s3Client pour récupérer les logs CloudTrail et les filtrer selon la période et les critères de l'incident
        
        return events;
    }
    
    private List<Map<String, Object>> collectVpcFlowLogs(LocalDateTime startTime, LocalDateTime endTime, Incident incident) {
        // Logique pour collecter les VPC Flow Logs pertinents
        List<Map<String, Object>> logs = new ArrayList<>();
        
        // Implémenter la logique de recherche dans les VPC Flow Logs
        
        return logs;
    }
    
    private List<Map<String, Object>> collectWafLogs(LocalDateTime startTime, LocalDateTime endTime, Incident incident) {
        // Logique pour collecter les logs WAF pertinents
        List<Map<String, Object>> logs = new ArrayList<>();
        
        // Implémenter la logique de recherche dans les logs WAF
        
        return logs;
    }
    
    private List<Map<String, Object>> collectAppLogs(LocalDateTime startTime, LocalDateTime endTime, Incident incident) {
        // Logique pour collecter les logs d'application pertinents
        List<Map<String, Object>> logs = new ArrayList<>();
        
        // Implémenter la logique de recherche dans les logs d'application
        
        return logs;
    }
    
    private Map<String, Object> analyzeData(List<Map<String, Object>> cloudtrailEvents,
                                         List<Map<String, Object>> vpcFlowLogs,
                                         List<Map<String, Object>> wafLogs,
                                         List<Map<String, Object>> appLogs,
                                         Incident incident) {
        Map<String, Object> analysis = new HashMap<>();
        
        // Implémenter l'analyse des données collectées
        // Par exemple, identifier des modèles suspects, des corrélations entre différents événements, etc.
        
        return analysis;
    }
    
    private List<String> generateRecommendations(Map<String, Object> analysis, Incident incident) {
        List<String> recommendations = new ArrayList<>();
        
        // Générer des recommandations basées sur l'analyse
        // Par exemple, suggérer des mesures de correction, des améliorations de sécurité, etc.
        
        return recommendations;
    }
    
    private APIGatewayProxyResponseEvent createResponse(int statusCode, String body) {
        APIGatewayProxyResponseEvent response = new APIGatewayProxyResponseEvent();
        response.setStatusCode(statusCode);
        response.setBody(body);
        
        Map<String, String> headers = new HashMap<>();
        headers.put("Content-Type", "application/json");
        response.setHeaders(headers);
        
        return response;
    }
    
    public static class Incident {
        private String incidentId;
        private String incidentType;
        private String severity;
        private String sourceIp;
        private String resourceId;
        private String timestamp;
        private String region;
        private String accountId;
        private Map<String, Object> additionalDetails;
        
        // Getters et setters
        public String getIncidentId() { return incidentId; }
        public void setIncidentId(String incidentId) { this.incidentId = incidentId; }
        
        public String getIncidentType() { return incidentType; }
        public void setIncidentType(String incidentType) { this.incidentType = incidentType; }
        
        public String getSeverity() { return severity; }
        public void setSeverity(String severity) { this.severity = severity; }
        
        public String getSourceIp() { return sourceIp; }
        public void setSourceIp(String sourceIp) { this.sourceIp = sourceIp; }
        
        public String getResourceId() { return resourceId; }
        public void setResourceId(String resourceId) { this.resourceId = resourceId; }
        
        public String getTimestamp() { return timestamp; }
        public void setTimestamp(String timestamp) { this.timestamp = timestamp; }
        
        public String getRegion() { return region; }
        public void setRegion(String region) { this.region = region; }
        
        public String getAccountId() { return accountId; }
        public void setAccountId(String accountId) { this.accountId = accountId; }
        
        public Map<String, Object> getAdditionalDetails() { return additionalDetails; }
        public void setAdditionalDetails(Map<String, Object> additionalDetails) { this.additionalDetails = additionalDetails; }
    }
}

```


### Protocole de Réponse aux Incidents
┌───────────────────────────────────────────────────────────────────────┐
│                    Protocole de Réponse aux Incidents                  │
│                                                                       │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐              │
│  │             │     │             │     │             │              │
│  │ Notification│────►│  Évaluation │────►│ Escalade    │              │
│  │             │     │             │     │             │              │
│  └─────────────┘     └─────────────┘     └──────┬──────┘              │
│                                                 │                     │
│                                                 ▼                     │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐              │
│  │             │     │             │     │             │              │
│  │ Post-mortem │◄────│ Restauration│◄────│ Containment │              │
│  │             │     │             │     │             │              │
│  └─────────────┘     └─────────────┘     └─────────────┘              │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘

### Meilleures Pratiques pour l'Investigation
1. Préservation des Preuves
  - Ne jamais modifier les journaux originaux
  - Créer des copies pour l'analyse
  - Documenter toutes les actions entreprises
2. Analyse Chronologique
  - Établir une chronologie précise des événements
  - Corréler les événements à travers différentes sources de journaux
  - Identifier les écarts et anomalies
3. Isolation de l'Impact
  - Déterminer l'étendue de l'incident
  - Identifier tous les systèmes potentiellement affectés
  - Évaluer l'impact sur les données sensibles
4. Documentation
  - Maintenir un journal détaillé de l'investigation
  - Documenter les preuves collectées
  - Enregistrer toutes les actions et décisions
5. Amélioration Continue
  - Analyser les causes profondes
  - Mettre à jour les procédures de détection et de réponse
  - Améliorer les contrôles de sécurité basés sur les leçons apprises

## 🔒 Conclusion

Le module d'audit d'AccessWeaver fournit une approche complète et robuste pour la journalisation, la surveillance et l'analyse des activités dans l'infrastructure AWS. En mettant l'accent sur l'exhaustivité, l'intégrité et la confidentialité des journaux, ce module permet à AccessWeaver de maintenir une posture de sécurité solide, de détecter rapidement les incidents de sécurité et de répondre efficacement aux exigences de conformité réglementaire.

Ce document a présenté une architecture d'audit complète couvrant :

1. La journalisation à tous les niveaux (AWS, réseau, application)
2. La centralisation et le stockage sécurisé des journaux
3. Les systèmes d'alerte et de détection
4. Les tableaux de bord et la visualisation des données
5. La conformité avec les réglementations applicables
6. Les processus d'investigation des incidents

En suivant les recommandations et les configurations détaillées dans ce document, AccessWeaver peut assurer une traçabilité complète des actions dans son infrastructure, détecter rapidement les activités suspectes, et démontrer sa conformité aux exigences réglementaires.

L'architecture centralisée des journaux, combinée à des outils d'analyse avancés et des procédures d'investigation structurées, garantit que les équipes de sécurité disposent des informations nécessaires pour protéger efficacement l'infrastructure et les données d'AccessWeaver.
