# 👤 IAM (Identity and Access Management) - AccessWeaver Infrastructure

**Version :** 1.0  
**Date :** Juin 2025  
**Module :** security/iam  
**Responsable :** Équipe Platform AccessWeaver

---

## 🎯 Vue d'Ensemble

### Objectif Principal
Ce document détaille la **stratégie de gestion des identités et des accès (IAM)** implémentée dans l'infrastructure AWS d'AccessWeaver. En tant que système d'autorisation enterprise, AccessWeaver lui-même met en œuvre des principes stricts de contrôle d'accès afin de garantir la sécurité de l'infrastructure sous-jacente et de l'application.

### Principes Fondamentaux

| Principe | Description | Implémentation |
|----------|-------------|----------------|
| **Moindre privilège** | Attribuer uniquement les autorisations minimales nécessaires | IAM fine-grained policies, time-bound access |
| **Séparation des privilèges** | Diviser les tâches critiques entre plusieurs rôles | Service-specific roles, multi-approval |
| **Defense-in-depth** | Multiples couches de contrôles d'accès | IAM + SCPs + Boundaries + Conditions |
| **Zero standing privileges** | Aucun accès permanent aux ressources critiques | Just-in-time access, temporary credentials |
| **Auditabilité** | Traçabilité complète de toutes les actions | CloudTrail, GuardDuty, multi-account logs |

### Architecture IAM Multi-Comptes

AccessWeaver utilise une architecture AWS multi-comptes pour isoler les environnements et les fonctionnalités :

```
┌─────────────────────────────────────────────────────────────────┐
│                       Organisation AWS                           │
│                                                                  │
│  ┌───────────────────┐   ┌───────────────────┐                   │
│  │ Compte Management │   │ Compte Sécurité   │                   │
│  │                   │   │                   │                   │
│  │ - IAM Users       │   │ - Logs centralisés│                   │
│  │ - SSO             │   │ - GuardDuty       │                   │
│  │ - Service Control │   │ - Config          │                   │
│  │   Policies        │   │ - SecurityHub     │                   │
│  └───────────────────┘   └───────────────────┘                   │
│                                                                  │
│  ┌───────────────────┐   ┌───────────────────┐                   │
│  │ Compte Shared     │   │ Compte Network    │                   │
│  │ Services          │   │                   │                   │
│  │ - CI/CD           │   │ - Transit Gateway │                   │
│  │ - Artifacts       │   │ - VPC Endpoints   │                   │
│  │ - Monitoring      │   │ - DNS             │                   │
│  └───────────────────┘   └───────────────────┘                   │
│                                                                  │
│  ┌───────────────────┐   ┌───────────────────┐   ┌─────────────┐ │
│  │ Compte Production │   │ Compte Staging    │   │ Compte Dev  │ │
│  │                   │   │                   │   │             │ │
│  │ - Applications    │   │ - Applications    │   │ - Apps      │ │
│  │ - Données         │   │ - Données de test │   │ - Test data │ │
│  └───────────────────┘   └───────────────────┘   └─────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Flux d'Authentification et d'Autorisation

```
┌──────────────────────────────────────────────────────────────────┐
│                 Flux IAM AccessWeaver                             │
│                                                                   │
│  ┌─────────┐      ┌──────────────┐      ┌────────────────┐        │
│  │Utilisateur│────►│ AWS SSO     │─────►│ Identity Store │        │
│  └─────────┘      │ Fédération   │      │ (AD/IdP)       │        │
│                   └──────────────┘      └────────────────┘        │
│                          │                                        │
│                          ▼                                        │
│           ┌──────────────────────────────────┐                    │
│           │   Rôles AWS avec Permission Sets  │                    │
│           └──────────────────────────────────┘                    │
│                          │                                        │
│                          ▼                                        │
│  ┌─────────────┐    ┌────────────┐     ┌──────────────────┐       │
│  │ Service     │    │ Resource   │     │ Service Control  │       │
│  │ Roles       │◄───┤ Policies   │◄────┤ Policies (SCPs)  │       │
│  └─────────────┘    └────────────┘     └──────────────────┘       │
│        │                  │                     │                 │
│        ▼                  ▼                     ▼                 │
│  ┌──────────────────────────────────────────────────────┐         │
│  │               Contrôles d'accès AWS                   │         │
│  │                                                       │         │
│  │  - IAM Policy Evaluation                              │         │
│  │  - Permission Boundaries                              │         │
│  │  - Session Context & Conditions                       │         │
│  │  - Resource-based Policies                            │         │
│  └──────────────────────────────────────────────────────┘         │
└──────────────────────────────────────────────────────────────────┘
```

## 🔑 Stratégie IAM Globale

### Gestion des Identités

AccessWeaver implémente une stratégie d'identité basée sur ces principes clés :

| Aspect | Implémentation | Justification |
|--------|----------------|---------------|
| **Authentification** | AWS SSO / IAM Identity Center | Centralisation, fédération d'identité |
| **Source d'identité** | Azure AD (principal) / Okta (backup) | Intégration avec l'annuaire d'entreprise |
| **Facteurs multiples** | MFA obligatoire | Protection contre vol d'identifiants |
| **Rotation des credentials** | Automatique avec durée limitée | Réduction de la surface d'attaque |
| **Gestion utilisateurs** | Lifecycle management automatisé | Revue périodique des accès |

#### AWS Organizations et Service Control Policies (SCPs)

Les Service Control Policies constituent une couche de sécurité préventive appliquée à l'ensemble de l'organisation :

```hcl
resource "aws_organizations_policy" "prevent_public_access" {
  name        = "accessweaver-prevent-public-access"
  description = "Prévient l'exposition publique des ressources sensibles"
  content     = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyPublicS3Buckets",
      "Effect": "Deny",
      "Action": [
        "s3:PutBucketPublicAccessBlock",
        "s3:PutBucketPolicy",
        "s3:PutBucketAcl"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "s3:PublicAccessBlockConfiguration/RestrictPublicBuckets": "false"
        }
      }
    },
    {
      "Sid": "DenyPublicRDSInstances",
      "Effect": "Deny",
      "Action": [
        "rds:CreateDBInstance",
        "rds:ModifyDBInstance"
      ],
      "Resource": "*",
      "Condition": {
        "Bool": {
          "rds:PubliclyAccessible": "true"
        }
      }
    },
    {
      "Sid": "DenyPublicECRRepositories",
      "Effect": "Deny",
      "Action": [
        "ecr:SetRepositoryPolicy"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ecr:RepositoryPolicyText": "*\"Principal\":{\"AWS\":\"*\"}*"
        }
      }
    }
  ]
}
EOF
}

resource "aws_organizations_policy" "enforce_encryption" {
  name        = "accessweaver-enforce-encryption"
  description = "Assure l'utilisation du chiffrement pour toutes les ressources sensibles"
  content     = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnforceS3Encryption",
      "Effect": "Deny",
      "Action": [
        "s3:PutObject"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": [
            "AES256",
            "aws:kms"
          ]
        }
      }
    },
    {
      "Sid": "EnforceRDSEncryption",
      "Effect": "Deny",
      "Action": [
        "rds:CreateDBInstance",
        "rds:CreateDBCluster"
      ],
      "Resource": "*",
      "Condition": {
        "Bool": {
          "rds:StorageEncrypted": "false"
        }
      }
    },
    {
      "Sid": "EnforceEBSEncryption",
      "Effect": "Deny",
      "Action": [
        "ec2:CreateVolume"
      ],
      "Resource": "*",
      "Condition": {
        "Bool": {
          "ec2:Encrypted": "false"
        }
      }
    }
  ]
}
EOF
}

resource "aws_organizations_policy" "region_restriction" {
  name        = "accessweaver-region-restriction"
  description = "Limite les régions AWS utilisables pour la conformité et la sécurité"
  content     = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowedRegions",
      "Effect": "Deny",
      "NotAction": [
        "cloudfront:*",
        "iam:*",
        "route53:*",
        "support:*",
        "budgets:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": [
            "eu-west-1",
            "eu-central-1",
            "us-east-1",
            "us-west-2"
          ]
        }
      }
    }
  ]
}
EOF
}

# Application des SCPs aux différentes OUs
resource "aws_organizations_policy_attachment" "attach_to_production" {
  policy_id = aws_organizations_policy.prevent_public_access.id
  target_id = aws_organizations_organizational_unit.production.id
}

resource "aws_organizations_policy_attachment" "attach_encryption_all" {
  policy_id = aws_organizations_policy.enforce_encryption.id
  target_id = aws_organizations_organization.accessweaver.roots[0].id
}

resource "aws_organizations_policy_attachment" "attach_regions_all" {
  policy_id = aws_organizations_policy.region_restriction.id
  target_id = aws_organizations_organization.accessweaver.roots[0].id
}
```

### Configuration AWS SSO / IAM Identity Center

AccessWeaver utilise AWS SSO pour la gestion centralisée des accès :

```hcl
# Activer AWS SSO
resource "aws_ssoadmin_instance" "accessweaver" {}

# Création de groupes de permission
resource "aws_identitystore_group" "administrators" {
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
  
  display_name = "Administrators"
  description  = "Administrateurs système AccessWeaver"
}

resource "aws_identitystore_group" "developers" {
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
  
  display_name = "Developers"
  description  = "Développeurs AccessWeaver"
}

resource "aws_identitystore_group" "security" {
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
  
  display_name = "Security"
  description  = "Équipe Sécurité AccessWeaver"
}

resource "aws_identitystore_group" "devops" {
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
  
  display_name = "DevOps"
  description  = "Équipe DevOps AccessWeaver"
}

# Permission sets pour différents niveaux d'accès
resource "aws_ssoadmin_permission_set" "administrator" {
  name             = "Administrator"
  description      = "Administrateur avec privilèges complets"
  instance_arn     = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  session_duration = "PT8H"
  
  tags = {
    Environment = "all"
    ManagedBy   = "terraform"
  }
}

resource "aws_ssoadmin_managed_policy_attachment" "administrator_policy" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn
}

resource "aws_ssoadmin_permission_set" "readonly" {
  name             = "ReadOnly"
  description      = "Accès en lecture seule à toutes les ressources"
  instance_arn     = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  session_duration = "PT8H"
  
  tags = {
    Environment = "all"
    ManagedBy   = "terraform"
  }
}

resource "aws_ssoadmin_managed_policy_attachment" "readonly_policy" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
}

resource "aws_ssoadmin_permission_set" "developer" {
  name             = "Developer"
  description      = "Accès développeur avec permissions limitées"
  instance_arn     = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  session_duration = "PT8H"
  
  tags = {
    Environment = "all"
    ManagedBy   = "terraform"
  }
}

resource "aws_ssoadmin_inline_policy" "developer_policy" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.developer.arn
  
  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ecs:Describe*",
          "ecs:List*",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "logs:Get*",
          "logs:List*",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:Describe*",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:Get*",
          "s3:List*"
        ]
        Resource = [
          "arn:aws:s3:::accessweaver-*-artifacts*",
          "arn:aws:s3:::accessweaver-*-artifacts*/*"
        ]
      }
    ]
  })
}

# Attribution des permissions aux groupes et comptes
resource "aws_ssoadmin_account_assignment" "admin_production" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn
  
  principal_id   = aws_identitystore_group.administrators.group_id
  principal_type = "GROUP"
  
  target_id   = var.production_account_id
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "security_all_accounts" {
  for_each = toset([
    var.production_account_id,
    var.staging_account_id,
    var.development_account_id,
    var.shared_account_id,
    var.security_account_id
  ])
  
  instance_arn       = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
  
  principal_id   = aws_identitystore_group.security.group_id
  principal_type = "GROUP"
  
  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "developers_dev" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.developer.arn
  
  principal_id   = aws_identitystore_group.developers.group_id
  principal_type = "GROUP"
  
  target_id   = var.development_account_id
  target_type = "AWS_ACCOUNT"
}
```
## 🔐 Rôles et Politiques IAM par Catégorie

AccessWeaver implémente une structure IAM rigoureuse basée sur des catégories fonctionnelles.

### Types de Rôles AWS

| Type de Rôle | Objectif | Exemple |
|--------------|----------|---------|
| **Rôles de Service** | Permettent aux services AWS d'agir au nom d'AccessWeaver | Lambda execution role, ECS task role |
| **Rôles d'Application** | Utilisés par les applications et microservices | API authorizer role, Decision engine role |
| **Rôles d'Infrastructure** | Utilisés pour le provisionnement et la gestion | Terraform role, CloudFormation role |
| **Rôles Cross-Account** | Permettent l'accès entre comptes AWS | Log shipping role, Monitoring role |
| **Rôles Humains** | Attribués aux utilisateurs via SSO | Developer role, Admin role, Security role |
| **Rôles Temporaires** | Accès limité dans le temps | Emergency access role, Audit role |

### Modèle de Permission Boundary

AccessWeaver utilise des permission boundaries pour limiter les privilèges maximaux attribuables :

```hcl
resource "aws_iam_policy" "developer_permission_boundary" {
  name        = "accessweaver-developer-permission-boundary"
  description = "Boundary pour restreindre les autorisations maximales des développeurs"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:*",
          "dynamodb:*",
          "lambda:*",
          "apigateway:*",
          "ecs:*",
          "ecr:*",
          "logs:*",
          "cloudwatch:*",
          "sns:*",
          "sqs:*",
          "events:*"
        ],
        Resource = "*"
      },
      {
        Effect = "Deny",
        Action = [
          "iam:Create*",
          "iam:Delete*",
          "iam:Update*",
          "iam:Put*",
          "iam:Attach*",
          "iam:Detach*",
          "organizations:*",
          "account:*",
          "ec2:CreateVpc",
          "rds:Create*",
          "kms:Delete*",
          "kms:Create*",
          "kms:Update*",
          "kms:Enable*",
          "kms:Disable*",
          "kms:Schedule*"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "production_permission_boundary" {
  name        = "accessweaver-production-permission-boundary"
  description = "Boundary pour les ressources de production"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Deny",
        Action = [
          "ec2:DeleteVpc",
          "rds:DeleteDB*",
          "dynamodb:DeleteTable",
          "s3:DeleteBucket"
        ],
        Resource = "*",
        Condition = {
          StringEquals = {
            "aws:RequestedRegion": var.production_regions
          }
        }
      },
      {
        Effect = "Deny",
        Action = [
          "iam:Delete*",
          "iam:Create*",
          "iam:Update*",
          "iam:Put*",
          "iam:Attach*",
          "iam:Detach*"
        ],
        Resource = "*"
      },
      {
        Effect = "Deny",
        Action = "*",
        Resource = "*",
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent": "false"
          }
        }
      }
    ]
  })
}
```

### Terraform Automation Role

Terraform utilise un rôle spécifique pour déployer l'infrastructure :

```hcl
resource "aws_iam_role" "terraform_role" {
  name = "accessweaver-terraform-automation"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${var.ci_cd_account_id}:role/gitlab-ci-role"
        },
        Action = "sts:AssumeRole",
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/Service": "CICD"
          }
        }
      }
    ]
  })
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/PowerUserAccess"
  ]
  
  tags = {
    Name        = "accessweaver-terraform-automation"
    Environment = var.environment
    Service     = "infrastructure"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "terraform_iam_permissions" {
  name = "accessweaver-terraform-iam-permissions"
  role = aws_iam_role.terraform_role.id
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions"
        ],
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/accessweaver-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/accessweaver-*"
        ]
      },
      {
        Effect = "Deny",
        Action = [
          "iam:*"
        ],
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/accessweaver-protected-*"
        ]
      }
    ]
  })
}
```

### Policies d'Applications Clés

Voici quelques exemples de politiques IAM utilisées par les principales applications AccessWeaver :

#### Decision Engine Role

```hcl
resource "aws_iam_role" "decision_engine" {
  name = "accessweaver-${var.environment}-decision-engine"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
  
  tags = {
    Name        = "accessweaver-${var.environment}-decision-engine"
    Environment = var.environment
    Service     = "decision-engine"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "decision_engine_permissions" {
  name = "accessweaver-${var.environment}-decision-engine-permissions"
  role = aws_iam_role.decision_engine.id
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem"
        ],
        Resource = [
          aws_dynamodb_table.policy_store.arn,
          aws_dynamodb_table.policy_store.arn,
          "${aws_dynamodb_table.policy_store.arn}/index/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ],
        Resource = aws_kms_key.application.arn
      },
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:accessweaver/${var.environment}/decision-engine/*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ecs/accessweaver-${var.environment}-decision-engine:*"
      },
      {
        Effect = "Allow",
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ],
        Resource = "*"
      }
    ]
  })
}
```

#### Admin API Role

```hcl
resource "aws_iam_role" "admin_api" {
  name = "accessweaver-${var.environment}-admin-api"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
  
  tags = {
    Name        = "accessweaver-${var.environment}-admin-api"
    Environment = var.environment
    Service     = "admin-api"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "admin_api_permissions" {
  name = "accessweaver-${var.environment}-admin-api-permissions"
  role = aws_iam_role.admin_api.id
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ],
        Resource = [
          aws_dynamodb_table.policy_store.arn,
          aws_dynamodb_table.policy_store.arn,
          "${aws_dynamodb_table.policy_store.arn}/index/*",
          aws_dynamodb_table.tenant_config.arn,
          "${aws_dynamodb_table.tenant_config.arn}/index/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:Encrypt"
        ],
        Resource = aws_kms_key.application.arn
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.policy_templates.arn,
          "${aws_s3_bucket.policy_templates.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:accessweaver/${var.environment}/admin-api/*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ecs/accessweaver-${var.environment}-admin-api:*"
      },
      {
        Effect = "Allow",
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ],
        Resource = "*"
      }
    ]
  })
}
```

### Lambda Authorizer Role

```hcl
resource "aws_iam_role" "api_authorizer" {
  name = "accessweaver-${var.environment}-api-authorizer"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-api-authorizer"
    Environment = var.environment
    Service     = "api-security"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "api_authorizer_permissions" {
  name = "accessweaver-${var.environment}-api-authorizer-permissions"
  role = aws_iam_role.api_authorizer.id
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ],
        Resource = [
          aws_dynamodb_table.api_keys.arn,
          "${aws_dynamodb_table.api_keys.arn}/index/*",
          aws_dynamodb_table.tenant_config.arn,
          "${aws_dynamodb_table.tenant_config.arn}/index/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt"
        ],
        Resource = aws_kms_key.application.arn
      },
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:accessweaver/${var.environment}/api-authorizer/*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/accessweaver-${var.environment}-api-authorizer:*"
      },
      {
        Effect = "Allow",
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ],
        Resource = "*"
      }
    ]
  })
}
```

## 🔒 Politiques de Sécurité IAM

### Rotation des Secrets et Identifiants

AccessWeaver implémente une stratégie de rotation automatique des secrets et identifiants :

```hcl
# AWS Secrets Manager - rotation automatique des secrets
resource "aws_secretsmanager_secret_rotation" "database_credentials" {
  secret_id           = aws_secretsmanager_secret.database.id
  rotation_lambda_arn = aws_lambda_function.rotate_db_credentials.arn
  
  rotation_rules {
    automatically_after_days = var.environment == "production" ? 30 : 90
  }
}

# Lambda de rotation des secrets
resource "aws_lambda_function" "rotate_db_credentials" {
  function_name = "accessweaver-${var.environment}-rotate-db-credentials"
  role          = aws_iam_role.secret_rotation.arn
  runtime       = "java21"
  handler       = "com.accessweaver.security.rotation.DatabaseCredentialRotationHandler"
  timeout       = 60
  memory_size   = 512
  
  environment {
    variables = {
      SECRET_ARN        = aws_secretsmanager_secret.database.arn
      DATABASE_ENDPOINT = aws_db_instance.main.endpoint
      KMS_KEY_ARN       = aws_kms_key.secrets.arn
      ENVIRONMENT       = var.environment
    }
  }
  
  filename         = "${path.module}/lambda/rotate-db-credentials.jar"
  source_code_hash = filebase64sha256("${path.module}/lambda/rotate-db-credentials.jar")
  
  tags = {
    Name        = "accessweaver-${var.environment}-rotate-db-credentials"
    Environment = var.environment
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

# Rôle IAM pour la rotation des secrets
resource "aws_iam_role" "secret_rotation" {
  name = "accessweaver-${var.environment}-secret-rotation"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-secret-rotation"
    Environment = var.environment
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "secret_rotation_permissions" {
  name = "accessweaver-${var.environment}-secret-rotation-permissions"
  role = aws_iam_role.secret_rotation.id
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ],
        Resource = aws_secretsmanager_secret.database.arn
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ],
        Resource = aws_kms_key.secrets.arn
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/accessweaver-${var.environment}-rotate-db-credentials:*"
      }
    ]
  })
}
```

### Détection des Accès Inutilisés

```hcl
# Lambda pour analyser et supprimer les accès inutilisés
resource "aws_lambda_function" "access_analyzer" {
  function_name = "accessweaver-${var.environment}-access-analyzer"
  role          = aws_iam_role.access_analyzer.arn
  runtime       = "java21"
  handler       = "com.accessweaver.security.iam.AccessAnalyzerHandler"
  timeout       = 300
  memory_size   = 1024
  
  environment {
    variables = {
      UNUSED_THRESHOLD_DAYS = var.environment == "production" ? "90" : "30"
      SNS_TOPIC_ARN         = aws_sns_topic.security_alerts.arn
      AUTO_REMEDIATE        = var.environment == "production" ? "false" : "true"
      ENVIRONMENT           = var.environment
    }
  }
  
  filename         = "${path.module}/lambda/access-analyzer.jar"
  source_code_hash = filebase64sha256("${path.module}/lambda/access-analyzer.jar")
  
  tags = {
    Name        = "accessweaver-${var.environment}-access-analyzer"
    Environment = var.environment
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role" "access_analyzer" {
  name = "accessweaver-${var.environment}-access-analyzer"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-access-analyzer"
    Environment = var.environment
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "access_analyzer_permissions" {
  name = "accessweaver-${var.environment}-access-analyzer-permissions"
  role = aws_iam_role.access_analyzer.id
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "iam:GenerateServiceLastAccessedDetails",
          "iam:GetServiceLastAccessedDetails",
          "iam:ListRoles",
          "iam:ListUsers",
          "iam:ListGroups",
          "iam:ListPolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListAttachedUserPolicies",
          "iam:ListAttachedGroupPolicies",
          "iam:GetRole",
          "iam:GetUser",
          "iam:GetGroup",
          "iam:GetPolicy"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "iam:DeleteRolePolicy",
          "iam:DetachRolePolicy"
        ],
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/accessweaver-*",
        Condition = {
          StringEquals = {
            "aws:RequestTag/AutoRemediate": "true"
          }
        }
      },
      {
        Effect = "Allow",
        Action = [
          "sns:Publish"
        ],
        Resource = aws_sns_topic.security_alerts.arn
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/accessweaver-${var.environment}-access-analyzer:*"
      }
    ]
  })
}

# Programmation du nettoyage automatique
resource "aws_cloudwatch_event_rule" "access_analyzer_schedule" {
  name                = "accessweaver-${var.environment}-access-analyzer-schedule"
  description         = "Exécute l'analyseur d'accès tous les mois"
  schedule_expression = "cron(0 0 1 * ? *)"
  
  tags = {
    Name        = "accessweaver-${var.environment}-access-analyzer-schedule"
    Environment = var.environment
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_event_target" "access_analyzer_target" {
  rule      = aws_cloudwatch_event_rule.access_analyzer_schedule.name
  target_id = "accessweaver-${var.environment}-access-analyzer"
  arn       = aws_lambda_function.access_analyzer.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_access_analyzer" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.access_analyzer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.access_analyzer_schedule.arn
}
```
## 📊 Monitoring et Audit IAM

AccessWeaver implémente un système complet de monitoring et d'audit des activités IAM pour détecter rapidement les anomalies et assurer la conformité.

### Centralisation des Logs IAM

Tous les logs IAM sont centralisés dans le compte de sécurité :

```hcl
# Configuration de CloudTrail multi-comptes
resource "aws_cloudtrail" "organization_trail" {
  provider                      = aws.management
  name                          = "accessweaver-organization-trail"
  s3_bucket_name                = aws_s3_bucket.audit_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  is_organization_trail         = true
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
  }
  
  insight_selector {
    insight_type = "ApiCallRateInsight"
  }
  
  insight_selector {
    insight_type = "ApiErrorRateInsight"
  }
  
  tags = {
    Name        = "accessweaver-organization-trail"
    Environment = "all"
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

# Bucket S3 pour les logs d'audit
resource "aws_s3_bucket" "audit_logs" {
  provider      = aws.security
  bucket        = "accessweaver-security-audit-logs"
  force_destroy = false
  
  tags = {
    Name        = "accessweaver-security-audit-logs"
    Environment = "all"
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs" {
  provider = aws.security
  bucket   = aws_s3_bucket.audit_logs.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "audit_logs" {
  provider = aws.security
  bucket   = aws_s3_bucket.audit_logs.id
  
  rule {
    id     = "archive-and-expire"
    status = "Enabled"
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    expiration {
      days = 2555  # ~7 ans (conformité)
    }
  }
}

resource "aws_s3_bucket_policy" "audit_logs" {
  provider = aws.security
  bucket   = aws_s3_bucket.audit_logs.id
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AWSCloudTrailWrite",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action   = "s3:PutObject",
        Resource = "${aws_s3_bucket.audit_logs.arn}/AWSLogs/${data.aws_organizations_organization.current.id}/*",
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailAclCheck",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action   = "s3:GetBucketAcl",
        Resource = aws_s3_bucket.audit_logs.arn
      },
      {
        Sid    = "DenyUnencryptedUploads",
        Effect = "Deny",
        Principal = {
          AWS = "*"
        },
        Action   = "s3:PutObject",
        Resource = "${aws_s3_bucket.audit_logs.arn}/*",
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid    = "DenyNonSecureTransport",
        Effect = "Deny",
        Principal = {
          AWS = "*"
        },
        Action   = "s3:*",
        Resource = "${aws_s3_bucket.audit_logs.arn}/*",
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
```

### Configuration IAM Access Analyzer

AccessWeaver utilise IAM Access Analyzer pour détecter les accès externes :

```hcl
# IAM Access Analyzer - Comptes individuels
resource "aws_accessanalyzer_analyzer" "account" {
  for_each = toset([
    "production",
    "staging",
    "development"
  ])
  
  provider      = aws.target[each.key]
  analyzer_name = "accessweaver-${each.key}-analyzer"
  type          = "ACCOUNT"
  
  tags = {
    Name        = "accessweaver-${each.key}-analyzer"
    Environment = each.key
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

# IAM Access Analyzer - Organisation
resource "aws_accessanalyzer_analyzer" "organization" {
  provider      = aws.security
  analyzer_name = "accessweaver-organization-analyzer"
  type          = "ORGANIZATION"
  
  tags = {
    Name        = "accessweaver-organization-analyzer"
    Environment = "all"
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

# Intégration avec SNS pour alertes
resource "aws_sns_topic" "iam_alerts" {
  provider = aws.security
  name     = "accessweaver-iam-alerts"
  
  kms_master_key_id = aws_kms_key.sns.arn
  
  tags = {
    Name        = "accessweaver-iam-alerts"
    Environment = "all"
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

# Lambda pour traiter les événements Access Analyzer
resource "aws_lambda_function" "access_analyzer_processor" {
  provider      = aws.security
  function_name = "accessweaver-access-analyzer-processor"
  role          = aws_iam_role.access_analyzer_processor.arn
  runtime       = "java21"
  handler       = "com.accessweaver.security.iam.AccessAnalyzerProcessorHandler"
  timeout       = 60
  memory_size   = 512
  
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.iam_alerts.arn
      JIRA_API_URL  = var.jira_api_url
      ENVIRONMENT   = "all"
    }
  }
  
  filename         = "${path.module}/lambda/access-analyzer-processor.jar"
  source_code_hash = filebase64sha256("${path.module}/lambda/access-analyzer-processor.jar")
  
  tags = {
    Name        = "accessweaver-access-analyzer-processor"
    Environment = "all"
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

# EventBridge pour détecter les résultats d'Access Analyzer
resource "aws_cloudwatch_event_rule" "access_analyzer_findings" {
  provider    = aws.security
  name        = "accessweaver-access-analyzer-findings"
  description = "Détecte les nouveaux résultats d'Access Analyzer"
  
  event_pattern = jsonencode({
    source      = ["aws.access-analyzer"],
    detail-type = ["Access Analyzer Finding"],
    detail = {
      status = ["ACTIVE"]
    }
  })
  
  tags = {
    Name        = "accessweaver-access-analyzer-findings"
    Environment = "all"
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_event_target" "access_analyzer_findings" {
  provider  = aws.security
  rule      = aws_cloudwatch_event_rule.access_analyzer_findings.name
  target_id = "accessweaver-access-analyzer-findings-lambda"
  arn       = aws_lambda_function.access_analyzer_processor.arn
}

resource "aws_lambda_permission" "allow_eventbridge_to_call_access_analyzer_processor" {
  provider      = aws.security
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.access_analyzer_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.access_analyzer_findings.arn
}
```

### AWS Config pour les Vérifications de Conformité IAM

```hcl
# AWS Config - Règles liées à IAM
resource "aws_config_config_rule" "iam_user_no_policies" {
  provider = aws.management
  name     = "accessweaver-iam-user-no-policies"
  
  source {
    owner             = "AWS"
    source_identifier = "IAM_USER_NO_POLICIES_CHECK"
  }
  
  tags = {
    Name        = "accessweaver-iam-user-no-policies"
    Environment = "all"
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

resource "aws_config_config_rule" "iam_root_access_key" {
  provider = aws.management
  name     = "accessweaver-iam-root-access-key"
  
  source {
    owner             = "AWS"
    source_identifier = "IAM_ROOT_ACCESS_KEY_CHECK"
  }
  
  tags = {
    Name        = "accessweaver-iam-root-access-key"
    Environment = "all"
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

resource "aws_config_config_rule" "iam_password_policy" {
  provider = aws.management
  name     = "accessweaver-iam-password-policy"
  
  source {
    owner             = "AWS"
    source_identifier = "IAM_PASSWORD_POLICY"
    
    source_detail {
      message_type = "ConfigurationItemChangeNotification"
    }
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
    Name        = "accessweaver-iam-password-policy"
    Environment = "all"
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

resource "aws_config_config_rule" "iam_policy_no_statements_with_admin_access" {
  provider = aws.management
  name     = "accessweaver-iam-policy-no-admin-access"
  
  source {
    owner             = "AWS"
    source_identifier = "IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS"
  }
  
  tags = {
    Name        = "accessweaver-iam-policy-no-admin-access"
    Environment = "all"
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

resource "aws_config_config_rule" "iam_user_mfa_enabled" {
  provider = aws.management
  name     = "accessweaver-iam-user-mfa-enabled"
  
  source {
    owner             = "AWS"
    source_identifier = "IAM_USER_MFA_ENABLED"
  }
  
  tags = {
    Name        = "accessweaver-iam-user-mfa-enabled"
    Environment = "all"
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

resource "aws_config_config_rule" "iam_user_unused_credentials_check" {
  provider = aws.management
  name     = "accessweaver-iam-user-unused-credentials"
  
  source {
    owner             = "AWS"
    source_identifier = "IAM_USER_UNUSED_CREDENTIALS_CHECK"
  }
  
  input_parameters = jsonencode({
    maxCredentialUsageAge = "90"
  })
  
  tags = {
    Name        = "accessweaver-iam-user-unused-credentials"
    Environment = "all"
    Service     = "security"
    ManagedBy   = "terraform"
  }
}
```

### Dashboards de Monitoring IAM

```hcl
# Dashboard CloudWatch pour IAM
resource "aws_cloudwatch_dashboard" "iam_security" {
  provider      = aws.security
  dashboard_name = "accessweaver-iam-security"
  
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
            ["AWS/IAM", "TotalAuthenticationsCount", "Region", "global"],
            [".", "AuthenticationsPerSecond", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Authentifications IAM"
          period  = 300
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
            ["AWS/IAM", "AccessDeniedAuthenticationsCount", "Region", "global"],
            [".", "AccessDeniedAuthenticationsPerSecond", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Authentifications Refusées"
          period  = 300
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
            ["AWS/IAM", "AuthorizationsPerSecond", "Region", "global"],
            [".", "AuthorizedAPICalls", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Autorisations"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          query   = "SOURCE '/aws/cloudtrail' | filter eventSource like 'iam.%' | stats count() as IAMEvents by eventName, userIdentity.arn, sourceIPAddress | sort IAMEvents desc | limit 10"
          region  = var.region
          title   = "Top 10 des Événements IAM"
          view    = "table"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 18
        width  = 24
        height = 6
        properties = {
          query   = "SOURCE '/aws/cloudtrail' | filter (eventName like 'Create%' or eventName like 'Put%' or eventName like 'Attach%') and eventSource like 'iam.%' | stats count() as IAMChanges by eventName, userIdentity.arn, sourceIPAddress | sort IAMChanges desc | limit 10"
          region  = var.region
          title   = "Top 10 des Modifications IAM"
          view    = "table"
        }
      }
    ]
  })
}

# Alarmes CloudWatch pour IAM
resource "aws_cloudwatch_metric_alarm" "iam_root_login" {
  provider            = aws.management
  alarm_name          = "accessweaver-root-login-detected"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "RootUserAuthenticationsCount"
  namespace           = "AWS/IAM"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Cette alarme se déclenche lorsqu'une connexion utilisateur root est détectée"
  alarm_actions       = [aws_sns_topic.iam_alerts.arn]
  dimensions = {
    Region = "global"
  }
  
  tags = {
    Name        = "accessweaver-root-login-detected"
    Environment = "all"
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "iam_policy_changes" {
  provider            = aws.management
  alarm_name          = "accessweaver-iam-policy-changes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "IAMPolicyChanges"
  namespace           = "AccessWeaver/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "3"
  alarm_description   = "Cette alarme se déclenche lorsque plus de 3 modifications de politiques IAM sont détectées en 5 minutes"
  alarm_actions       = [aws_sns_topic.iam_alerts.arn]
  
  tags = {
    Name        = "accessweaver-iam-policy-changes"
    Environment = "all"
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

# Lambda pour détecter les modifications IAM
resource "aws_lambda_function" "iam_change_detector" {
  provider      = aws.security
  function_name = "accessweaver-iam-change-detector"
  role          = aws_iam_role.iam_change_detector.arn
  runtime       = "java21"
  handler       = "com.accessweaver.security.iam.IAMChangeDetectorHandler"
  timeout       = 60
  memory_size   = 512
  
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.iam_alerts.arn
      CLOUDWATCH_NAMESPACE = "AccessWeaver/Security"
      JIRA_API_URL  = var.jira_api_url
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
  
  filename         = "${path.module}/lambda/iam-change-detector.jar"
  source_code_hash = filebase64sha256("${path.module}/lambda/iam-change-detector.jar")
  
  tags = {
    Name        = "accessweaver-iam-change-detector"
    Environment = "all"
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

# EventBridge pour détecter les modifications IAM
resource "aws_cloudwatch_event_rule" "iam_changes" {
  provider    = aws.security
  name        = "accessweaver-iam-changes"
  description = "Détecte les modifications liées à IAM"
  
  event_pattern = jsonencode({
    source      = ["aws.iam"],
    detail-type = ["AWS API Call via CloudTrail"],
    detail = {
      eventSource = ["iam.amazonaws.com"],
      eventName   = [
        "CreatePolicy",
        "DeletePolicy",
        "CreatePolicyVersion",
        "DeletePolicyVersion",
        "AttachRolePolicy",
        "DetachRolePolicy",
        "AttachUserPolicy",
        "DetachUserPolicy",
        "AttachGroupPolicy",
        "DetachGroupPolicy",
        "PutRolePolicy",
        "DeleteRolePolicy",
        "PutUserPolicy",
        "DeleteUserPolicy",
        "PutGroupPolicy",
        "DeleteGroupPolicy",
        "CreateRole",
        "DeleteRole",
        "UpdateAssumeRolePolicy"
      ]
    }
  })
  
  tags = {
    Name        = "accessweaver-iam-changes"
    Environment = "all"
    Service     = "security"
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_event_target" "iam_changes" {
  provider  = aws.security
  rule      = aws_cloudwatch_event_rule.iam_changes.name
  target_id = "accessweaver-iam-changes-lambda"
  arn       = aws_lambda_function.iam_change_detector.arn
}
```

## 🛡️ Bonnes Pratiques IAM

AccessWeaver adhère à un ensemble de bonnes pratiques pour la gestion des identités et des accès AWS.

### Résumé des Pratiques Recommandées

| Catégorie | Bonnes Pratiques | Implémentation |
|-----------|------------------|----------------|
| **Gestion des Comptes** | Utiliser AWS Organizations avec OUs | Multi-comptes pour les environnements et fonctions |
| **Authentification** | Fédération d'identité, MFA obligatoire | AWS SSO avec Azure AD/Okta, Conditions MFA |
| **Autorisations** | Moindre privilège, permission boundaries | Politiques IAM restrictives, boundaries par rôle |
| **Service Control Policies** | Contrôles préventifs à l'échelle de l'organisation | SCPs pour chiffrement, régions, accès public |
| **Isolation d'Environnement** | Séparation stricte dev/staging/prod | Comptes AWS distincts, accès contrôlé |
| **Gestion des Secrets** | Rotation automatique, accès temporaire | AWS Secrets Manager, rotation programmée |
| **Audit et Monitoring** | Surveillance centralisée, alertes | CloudTrail, Access Analyzer, CloudWatch |

### Architecture IAM Recommandée

```
┌──────────────────────────────────────────────────────────────────────┐
│          Architecture IAM à Privilèges Minimaux                       │
│                                                                       │
│  ┌───────────────┐     ┌───────────────┐     ┌───────────────┐        │
│  │   Contrôles   │     │   Contrôles   │     │   Contrôles   │        │
│  │ Préventifs    │────►│ Détectifs     │────►│ Correctifs    │        │
│  └───────────────┘     └───────────────┘     └───────────────┘        │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │                                                                 │  │
│  │  ┌───────────┐        ┌───────────┐        ┌───────────┐        │  │
│  │  │   SCPs    │        │Permission │        │  IAM      │        │  │
│  │  │           │        │Boundaries │        │ Policies  │        │  │
│  │  └───────────┘        └───────────┘        └───────────┘        │  │
│  │                                                                 │  │
│  │  ┌───────────┐        ┌───────────┐        ┌───────────┐        │  │
│  │  │Resource   │        │ Conditions│        │Session    │        │  │
│  │  │Policies   │        │  IAM      │        │ Context   │        │  │
│  │  └───────────┘        └───────────┘        └───────────┘        │  │
│  │                                                                 │  │
│  └─────────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌─────────────────┐      ┌─────────────────┐    ┌─────────────────┐  │
│  │Audit Centralisé │      │Détection        │    │Automatisation   │  │
│  │- CloudTrail     │      │d'Anomalies      │    │Corrective       │  │
│  │- Config         │      │- GuardDuty      │    │- Lambda         │  │
│  │- S3 (Immutable) │      │- Access Analyzer │    │- EventBridge   │  │
│  └─────────────────┘      └─────────────────┘    └─────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

### Checklist de Mise en Œuvre

- [x] Activer la fédération d'identité avec AWS SSO
- [x] Configurer MFA obligatoire pour tous les utilisateurs
- [x] Mettre en place des permission boundaries pour tous les rôles
- [x] Déployer des Service Control Policies restrictives
- [x] Configurer IAM Access Analyzer dans tous les comptes
- [x] Centraliser les logs d'audit avec CloudTrail
- [x] Mettre en œuvre la rotation automatique des secrets
- [x] Déployer des alarmes pour les activités IAM anormales
- [x] Automatiser les vérifications de conformité avec AWS Config
- [x] Implémenter la suppression automatique des accès inutilisés

## 📝 Références

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS Organizations User Guide](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_introduction.html)
- [AWS Identity Federation Guide](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers.html)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [AWS Security Reference Architecture](https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/welcome.html)
