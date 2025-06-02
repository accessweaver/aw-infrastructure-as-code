# 💾 Module Backup - AccessWeaver Infrastructure

**Version :** 1.0  
**Date :** Juin 2025  
**Module :** modules/backup  
**Responsable :** Équipe Platform AccessWeaver

---

## 🎯 Vue d'Ensemble

### Objectif Principal
Le module Backup fournit une solution de **sauvegarde complète et automatisée** pour l'ensemble des données critiques de la plateforme AccessWeaver. Il met en œuvre AWS Backup, un service géré qui centralise et automatise la protection des données dans les services AWS, offrant une stratégie robuste de récupération après sinistre (DR) et de conformité règlementaire.

### Ressources Couvertes

```
┌───────────────────────────────────────────────────────────┐
│                 AWS Backup Vault                          │
│                     /    |   \                            │
│                    /     |    \                           │
│                   /      |     \                          │
│       ┌───────────┐ ┌───────────┐ ┌───────────┐           │
│       │    RDS    │ │   EFS     │ │  DynamoDB │           │
│       └───────────┘ └───────────┘ └───────────┘           │
│              |            |             |                 │
│       ┌───────────┐ ┌───────────┐ ┌─────────────┐         │
│       │  ECS/ECR  │ │    S3     │ │  ElastiCache│         │
│       └───────────┘ └───────────┘ └─────────────┘         │
│                                                           │
│       ┌──────────────────────────────────────────┐        │
│       │     Plans de Backup par Environnement    │        │
│       └──────────────────────────────────────────┘        │
└───────────────────────────────────────────────────────────┘
```

### Caractéristiques Principales
- **Backups automatiques** : Programmation flexible des sauvegardes (quotidienne, hebdomadaire, mensuelle)
- **Rétention paramétrable** : Politiques de conservation adaptées à chaque environnement
- **Chiffrement natif** : Protection des données au repos avec KMS
- **Cycle de vie des backups** : Transition automatique vers des stockages moins coûteux
- **Restauration simplifiée** : Processus standardisé pour la récupération des données
- **Validation automatique** : Tests réguliers de l'intégrité des backups
- **Audit et conformité** : Traçabilité complète pour les exigences réglementaires

---

## 🏗️ Architecture par Environnement

### Stratégie Multi-Environnement

| Aspect | Development | Staging | Production |
|--------|-------------|---------|------------|
| **⏰ Fréquence** | Quotidienne | Quotidienne | Quotidienne + Hebdomadaire + Mensuelle |
| **💾 Reten. Court Terme** | 7 jours | 14 jours | 30 jours |
| **📆 Reten. Long Terme** | Non | 30 jours | 1 an + 7 ans (archives) |
| **🔒 Chiffrement** | Par défaut | KMS dédié | KMS multi-régional |
| **🔄 Cop. Trans-régionale** | Non | Non | Oui |
| **🧰 Test de restauration** | Manuel | Automatique (mensuel) | Automatique (hebdomadaire) |
| **🎯 RPO** | 24h | 24h | 1h pour RDS, 24h pour autres |
| **⏱️ RTO** | <24h | <12h | <4h |

### Plan de Backup Development

```
┌─────────────────────────────────────────────────────────┐
│            AWS Backup - Environnement Development          │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Backup Vault                                      │   │
│  │  - accessweaver-dev-backup-vault                  │   │
│  │  - Rétention: 7 jours                             │   │
│  │  - Stockage: S3 Standard uniquement                │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Plan Quotidien                                    │   │
│  │  - Nom: accessweaver-dev-daily                     │   │
│  │  - Fenêtre: 22h00 - 02h00                         │   │
│  │  - Fréquence: Tous les jours                       │   │
│  │  - Services: RDS, EFS, S3                           │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Notifications                                     │   │
│  │  - SNS Topic: accessweaver-dev-backup-alerts        │   │
│  │  - Notifications: Échecs uniquement               │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Plan de Backup Staging

```
┌─────────────────────────────────────────────────────────┐
│            AWS Backup - Environnement Staging              │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Backup Vault                                      │   │
│  │  - accessweaver-staging-backup-vault              │   │
│  │  - Rétention: 14 jours (court terme)              │   │
│  │  - Rétention: 30 jours (long terme)               │   │
│  │  - Stockage: S3 Standard + S3 IA                   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Plan Quotidien                                    │   │
│  │  - Nom: accessweaver-staging-daily                 │   │
│  │  - Fenêtre: 22h00 - 02h00                         │   │
│  │  - Fréquence: Tous les jours                       │   │
│  │  - Services: RDS, EFS, S3, DynamoDB, ElastiCache     │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Tests de Restauration                            │   │
│  │  - Fréquence: Mensuelle                           │   │
│  │  - Scope: RDS uniquement                           │   │
│  │  - Environnement de test dédié                    │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Notifications                                     │   │
│  │  - SNS Topic: accessweaver-staging-backup-alerts    │   │
│  │  - Notifications: Échecs et succès                │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Plan de Backup Production

```
┌─────────────────────────────────────────────────────────┐
│            AWS Backup - Environnement Production           │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Backup Vault Principal                           │   │
│  │  - accessweaver-prod-backup-vault-primary         │   │
│  │  - Région: eu-west-1                             │   │
│  │  - Rétention: 30 jours (court terme)              │   │
│  │  - Rétention: 1 an (long terme)                   │   │
│  │  - Stockage: S3 Standard + S3 IA + Glacier        │   │
│  │  - Chiffrement: KMS dédié multi-régional          │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Backup Vault Secondaire                          │   │
│  │  - accessweaver-prod-backup-vault-secondary       │   │
│  │  - Région: eu-central-1                          │   │
│  │  - Copie cross-région des backups critiques        │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Backup Vault Archive                             │   │
│  │  - accessweaver-prod-backup-vault-archive         │   │
│  │  - Rétention: 7 ans                              │   │
│  │  - Stockage: Glacier Deep Archive                  │   │
│  │  - Transition automatique après 1 an              │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Plan Horaire (Tier 1)                            │   │
│  │  - Nom: accessweaver-prod-hourly                   │   │
│  │  - Services: RDS uniquement                        │   │
│  │  - Fenêtre: Chaque heure                          │   │
│  │  - Rétention: 24 heures                           │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Plan Quotidien (Tier 1 + 2)                      │   │
│  │  - Nom: accessweaver-prod-daily                    │   │
│  │  - Services: Tous                                  │   │
│  │  - Fenêtre: 22h00 - 02h00                         │   │
│  │  - Réplication cross-région: Oui                  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Plan Hebdomadaire (Tier 1 + 2)                   │   │
│  │  - Nom: accessweaver-prod-weekly                   │   │
│  │  - Services: Tous                                  │   │
│  │  - Jour: Dimanche                                 │   │
│  │  - Fenêtre: 00h00 - 06h00                         │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Plan Mensuel (Tier 1 + 2)                        │   │
│  │  - Nom: accessweaver-prod-monthly                  │   │
│  │  - Services: Tous                                  │   │
│  │  - Jour: 1er du mois                              │   │
│  │  - Stockage à long terme: Oui                     │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Tests de Restauration                            │   │
│  │  - Fréquence: Hebdomadaire (RDS)                  │   │
│  │  - Fréquence: Mensuelle (autres services)         │   │
│  │  - Environnement de DR dédié                      │   │
│  │  - Validation automatisée                         │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 🔧 Configuration Terraform

### Structure du Module

Le module Backup implémente une solution complète de sauvegarde basée sur AWS Backup, avec la structure suivante :

```hcl
modules/
└── backup/
    ├── main.tf            # Ressources principales AWS Backup
    ├── variables.tf       # Déclaration des variables d'entrée
    ├── outputs.tf         # Sorties du module
    ├── locals.tf          # Variables locales et logique conditionnelle
    ├── vault.tf           # Configuration des coffres de sauvegarde
    ├── plans.tf           # Plans de sauvegarde par environnement
    ├── selection.tf       # Sélection des ressources à sauvegarder
    ├── notifications.tf   # Configuration des notifications SNS
    └── kms.tf             # Clés de chiffrement dédiées
```

### Utilisation du Module

```hcl
module "backup" {
  source = "../../modules/backup"
  
  environment               = "production"
  backup_vault_name         = "accessweaver-prod-backup-vault"
  enable_cross_region_backup = true
  secondary_region          = "eu-central-1"
  
  # Configuration des rétentions
  short_term_retention      = 30   # jours
  long_term_retention       = 365  # jours
  archive_retention         = 2555 # jours (7 ans)
  
  # Sélection des ressources
  rds_instance_arns         = module.database.db_instance_arns
  dynamodb_table_arns       = module.dynamodb.table_arns
  elasticache_cluster_arns  = module.redis.redis_cluster_arns
  efs_arns                  = module.storage.efs_arns
  s3_bucket_arns            = module.storage.bucket_arns
  
  # Plans de sauvegarde
  enable_hourly_backups     = true
  hourly_backup_resources   = ["rds"]
  
  # Notifications
  notification_email        = "platform-alerts@accessweaver.com"
  
  # Test de restauration automatisé
  enable_recovery_testing   = true
  recovery_test_frequency   = "weekly"
  
  tags = {
    Project     = "AccessWeaver"
    Environment = "production"
    Managed     = "terraform"
  }
}
```

### Variables d'Entrée Principales

| Nom Variable | Type | Description | Défaut |
|--------------|------|-------------|--------|
| `environment` | string | Environnement de déploiement | `"development"` |
| `backup_vault_name` | string | Nom du coffre de sauvegarde principal | `"accessweaver-backup-vault"` |
| `enable_cross_region_backup` | bool | Activer la réplication cross-région | `false` |
| `secondary_region` | string | Région secondaire pour la réplication | `null` |
| `short_term_retention` | number | Rétention des sauvegardes court terme (jours) | `7` |
| `long_term_retention` | number | Rétention des sauvegardes long terme (jours) | `null` |
| `archive_retention` | number | Rétention des archives (jours) | `null` |
| `kms_key_id` | string | ID de clé KMS pour le chiffrement | `null` |
| `create_kms_key` | bool | Créer une nouvelle clé KMS dédiée | `false` |
| `notification_email` | string | Email pour les notifications | `null` |

### Ressources AWS Créées

```hcl
# Principales ressources AWS créées par le module

# Backup Vault
resource "aws_backup_vault" "main" {
  name        = var.backup_vault_name
  kms_key_arn = local.kms_key_arn
  tags        = local.tags
}

# Backup Plan
resource "aws_backup_plan" "daily" {
  name = "${var.environment}-daily-backup-plan"

  rule {
    rule_name         = "daily-backup-rule"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 22 * * ? *)"
    
    lifecycle {
      delete_after = var.short_term_retention
    }
  }
  
  # Règles additionnelles selon l'environnement
  dynamic "rule" {
    for_each = var.environment == "production" ? [1] : []
    content {
      rule_name         = "weekly-backup-rule"
      target_vault_name = aws_backup_vault.main.name
      schedule          = "cron(0 0 ? * SUN *)"
      
      lifecycle {
        delete_after = var.long_term_retention
      }
    }
  }
  
  tags = local.tags
}

# Sélection de ressources
resource "aws_backup_selection" "selection" {
  name          = "${var.environment}-resource-selection"
  iam_role_arn  = aws_iam_role.backup_role.arn
  plan_id       = aws_backup_plan.daily.id
  
  resources = concat(
    var.rds_instance_arns,
    var.dynamodb_table_arns,
    var.elasticache_cluster_arns,
    var.efs_arns,
    var.s3_bucket_arns
  )
}
```

### Outputs du Module

| Nom | Description |
|-----|-------------|
| `backup_vault_arn` | ARN du coffre de sauvegarde principal |
| `backup_vault_name` | Nom du coffre de sauvegarde principal |
| `secondary_backup_vault_arn` | ARN du coffre de sauvegarde secondaire (si activé) |
| `backup_plan_arns` | ARNs des plans de sauvegarde créés |
| `backup_sns_topic_arn` | ARN du topic SNS pour les notifications |
| `kms_key_arn` | ARN de la clé KMS utilisée pour le chiffrement |

---

## 🔄 Procédures de Restauration

### Processus de Restauration Standard

#### Étape 1 : Évaluation et Préparation

1. **Évaluer l'incident** : Déterminer la cause de la perte de données et l'étendue des données à restaurer
2. **Préparer l'environnement cible** : Vérifier que l'environnement cible a la capacité nécessaire
3. **Consulter le catalogue de backups** : Identifier le point de restauration optimal
4. **Notification des parties prenantes** : Informer les équipes concernées et définir la fenêtre de restauration

#### Étape 2 : Exécution de la Restauration

##### Via la Console AWS

1. Accéder à la console AWS Backup
2. Sélectionner le coffre de sauvegarde approprié
3. Filtrer par ressource et date pour trouver le point de restauration
4. Sélectionner "Restaurer" et configurer les paramètres spécifiques à la ressource
5. Surveiller le processus de restauration dans la section "Jobs de restauration"

##### Via Terraform (Approche recommandée)

```hcl
# Exemple de script de restauration pour RDS
module "restore_rds" {
  source = "../../modules/backup/restore"
  
  backup_recovery_point_arn = "arn:aws:backup:eu-west-1:123456789012:recovery-point:abcdef-1234-5678-90ab-cdef"
  
  target_db_instance_identifier = "accessweaver-restored-db"
  db_subnet_group_name          = module.vpc.database_subnet_group
  vpc_security_group_ids        = [module.security_groups.db_security_group_id]
  
  tags = {
    Restored    = "true"
    RestoreDate = "2025-06-02"
    Incident    = "INC-2025-06-001"
  }
}
```

#### Étape 3 : Validation Post-Restauration

1. **Vérification de l'intégrité** : S'assurer que les données restaurées sont complètes et cohérentes
2. **Tests applicatifs** : Exécuter des tests fonctionnels pour valider le bon fonctionnement
3. **Synchronisation incrémentale** : Si nécessaire, appliquer les transactions/changements survenus depuis le point de backup
4. **Documentation** : Enregistrer les détails de la restauration (temps d'exécution, problèmes rencontrés)

### Restauration par Type de Ressource

| Ressource | Procédure Spécifique | Temps Estimé | Précautions |
|-----------|----------------------|--------------|-------------|
| **RDS** | Restauration point-in-time avec paramètres de connexion adaptés | 30-60 min | Vérifier l'espace disque et les groupes de paramètres |
| **DynamoDB** | Restauration vers une nouvelle table puis basculement | 15-45 min | Impact sur le débit provisionné |
| **ElastiCache** | Restauration d'un nouveau cluster puis mise à jour des endpoints | 20-30 min | Mise à jour des configurations de connexion |
| **EFS** | Restauration dans un nouveau système de fichiers | 30-90 min | Vérifier les points de montage |
| **S3** | Restauration au niveau des objets ou du bucket | Variable | Gestion des versions et permissions |

### Restauration en Cas de Sinistre Majeur (DR)

1. **Activation du plan DR** : Déclencher le plan de reprise après sinistre
2. **Restauration cross-régionale** : Utiliser les backups dans la région secondaire (eu-central-1)
3. **Provisionnement des ressources** : Déployer l'infrastructure via Terraform dans la région secondaire
4. **Restauration des données** : Restaurer les backups dans l'ordre de priorité défini
5. **Reconfiguration DNS** : Mettre à jour les enregistrements DNS pour pointer vers la nouvelle infrastructure
6. **Validation complète** : Exécuter la suite de tests de validation DR

### Procédure de Test de Restauration

Les tests de restauration sont essentiels pour garantir la fiabilité du système de backup. Ils sont exécutés automatiquement selon la fréquence définie par environnement.

```bash
# Script d'automatisation des tests de restauration (simplifié)
#!/bin/bash

# Paramètres
ENV=$1
SERVICE=$2
DATE=$(date +%Y-%m-%d)

# Exécuter la restauration
terraform -chdir=dr-tests/$ENV apply \
  -var="service=$SERVICE" \
  -var="test_date=$DATE" \
  -var="recovery_point=latest" \
  -auto-approve

# Vérifier l'intégrité
./validation-scripts/check-$SERVICE-integrity.sh

# Enregistrer les résultats
echo "Test de restauration $SERVICE ($ENV) du $DATE: $RESULT" >> /var/log/backup-tests.log

# Notification du résultat
aws sns publish --topic-arn $SNS_TOPIC --message "Test restauration $SERVICE: $RESULT"
```

---

## 📊 Monitoring et Alerting

### Indicateurs Clés de Performance (KPIs)

| KPI | Description | Seuil Critique | Fréquence |
|-----|-------------|----------------|-----------|
| **Taux de Réussite des Backups** | Pourcentage de jobs de backup réussis | <98% | Quotidien |
| **Délai d'Exécution** | Temps nécessaire pour compléter le backup | >150% du temps moyen | Par job |
| **Taille des Backups** | Volume des données sauvegardées | >120% de la moyenne | Quotidien |
| **Taux de Réussite des Tests** | Pourcentage de tests de restauration réussis | <100% | Par test |
| **RTO Effectif** | Temps de restauration mesuré lors des tests | >90% de l'objectif | Par test |
| **Coût de Stockage** | Coût mensuel du stockage des backups | >110% du budget | Mensuel |

### Architecture de Monitoring

```
┌───────────────────────────────────────────────────────────┐
│                                                           │
│               CloudWatch Dashboard                        │
│  ┌─────────────────┐ ┌──────────────┐ ┌───────────────┐  │
│  │  Métriques AWS  │ │ Logs AWS     │ │ État Services │  │
│  │  Backup         │ │ Backup       │ │ AWS Backup    │  │
│  └─────────────────┘ └──────────────┘ └───────────────┘  │
│                                                           │
│  ┌─────────────────┐ ┌──────────────┐ ┌───────────────┐  │
│  │  Jobs Backup    │ │ Restauration │ │ Utilisation   │  │
│  │  (Statut/Durée) │ │ (Tests)      │ │ Stockage      │  │
│  └─────────────────┘ └──────────────┘ └───────────────┘  │
│                                                           │
└─────────┬─────────────────────────────────┬──────────────┘
          │                                 │
┌─────────▼────────────┐        ┌──────────▼───────────────┐
│                      │        │                          │
│  CloudWatch Alarms   │        │   EventBridge Rules      │
│                      │        │                          │
└──────────┬───────────┘        └───────────┬──────────────┘
           │                                │
           │                                │
┌──────────▼───────────────────────────────▼──────────────┐
│                                                         │
│                     SNS Topics                          │
│                                                         │
└────────────┬────────────────────────┬──────────────────┘
             │                        │
             │                        │
┌────────────▼────────┐    ┌──────────▼─────────────────┐
│                     │    │                            │
│   Email             │    │   Intégration ChatOps      │
│   Notifications     │    │   (Slack, Teams)           │
│                     │    │                            │
└─────────────────────┘    └────────────────────────────┘
```

### Alarmes CloudWatch

Le module Backup configure automatiquement plusieurs alarmes CloudWatch pour surveiller l'état des backups :

```hcl
# Exemple de configuration d'alarmes dans le module Terraform
resource "aws_cloudwatch_metric_alarm" "backup_job_failure" {
  alarm_name          = "${var.environment}-backup-job-failure-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "JobsFailed"
  namespace           = "AWS/Backup"
  period              = 86400  # 24 heures
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Cette alarme se déclenche lorsqu'un job de backup échoue"
  alarm_actions       = [aws_sns_topic.backup_alerts.arn]
  ok_actions          = [aws_sns_topic.backup_alerts.arn]
  
  dimensions = {
    BackupVaultName = aws_backup_vault.main.name
  }
}

resource "aws_cloudwatch_metric_alarm" "backup_job_expiration" {
  alarm_name          = "${var.environment}-backup-point-expiration-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RecoveryPointsExpired"
  namespace           = "AWS/Backup"
  period              = 86400  # 24 heures
  statistic           = "Sum"
  threshold           = var.environment == "production" ? 0 : 5
  alarm_description   = "Cette alarme se déclenche lorsque des points de récupération expirent"
  alarm_actions       = [aws_sns_topic.backup_alerts.arn]
  
  dimensions = {
    BackupVaultName = aws_backup_vault.main.name
  }
}
```

### Règles EventBridge

Des règles EventBridge sont configurées pour capturer les événements liés aux backups et déclencher des actions automatisées :

```hcl
resource "aws_cloudwatch_event_rule" "backup_state_change" {
  name        = "${var.environment}-backup-state-change"
  description = "Capture les changements d'état des jobs de backup"
  
  event_pattern = jsonencode({
    source      = ["aws.backup"],
    detail-type = ["Backup Job State Change", "Recovery Point State Change"]
  })
}

resource "aws_cloudwatch_event_target" "backup_state_sns" {
  rule      = aws_cloudwatch_event_rule.backup_state_change.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.backup_alerts.arn
}
```

### Dashboard de Monitoring

Un dashboard CloudWatch dédié est créé pour visualiser l'état des backups dans tous les environnements :

```hcl
resource "aws_cloudwatch_dashboard" "backup_dashboard" {
  dashboard_name = "AccessWeaver-Backup-Monitoring"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric",
        x      = 0,
        y      = 0,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/Backup", "NumberOfBackupJobsCreated", "BackupVaultName", aws_backup_vault.main.name],
            ["AWS/Backup", "NumberOfBackupJobsCompleted", "BackupVaultName", aws_backup_vault.main.name],
            ["AWS/Backup", "NumberOfBackupJobsAborted", "BackupVaultName", aws_backup_vault.main.name],
            ["AWS/Backup", "NumberOfBackupJobsFailed", "BackupVaultName", aws_backup_vault.main.name]
          ],
          view    = "timeSeries",
          stacked = false,
          title   = "Jobs de Backup - État"
        }
      },
      // Autres widgets...
    ]
  })
}
```

### Procédure de Réponse aux Alertes

| Alerte | Gravité | Action Immédiate | Délai d'Intervention |
|--------|---------|------------------|----------------------|
| **Échec de Backup** | Haute | Vérifier les logs, réexécuter manuellement si nécessaire | <30 minutes |
| **Échec de Test de Restauration** | Haute | Analyser la cause, corriger et retester | <2 heures |
| **Point de Récupération Expiré** | Moyenne | Vérifier la politique de rétention, ajuster si nécessaire | <4 heures |
| **Dépassement de Seuil de Stockage** | Basse | Examiner la croissance des données, ajuster les budgets | <24 heures |

### Rapports Automatisés

Des rapports hebdomadaires et mensuels sont générés automatiquement pour suivre les performances et la conformité du système de backup :

```bash
#!/bin/bash
# Exemple de script de génération de rapports (exécuté via AWS Lambda)

# Collecter les métriques
aws cloudwatch get-metric-data \
  --metric-data-queries file://backup-metrics-query.json \
  --start-time $(date -d "7 days ago" +%s) \
  --end-time $(date +%s) \
  > /tmp/backup-metrics.json

# Générer le rapport
python3 /opt/report-generator.py \
  --input /tmp/backup-metrics.json \
  --template /opt/backup-report-template.html \
  --output /tmp/backup-weekly-report.html

# Envoyer par email
aws ses send-email \
  --source backup-reports@accessweaver.com \
  --destination file://report-recipients.json \
  --message file://email-with-report.json
```
### Objectif Principal
Le module Backup fournit une solution de **sauvegarde complète et automatisée** pour l'ensemble des données critiques de la plateforme AccessWeaver. Il met en œuvre AWS Backup, un service géré qui centralise et automatise la protection des données dans les services AWS, offrant une stratégie robuste de récupération après sinistre (DR) et de conformité règlementaire.

### Ressources Couvertes

```
┌─────────────────────────────────────────────────────────┐
│                 AWS Backup Vault                          │
│                     /    |   \                            │
│                    /     |    \                           │
│                   /      |     \                          │
│       ┌───────────┐ ┌───────────┐ ┌───────────┐      │
│       │    RDS     │ │   EFS     │ │  DynamoDB  │      │
│       └───────────┘ └───────────┘ └───────────┘      │
│                  |       |       |                       │
│       ┌───────────┐ ┌───────────┐ ┌───────────┐      │
│       │  ECS/ECR   │ │    S3     │ │  ElastiCache│      │
│       └───────────┘ └───────────┘ └───────────┘      │
│                                                         │
│       ┌──────────────────────────────────────────┐      │
│       │     Plans de Backup par Environnement        │      │
│       └──────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────┘
```

### Caractéristiques Principales
- **Backups automatiques** : Programmation flexible des sauvegardes (quotidienne, hebdomadaire, mensuelle)
- **Rétention paramétrable** : Politiques de conservation adaptées à chaque environnement
- **Chiffrement natif** : Protection des données au repos avec KMS
- **Cycle de vie des backups** : Transition automatique vers des stockages moins coûteux
- **Restauration simplifiée** : Processus standardisé pour la récupération des données
- **Validation automatique** : Tests réguliers de l'intégrité des backups
- **Audit et conformité** : Traçabilité complète pour les exigences réglementaires

---

## 🏗️ Architecture par Environnement

### Stratégie Multi-Environnement

| Aspect | Development | Staging | Production |
|--------|-------------|---------|------------|
| **⏰ Fréquence** | Quotidienne | Quotidienne | Quotidienne + Hebdomadaire + Mensuelle |
| **💾 Reten. Court Terme** | 7 jours | 14 jours | 30 jours |
| **📆 Reten. Long Terme** | Non | 30 jours | 1 an + 7 ans (archives) |
| **🔒 Chiffrement** | Par défaut | KMS dédié | KMS multi-régional |
| **🔄 Cop. Trans-régionale** | Non | Non | Oui |
| **🧰 Test de restauration** | Manuel | Automatique (mensuel) | Automatique (hebdomadaire) |
| **🎯 RPO** | 24h | 24h | 1h pour RDS, 24h pour autres |
| **⏱️ RTO** | <24h | <12h | <4h |

### Plan de Backup Development

```
┌─────────────────────────────────────────────────────────┐
│            AWS Backup - Environnement Development          │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Backup Vault                                      │   │
│  │  - accessweaver-dev-backup-vault                  │   │
│  │  - Rétention: 7 jours                             │   │
│  │  - Stockage: S3 Standard uniquement                │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Plan Quotidien                                    │   │
│  │  - Nom: accessweaver-dev-daily                     │   │
│  │  - Fenêtre: 22h00 - 02h00                         │   │
│  │  - Fréquence: Tous les jours                       │   │
│  │  - Services: RDS, EFS, S3                           │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Notifications                                     │   │
│  │  - SNS Topic: accessweaver-dev-backup-alerts        │   │
│  │  - Notifications: Échecs uniquement               │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Plan de Backup Staging

```
┌─────────────────────────────────────────────────────────┐
│            AWS Backup - Environnement Staging              │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Backup Vault                                      │   │
│  │  - accessweaver-staging-backup-vault              │   │
│  │  - Rétention: 14 jours (court terme)              │   │
│  │  - Rétention: 30 jours (long terme)               │   │
│  │  - Stockage: S3 Standard + S3 IA                   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Plan Quotidien                                    │   │
│  │  - Nom: accessweaver-staging-daily                 │   │
│  │  - Fenêtre: 22h00 - 02h00                         │   │
│  │  - Fréquence: Tous les jours                       │   │
│  │  - Services: RDS, EFS, S3, DynamoDB, ElastiCache     │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Tests de Restauration                            │   │
│  │  - Fréquence: Mensuelle                           │   │
│  │  - Scope: RDS uniquement                           │   │
│  │  - Environnement de test dédié                    │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Notifications                                     │   │
│  │  - SNS Topic: accessweaver-staging-backup-alerts    │   │
│  │  - Notifications: Échecs et succès                │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```
### Plan de Backup Production

```
┌─────────────────────────────────────────────────────────┐
│            AWS Backup - Environnement Production           │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Backup Vault Principal                           │   │
│  │  - accessweaver-prod-backup-vault-primary         │   │
│  │  - Région: eu-west-1                             │   │
│  │  - Rétention: 30 jours (court terme)              │   │
│  │  - Rétention: 1 an (long terme)                   │   │
│  │  - Stockage: S3 Standard + S3 IA + Glacier        │   │
│  │  - Chiffrement: KMS dédié multi-régional          │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Backup Vault Secondaire                          │   │
│  │  - accessweaver-prod-backup-vault-secondary       │   │
│  │  - Région: eu-central-1                          │   │
│  │  - Copie cross-région des backups critiques        │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Backup Vault Archive                             │   │
│  │  - accessweaver-prod-backup-vault-archive         │   │
│  │  - Rétention: 7 ans                              │   │
│  │  - Stockage: Glacier Deep Archive                  │   │
│  │  - Transition automatique après 1 an              │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Plan Horaire (Tier 1)                            │   │
│  │  - Nom: accessweaver-prod-hourly                   │   │
│  │  - Services: RDS uniquement                        │   │
│  │  - Fenêtre: Chaque heure                          │   │
│  │  - Rétention: 24 heures                           │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Plan Quotidien (Tier 1 + 2)                      │   │
│  │  - Nom: accessweaver-prod-daily                    │   │
│  │  - Services: Tous                                  │   │
│  │  - Fenêtre: 22h00 - 02h00                         │   │
│  │  - Réplication cross-région: Oui                  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Plan Hebdomadaire (Tier 1 + 2)                   │   │
│  │  - Nom: accessweaver-prod-weekly                   │   │
│  │  - Services: Tous                                  │   │
│  │  - Jour: Dimanche                                 │   │
│  │  - Fenêtre: 00h00 - 06h00                         │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Plan Mensuel (Tier 1 + 2)                        │   │
│  │  - Nom: accessweaver-prod-monthly                  │   │
│  │  - Services: Tous                                  │   │
│  │  - Jour: 1er du mois                              │   │
│  │  - Stockage à long terme: Oui                     │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Tests de Restauration                            │   │
│  │  - Fréquence: Hebdomadaire (RDS)                  │   │
│  │  - Fréquence: Mensuelle (autres services)         │   │
│  │  - Environnement de DR dédié                      │   │
│  │  - Validation automatisée                         │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---
## 🔧 Configuration Terraform

### Structure du Module

Le module Backup implémente une solution complète de sauvegarde basée sur AWS Backup, avec la structure suivante :

```hcl
modules/
└── backup/
    ├── main.tf            # Ressources principales AWS Backup
    ├── variables.tf       # Déclaration des variables d'entrée
    ├── outputs.tf         # Sorties du module
    ├── locals.tf          # Variables locales et logique conditionnelle
    ├── vault.tf           # Configuration des coffres de sauvegarde
    ├── plans.tf           # Plans de sauvegarde par environnement
    ├── selection.tf       # Sélection des ressources à sauvegarder
    ├── notifications.tf   # Configuration des notifications SNS
    └── kms.tf             # Clés de chiffrement dédiées
```

### Utilisation du Module

```hcl
module "backup" {
  source = "../../modules/backup"
  
  environment               = "production"
  backup_vault_name         = "accessweaver-prod-backup-vault"
  enable_cross_region_backup = true
  secondary_region          = "eu-central-1"
  
  # Configuration des rétentions
  short_term_retention      = 30   # jours
  long_term_retention       = 365  # jours
  archive_retention         = 2555 # jours (7 ans)
  
  # Sélection des ressources
  rds_instance_arns         = module.database.db_instance_arns
  dynamodb_table_arns       = module.dynamodb.table_arns
  elasticache_cluster_arns  = module.redis.redis_cluster_arns
  efs_arns                  = module.storage.efs_arns
  s3_bucket_arns            = module.storage.bucket_arns
  
  # Plans de sauvegarde
  enable_hourly_backups     = true
  hourly_backup_resources   = ["rds"]
  
  # Notifications
  notification_email        = "platform-alerts@accessweaver.com"
  
  # Test de restauration automatisé
  enable_recovery_testing   = true
  recovery_test_frequency   = "weekly"
  
  tags = {
    Project     = "AccessWeaver"
    Environment = "production"
    Managed     = "terraform"
  }
}
```

### Variables d'Entrée Principales

| Nom Variable | Type | Description | Défaut |
|--------------|------|-------------|--------|
| `environment` | string | Environnement de déploiement | `"development"` |
| `backup_vault_name` | string | Nom du coffre de sauvegarde principal | `"accessweaver-backup-vault"` |
| `enable_cross_region_backup` | bool | Activer la réplication cross-région | `false` |
| `secondary_region` | string | Région secondaire pour la réplication | `null` |
| `short_term_retention` | number | Rétention des sauvegardes court terme (jours) | `7` |
| `long_term_retention` | number | Rétention des sauvegardes long terme (jours) | `null` |
| `archive_retention` | number | Rétention des archives (jours) | `null` |
| `kms_key_id` | string | ID de clé KMS pour le chiffrement | `null` |
| `create_kms_key` | bool | Créer une nouvelle clé KMS dédiée | `false` |
| `notification_email` | string | Email pour les notifications | `null` |

### Ressources AWS Créées

```hcl
# Principales ressources AWS créées par le module

# Backup Vault
resource "aws_backup_vault" "main" {
  name        = var.backup_vault_name
  kms_key_arn = local.kms_key_arn
  tags        = local.tags
}

# Backup Plan
resource "aws_backup_plan" "daily" {
  name = "${var.environment}-daily-backup-plan"

  rule {
    rule_name         = "daily-backup-rule"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 22 * * ? *)"
    
    lifecycle {
      delete_after = var.short_term_retention
    }
  }
  
  # Règles additionnelles selon l'environnement
  dynamic "rule" {
    for_each = var.environment == "production" ? [1] : []
    content {
      rule_name         = "weekly-backup-rule"
      target_vault_name = aws_backup_vault.main.name
      schedule          = "cron(0 0 ? * SUN *)"
      
      lifecycle {
        delete_after = var.long_term_retention
      }
    }
  }
  
  tags = local.tags
}

# Sélection de ressources
resource "aws_backup_selection" "selection" {
  name          = "${var.environment}-resource-selection"
  iam_role_arn  = aws_iam_role.backup_role.arn
  plan_id       = aws_backup_plan.daily.id
  
  resources = concat(
    var.rds_instance_arns,
    var.dynamodb_table_arns,
    var.elasticache_cluster_arns,
    var.efs_arns,
    var.s3_bucket_arns
  )
}
```

### Outputs du Module

| Nom | Description |
|-----|-------------|
| `backup_vault_arn` | ARN du coffre de sauvegarde principal |
| `backup_vault_name` | Nom du coffre de sauvegarde principal |
| `secondary_backup_vault_arn` | ARN du coffre de sauvegarde secondaire (si activé) |
| `backup_plan_arns` | ARNs des plans de sauvegarde créés |
| `backup_sns_topic_arn` | ARN du topic SNS pour les notifications |
| `kms_key_arn` | ARN de la clé KMS utilisée pour le chiffrement |
## 🔄 Procédures de Restauration

### Processus de Restauration Standard

#### Étape 1 : Évaluation et Préparation

1. **Évaluer l'incident** : Déterminer la cause de la perte de données et l'étendue des données à restaurer
2. **Préparer l'environnement cible** : Vérifier que l'environnement cible a la capacité nécessaire
3. **Consulter le catalogue de backups** : Identifier le point de restauration optimal
4. **Notification des parties prenantes** : Informer les équipes concernées et définir la fenêtre de restauration

#### Étape 2 : Exécution de la Restauration

##### Via la Console AWS

1. Accéder à la console AWS Backup
2. Sélectionner le coffre de sauvegarde approprié
3. Filtrer par ressource et date pour trouver le point de restauration
4. Sélectionner "Restaurer" et configurer les paramètres spécifiques à la ressource
5. Surveiller le processus de restauration dans la section "Jobs de restauration"

##### Via Terraform (Approche recommandée)

```hcl
# Exemple de script de restauration pour RDS
module "restore_rds" {
  source = "../../modules/backup/restore"
  
  backup_recovery_point_arn = "arn:aws:backup:eu-west-1:123456789012:recovery-point:abcdef-1234-5678-90ab-cdef"
  
  target_db_instance_identifier = "accessweaver-restored-db"
  db_subnet_group_name          = module.vpc.database_subnet_group
  vpc_security_group_ids        = [module.security_groups.db_security_group_id]
  
  tags = {
    Restored    = "true"
    RestoreDate = "2025-06-02"
    Incident    = "INC-2025-06-001"
  }
}
```

#### Étape 3 : Validation Post-Restauration

1. **Vérification de l'intégrité** : S'assurer que les données restaurées sont complètes et cohérentes
2. **Tests applicatifs** : Exécuter des tests fonctionnels pour valider le bon fonctionnement
3. **Synchronisation incrémentale** : Si nécessaire, appliquer les transactions/changements survenus depuis le point de backup
4. **Documentation** : Enregistrer les détails de la restauration (temps d'exécution, problèmes rencontrés)

### Restauration par Type de Ressource

| Ressource | Procédure Spécifique | Temps Estimé | Précautions |
|-----------|----------------------|--------------|-------------|
| **RDS** | Restauration point-in-time avec paramètres de connexion adaptés | 30-60 min | Vérifier l'espace disque et les groupes de paramètres |
| **DynamoDB** | Restauration vers une nouvelle table puis basculement | 15-45 min | Impact sur le débit provisionné |
| **ElastiCache** | Restauration d'un nouveau cluster puis mise à jour des endpoints | 20-30 min | Mise à jour des configurations de connexion |
| **EFS** | Restauration dans un nouveau système de fichiers | 30-90 min | Vérifier les points de montage |
| **S3** | Restauration au niveau des objets ou du bucket | Variable | Gestion des versions et permissions |

### Restauration en Cas de Sinistre Majeur (DR)

1. **Activation du plan DR** : Déclencher le plan de reprise après sinistre
2. **Restauration cross-régionale** : Utiliser les backups dans la région secondaire (eu-central-1)
3. **Provisionnement des ressources** : Déployer l'infrastructure via Terraform dans la région secondaire
4. **Restauration des données** : Restaurer les backups dans l'ordre de priorité défini
5. **Reconfiguration DNS** : Mettre à jour les enregistrements DNS pour pointer vers la nouvelle infrastructure
6. **Validation complète** : Exécuter la suite de tests de validation DR

### Procédure de Test de Restauration

Les tests de restauration sont essentiels pour garantir la fiabilité du système de backup. Ils sont exécutés automatiquement selon la fréquence définie par environnement.

```bash
# Script d'automatisation des tests de restauration (simplifié)
#!/bin/bash

# Paramètres
ENV=$1
SERVICE=$2
DATE=$(date +%Y-%m-%d)

# Exécuter la restauration
terraform -chdir=dr-tests/$ENV apply \
  -var="service=$SERVICE" \
  -var="test_date=$DATE" \
  -var="recovery_point=latest" \
  -auto-approve

# Vérifier l'intégrité
./validation-scripts/check-$SERVICE-integrity.sh

# Enregistrer les résultats
echo "Test de restauration $SERVICE ($ENV) du $DATE: $RESULT" >> /var/log/backup-tests.log

# Notification du résultat
aws sns publish --topic-arn $SNS_TOPIC --message "Test restauration $SERVICE: $RESULT"
```
## 📊 Monitoring et Alerting

### Indicateurs Clés de Performance (KPIs)

| KPI | Description | Seuil Critique | Fréquence |
|-----|-------------|----------------|-----------|
| **Taux de Réussite des Backups** | Pourcentage de jobs de backup réussis | <98% | Quotidien |
| **Délai d'Exécution** | Temps nécessaire pour compléter le backup | >150% du temps moyen | Par job |
| **Taille des Backups** | Volume des données sauvegardées | >120% de la moyenne | Quotidien |
| **Taux de Réussite des Tests** | Pourcentage de tests de restauration réussis | <100% | Par test |
| **RTO Effectif** | Temps de restauration mesuré lors des tests | >90% de l'objectif | Par test |
| **Coût de Stockage** | Coût mensuel du stockage des backups | >110% du budget | Mensuel |

### Architecture de Monitoring

```
┌───────────────────────────────────────────────────────────┐
│                                                           │
│               CloudWatch Dashboard                        │
│  ┌─────────────────┐ ┌──────────────┐ ┌───────────────┐  │
│  │  Métriques AWS  │ │ Logs AWS     │ │ État Services │  │
│  │  Backup         │ │ Backup       │ │ AWS Backup    │  │
│  └─────────────────┘ └──────────────┘ └───────────────┘  │
│                                                           │
│  ┌─────────────────┐ ┌──────────────┐ ┌───────────────┐  │
│  │  Jobs Backup    │ │ Restauration │ │ Utilisation   │  │
│  │  (Statut/Durée) │ │ (Tests)      │ │ Stockage      │  │
│  └─────────────────┘ └──────────────┘ └───────────────┘  │
│                                                           │
└─────────┬─────────────────────────────────┬──────────────┘
          │                                 │
┌─────────▼────────────┐        ┌──────────▼───────────────┐
│                      │        │                          │
│  CloudWatch Alarms   │        │   EventBridge Rules      │
│                      │        │                          │
└──────────┬───────────┘        └───────────┬──────────────┘
           │                                │
           │                                │
┌──────────▼───────────────────────────────▼──────────────┐
│                                                         │
│                     SNS Topics                          │
│                                                         │
└────────────┬────────────────────────┬──────────────────┘
             │                        │
             │                        │
┌────────────▼────────┐    ┌──────────▼─────────────────┐
│                     │    │                            │
│   Email             │    │   Intégration ChatOps      │
│   Notifications     │    │   (Slack, Teams)           │
│                     │    │                            │
└─────────────────────┘    └────────────────────────────┘
```

### Alarmes CloudWatch

Le module Backup configure automatiquement plusieurs alarmes CloudWatch pour surveiller l'état des backups :

```hcl
# Exemple de configuration d'alarmes dans le module Terraform
resource "aws_cloudwatch_metric_alarm" "backup_job_failure" {
  alarm_name          = "${var.environment}-backup-job-failure-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "JobsFailed"
  namespace           = "AWS/Backup"
  period              = 86400  # 24 heures
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Cette alarme se déclenche lorsqu'un job de backup échoue"
  alarm_actions       = [aws_sns_topic.backup_alerts.arn]
  ok_actions          = [aws_sns_topic.backup_alerts.arn]
  
  dimensions = {
    BackupVaultName = aws_backup_vault.main.name
  }
}

resource "aws_cloudwatch_metric_alarm" "backup_job_expiration" {
  alarm_name          = "${var.environment}-backup-point-expiration-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RecoveryPointsExpired"
  namespace           = "AWS/Backup"
  period              = 86400  # 24 heures
  statistic           = "Sum"
  threshold           = var.environment == "production" ? 0 : 5
  alarm_description   = "Cette alarme se déclenche lorsque des points de récupération expirent"
  alarm_actions       = [aws_sns_topic.backup_alerts.arn]
  
  dimensions = {
    BackupVaultName = aws_backup_vault.main.name
  }
}
```

### Règles EventBridge

Des règles EventBridge sont configurées pour capturer les événements liés aux backups et déclencher des actions automatisées :

```hcl
resource "aws_cloudwatch_event_rule" "backup_state_change" {
  name        = "${var.environment}-backup-state-change"
  description = "Capture les changements d'état des jobs de backup"
  
  event_pattern = jsonencode({
    source      = ["aws.backup"],
    detail-type = ["Backup Job State Change", "Recovery Point State Change"]
  })
}

resource "aws_cloudwatch_event_target" "backup_state_sns" {
  rule      = aws_cloudwatch_event_rule.backup_state_change.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.backup_alerts.arn
}
```

### Dashboard de Monitoring

Un dashboard CloudWatch dédié est créé pour visualiser l'état des backups dans tous les environnements :

```hcl
resource "aws_cloudwatch_dashboard" "backup_dashboard" {
  dashboard_name = "AccessWeaver-Backup-Monitoring"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric",
        x      = 0,
        y      = 0,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/Backup", "NumberOfBackupJobsCreated", "BackupVaultName", aws_backup_vault.main.name],
            ["AWS/Backup", "NumberOfBackupJobsCompleted", "BackupVaultName", aws_backup_vault.main.name],
            ["AWS/Backup", "NumberOfBackupJobsAborted", "BackupVaultName", aws_backup_vault.main.name],
            ["AWS/Backup", "NumberOfBackupJobsFailed", "BackupVaultName", aws_backup_vault.main.name]
          ],
          view    = "timeSeries",
          stacked = false,
          title   = "Jobs de Backup - État"
        }
      },
      // Autres widgets...
    ]
  })
}
```

### Procédure de Réponse aux Alertes

| Alerte | Gravité | Action Immédiate | Délai d'Intervention |
|--------|---------|------------------|----------------------|
| **Échec de Backup** | Haute | Vérifier les logs, réexécuter manuellement si nécessaire | <30 minutes |
| **Échec de Test de Restauration** | Haute | Analyser la cause, corriger et retester | <2 heures |
| **Point de Récupération Expiré** | Moyenne | Vérifier la politique de rétention, ajuster si nécessaire | <4 heures |
| **Dépassement de Seuil de Stockage** | Basse | Examiner la croissance des données, ajuster les budgets | <24 heures |

### Rapports Automatisés

Des rapports hebdomadaires et mensuels sont générés automatiquement pour suivre les performances et la conformité du système de backup :

```bash
#!/bin/bash
# Exemple de script de génération de rapports (exécuté via AWS Lambda)

# Collecter les métriques
aws cloudwatch get-metric-data \
  --metric-data-queries file://backup-metrics-query.json \
  --start-time $(date -d "7 days ago" +%s) \
  --end-time $(date +%s) \
  > /tmp/backup-metrics.json

# Générer le rapport
python3 /opt/report-generator.py \
  --input /tmp/backup-metrics.json \
  --template /opt/backup-report-template.html \
  --output /tmp/backup-weekly-report.html

# Envoyer par email
aws ses send-email \
  --source backup-reports@accessweaver.com \
  --destination file://report-recipients.json \
  --message file://email-with-report.json
```
