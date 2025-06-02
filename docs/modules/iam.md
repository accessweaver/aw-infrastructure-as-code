# 🔐 Module IAM - AccessWeaver Infrastructure

**Version :** 1.0  
**Date :** Juin 2025  
**Module :** modules/iam  
**Responsable :** Équipe Platform AccessWeaver

---

## 🎯 Vue d'Ensemble

### Objectif Principal
Le module IAM définit une **stratégie d'accès least-privilege** pour tous les composants de l'infrastructure AccessWeaver. Il fournit un système d'autorisations granulaires pour les services AWS, permettant une sécurité maximale tout en garantissant la fonctionnalité nécessaire à chaque service.

### Positionnement dans l'écosystème
```
┌─────────────────────────────────────────────────────────┐
│                   AWS IAM                               │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │    Roles    │  │  Policies   │  │   Groups    │     │
│  │             │  │             │  │             │     │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘     │
│         │                │                │            │
│         └────────────────┼────────────────┘            │
│                          │                             │
└──────────────────────────┼─────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────────┐
         │                 │                     │
┌────────▼─────────┐ ┌────▼───────────┐ ┌───────▼────────┐
│   ECS Services   │ │  RDS Database  │ │ S3 Buckets     │
└──────────────────┘ └────────────────┘ └────────────────┘
         │                 │                     │
         └─────────────────┼─────────────────────┘
                           │
                   ┌───────▼───────┐
                   │  CloudWatch   │
                   └───────────────┘
```

### Caractéristiques Principales
- **Principe du moindre privilège** : Accès strictement limité aux besoins fonctionnels
- **Séparation des rôles** : Isolation entre environnements et services
- **Auditabilité complète** : Journalisation et traçabilité des actions
- **Rotation automatique** : Gestion du cycle de vie des clés et secrets
- **Intégration AWS SSO** : Pour la gestion des accès humains
- **OIDC pour CI/CD** : Authentication moderne sans secrets stockés

---

## 🏗 Architecture par Environnement

### Stratégie Multi-Environnement

| Aspect | Development | Staging | Production |
|--------|-------------|---------|------------|
| **🔒 Isolation** | Modérée | Stricte | Hermétique |
| **👥 Accès Humain** | Développeurs + Ops | Ops uniquement | Accès break-glass |
| **🔄 Rotation Clés** | 90 jours | 60 jours | 30 jours |
| **📊 Audit** | Basique | Avancé | Complet |
| **🛡️ Politiques** | Permissives | Restrictives | Least-privilege |
| **🔍 Monitoring** | Minimal | Standard | Avancé + Alertes |

### Architecture IAM Development
```
┌─────────────────────────────────────────────────────────┐
│                   AWS IAM - Development                 │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  IAM Roles                                      │   │
│  │  - accessweaver-dev-ecs-task-role              │   │
│  │  - accessweaver-dev-ecs-execution-role         │   │
│  │  - accessweaver-dev-lambda-role                │   │
│  │  - accessweaver-dev-cloudwatch-role            │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  IAM Policies                                   │   │
│  │  - accessweaver-dev-s3-access                  │   │
│  │  - accessweaver-dev-rds-access                 │   │
│  │  - accessweaver-dev-redis-access               │   │
│  │  - accessweaver-dev-sqs-policy                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  IAM Groups                                     │   │
│  │  - AccessWeaver-Developers                     │   │
│  │  - AccessWeaver-DevOps                         │   │
│  │  - AccessWeaver-Admins                         │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Architecture IAM Production
```
┌─────────────────────────────────────────────────────────┐
│                   AWS IAM - Production                  │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  IAM Roles                                      │   │
│  │  - accessweaver-prod-ecs-task-role             │   │
│  │  - accessweaver-prod-ecs-execution-role        │   │
│  │  - accessweaver-prod-lambda-role               │   │
│  │  - accessweaver-prod-cloudwatch-role           │   │
│  │  - accessweaver-prod-backup-role               │   │
│  │  - accessweaver-prod-breakglass-role           │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  IAM Policies                                   │   │
│  │  - accessweaver-prod-s3-access-restricted      │   │
│  │  - accessweaver-prod-rds-access-restricted     │   │
│  │  - accessweaver-prod-redis-access-restricted   │   │
│  │  - accessweaver-prod-sqs-policy-restricted     │   │
│  │  - accessweaver-prod-kms-policy                │   │
│  │  - accessweaver-prod-boundary-policy           │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  IAM Groups                                     │   │
│  │  - AccessWeaver-SRE                            │   │
│  │  - AccessWeaver-SecurityOps                    │   │
│  │  - AccessWeaver-EmergencyAccess                │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 🔐 Politiques IAM

### Matrice de Permissions par Service

| Service | S3 | RDS | Redis | SQS | CloudWatch | KMS | Secrets |
|---------|----|----|-------|-----|------------|-----|---------|
| **API Service** | Read/Write | Read/Write | Read/Write | Send/Receive | Write Logs | Decrypt | Read |
| **Auth Service** | Read | Read/Write | Read/Write | Send | Write Logs | Decrypt | Read |
| **Worker Service** | Read/Write | Read | Read/Write | Receive | Write Logs | Decrypt | Read |
| **Analytics** | Read | Read-Only | No Access | No Access | Write Logs | No Access | No Access |
| **Monitoring** | No Access | No Access | No Access | No Access | Full Access | No Access | No Access |

### Roles ECS

#### Role d'exécution ECS
```hcl
# Role permettant à ECS de démarrer et exécuter les tâches
resource "aws_iam_role" "ecs_execution_role" {
  name = "accessweaver-${var.environment}-ecs-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Environment = var.environment
    Project     = "AccessWeaver"
  }
}

# Politique pour le rôle d'exécution ECS
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Politique additionnelle pour accéder aux secrets
resource "aws_iam_policy" "ecs_secrets_access" {
  name        = "accessweaver-${var.environment}-ecs-secrets-access"
  description = "Politique permettant l'accès aux secrets pour les tâches ECS"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Effect   = "Allow"
        Resource = [
          var.secrets_arn,
          var.kms_key_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_secrets_policy_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_secrets_access.arn
}
```

#### Role de tâche ECS
```hcl
# Role permettant aux applications d'accéder aux services AWS
resource "aws_iam_role" "ecs_task_role" {
  name = "accessweaver-${var.environment}-ecs-task-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Environment = var.environment
    Project     = "AccessWeaver"
  }
}

# Politique pour l'accès S3
resource "aws_iam_policy" "s3_access" {
  name        = "accessweaver-${var.environment}-s3-access"
  description = "Politique d'accès aux buckets S3 pour les applications"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "${var.s3_bucket_arn}",
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_s3_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# Politique pour CloudWatch Logs
resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "accessweaver-${var.environment}-cloudwatch-logs-policy"
  description = "Politique pour écrire des logs dans CloudWatch"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:log-group:/ecs/accessweaver-${var.environment}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_cloudwatch_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
}
```

---

## 📝 Implémentation et Utilisation

### Intégration avec le Module ECS

```hcl
module "iam" {
  source      = "../modules/iam"
  environment = var.environment
  
  # Ressources ARNs pour les politiques
  s3_bucket_arn = module.s3.bucket_arn
  secrets_arn   = module.secrets.secrets_arn
  kms_key_arn   = module.kms.key_arn
}

module "ecs" {
  source      = "../modules/ecs"
  environment = var.environment
  
  # Utilisation des rôles IAM
  task_execution_role_arn = module.iam.ecs_execution_role_arn
  task_role_arn           = module.iam.ecs_task_role_arn
  
  # Autres paramètres ECS...
}
```

### AWS SSO / Identity Center

Pour les accès humains, nous recommandons d'utiliser AWS SSO plutôt que des utilisateurs IAM traditionnels:

```hcl
# Configuration AWS SSO avec Terraform
resource "aws_identitystore_group" "developers" {
  display_name      = "AccessWeaver-Developers"
  description       = "Groupe des développeurs AccessWeaver"
  identity_store_id = var.identity_store_id
}

resource "aws_identitystore_group" "sre" {
  display_name      = "AccessWeaver-SRE"
  description       = "Groupe SRE pour AccessWeaver"
  identity_store_id = var.identity_store_id
}

# Permission Set pour développeurs
resource "aws_ssoadmin_permission_set" "developer_permission_set" {
  name             = "AccessWeaver-Developer-Permissions"
  description      = "Permissions de base pour développeurs"
  instance_arn     = var.sso_instance_arn
  session_duration = "PT8H"
}

# Assignation des groupes aux permissions dans les comptes
resource "aws_ssoadmin_account_assignment" "developer_assignment_dev" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer_permission_set.arn
  
  principal_id   = aws_identitystore_group.developers.group_id
  principal_type = "GROUP"
  
  target_id   = var.development_account_id
  target_type = "AWS_ACCOUNT"
}
```

---

## 📊 Bonnes Pratiques et Recommandations

### 🔍 Sécurité et Conformité
- **Utiliser des politiques restrictives** avec énumération explicite des actions et ressources
- **Implémenter des Permission Boundaries** pour limiter l'étendue des permissions
- **Éviter les wildcards** (`*`) dans les politiques sauf si absolument nécessaire
- **Auditer régulièrement** les permissions avec IAM Access Analyzer
- **Activer AWS CloudTrail** pour journaliser toutes les actions IAM

### ⚡ Gestion des Accès
- **Favoriser les rôles IAM** plutôt que les utilisateurs avec clés d'accès
- **Utiliser OIDC** pour l'intégration CI/CD (GitHub Actions, GitLab CI)
- **Implémenter MFA** pour tous les accès humains
- **Politique de rotation** stricte pour toutes les clés d'accès
- **Définir des conditions** dans les politiques (IP source, heure, etc.)

### 🔄 CI/CD et Automatisation
- **Utiliser des rôles dédiés** pour les pipelines CI/CD
- **Implémenter des workflows d'approbation** pour les changements IAM
- **Utiliser les tags** pour la gestion et l'automatisation
- **Stocker les définitions IAM** comme Infrastructure as Code (Terraform)
- **Tester les politiques** avant déploiement avec des outils comme IAM Policy Simulator

---

## 🔧 Troubleshooting

### Problèmes Courants et Solutions

#### 1. Erreur "AccessDenied"
- **Symptômes**: Une tâche ECS ou une Lambda ne peut pas accéder à une ressource AWS.
- **Causes possibles**: 
  - Politique IAM trop restrictive
  - ARN de ressource incorrect
  - Condition de politique non satisfaite
- **Solution**:
  - Vérifier les logs CloudTrail pour identifier l'action exacte et la ressource
  - Comparer avec les permissions accordées dans la politique
  - Utiliser le simulateur de politique IAM pour tester

#### 2. Problème de délégation de rôle
- **Symptômes**: Erreur "AssumeRole" lors de l'exécution d'une tâche.
- **Causes possibles**:
  - Politique de confiance incorrecte
  - Problème de relations de confiance entre comptes
- **Solution**:
  - Vérifier la politique de confiance du rôle (`assume_role_policy`)
  - Vérifier les contraintes d'identité (externalId, conditions)
  - S'assurer que le service ou l'entité qui assume le rôle est correctement spécifié

#### 3. Problème d'accès aux secrets
- **Symptômes**: L'application ne peut pas accéder aux secrets dans Secrets Manager.
- **Causes possibles**:
  - Permissions KMS manquantes
  - ARN du secret incorrect
- **Solution**:
  - Ajouter des permissions KMS si le secret est chiffré avec une clé personnalisée
  - Vérifier que l'ARN du secret est correct dans la politique
  - Tester avec la CLI AWS en assumant le rôle de l'application

---

## 📝 Changelog et Versions

| Version | Date | Changements |
|---------|------|-------------|
| **1.0.0** | 2025-06-01 | Documentation initiale complète |
| **1.0.1** | 2025-06-02 | Ajout section troubleshooting |

---

## 🏆 Conclusion

Le module IAM d'AccessWeaver constitue la **pierre angulaire de la sécurité** de notre infrastructure. En adoptant une approche least-privilege rigoureuse, nous garantissons que chaque composant dispose exactement des permissions nécessaires à son fonctionnement, ni plus ni moins.

### Points Clés à Retenir

✅ **Sécurité First** : Politiques restrictives et permission boundaries  
✅ **Auditabilité** : Logging complet et traçabilité avec CloudTrail  
✅ **Gestion moderne** : AWS SSO pour les humains, OIDC pour CI/CD  
✅ **Automatisation** : Toutes les politiques en Infrastructure as Code

### Success Criteria Validation

- **✅ Least Privilege** : Chaque rôle limité aux permissions minimales requises
- **✅ Isolation** : Séparation stricte entre environnements et services
- **✅ Auditabilité** : Toutes les actions traçables via CloudTrail
- **✅ Sécurité** : Absence d'accès direct aux ressources sensibles
- **✅ Maintenabilité** : Gestion centralisée et automatisée des permissions

**🎯 Prochaine Action :** Implémenter un audit régulier des permissions avec IAM Access Analyzer.

---

**📚 Cette documentation fait partie de l'écosystème AccessWeaver Infrastructure.**

**Liens rapides :**
- [Retour à l'Index](../README.md)
- [Module Security Groups](./security-groups.md)
- [Module CloudWatch](./cloudwatch.md)
- [Guide de Sécurité](../security/README.md)