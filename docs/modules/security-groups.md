# 🚀 Module Security Groups - AccessWeaver

Module transversal pour la gestion unifiée des groupes de sécurité AWS pour l'ensemble de l'infrastructure AccessWeaver, garantissant communication sécurisée et principe de moindre privilège.

## 🎯 Objectifs

### ✅ Sécurité Renforcée
- **Principe de moindre privilège** pour tous les composants
- **Isolation réseau complète** entre environnements
- **Règles restrictives par défaut** avec ouvertures explicites
- **Vérification dynamique** des CIDR blocks et security groups
- **Documentation automatique** des règles de trafic

### ✅ Modèle de Communication Zero-Trust
- **Authentification mutuelle** entre services
- **Communication chiffrée** (TLS) pour tout trafic interne
- **Contrôle d'accès granulaire** au niveau service
- **Logging complet** de tout le trafic inter-services
- **Révocation immédiate** des accès compromis

### ✅ Implémentation Multi-Services
- **Groupes de sécurité ALB** pour accès externe
- **Groupes de sécurité ECS** pour communication entre services
- **Groupes de sécurité RDS** pour accès base de données
- **Groupes de sécurité Redis** pour accès cache
- **Groupes de sécurité VPC Endpoints** pour services AWS

### ✅ Gestion du Cycle de Vie
- **Création automatique** à partir de définitions de service
- **Mise à jour sans interruption** lors des changements
- **Nettoyage automatique** lors de la suppression de services
- **Versionning** des règles pour audit de sécurité
- **Intégration CI/CD** pour validation automatique

## 🏗 Architecture et Relations

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                  Internet / Utilisateurs                │
│                             │                           │
│                             ▼                           │
│ ┌───────────────────────────────────────────────────┐   │
│ │                  SG: ALB Public                   │   │
│ │   - Entrant: HTTP(80), HTTPS(443) de partout      │   │
│ │   - Sortant: Ephemeral ports vers SG ECS services │   │
│ └───────────────────────────────────────────────────┘   │
│                             │                           │
│                             ▼                           │
│ ┌───────────────────────────────────────────────────┐   │
│ │                SG: ECS Services                   │   │
│ │   - Entrant: Ephemeral ports depuis SG ALB        │   │
│ │   - Entrant: Service ports depuis SG ECS          │   │
│ │   - Sortant: RDS port vers SG RDS                 │   │
│ │   - Sortant: Redis port vers SG Redis             │   │
│ │   - Sortant: HTTPS(443) vers Internet             │   │
│ └───────────────────────────────────────────────────┘   │
│                             │                           │
│                 ┌───────────┴───────────┐               │
│                 │                       │               │
│                 ▼                       ▼               │
│ ┌───────────────────────────┐ ┌───────────────────────┐ │
│ │        SG: RDS            │ │      SG: Redis        │ │
│ │  - Entrant: DB port       │ │  - Entrant: Redis port│ │
│ │    depuis SG ECS services │ │    depuis SG ECS      │ │
│ │  - Sortant: Aucun         │ │  - Sortant: Aucun     │ │
│ └───────────────────────────┘ └───────────────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## 🔐 Configurations de Sécurité

### 📊 Matrice de Sécurité par Environnement

| Configuration | Dev | Staging | Prod |
|---------------|-----|---------|------|
| **ALB → Internet (HTTPS)** | ✅ | ✅ | ✅ |
| **ALB → Internet (HTTP)** | ✅ | ❌ (redirection) | ❌ (redirection) |
| **ECS → ALB** | ✅ | ✅ | ✅ |
| **ECS → ECS (inter-service)** | ✅ | ✅ | ✅ |
| **ECS → RDS** | ✅ | ✅ | ✅ |
| **ECS → Redis** | ✅ | ✅ | ✅ |
| **ECS → Internet** | ✅ | ✅ Limité | ✅ Limité |
| **Logging du trafic** | ❌ | ✅ | ✅ |

### 🛡️ Règles par Composant

#### ALB Security Group
- **Entrant**: 
  - HTTP (80) - Tout le monde en dev, redirection HTTPS en staging/prod
  - HTTPS (443) - Tout le monde
- **Sortant**: 
  - Ports dynamiques vers Security Group ECS

#### ECS Services Security Group
- **Entrant**:
  - Ports dynamiques depuis Security Group ALB
  - Ports des services depuis le même Security Group (pour communication inter-services)
- **Sortant**:
  - Port MySQL/PostgreSQL vers Security Group RDS
  - Port Redis vers Security Group Redis
  - HTTPS (443) vers Internet pour APIs externes

#### RDS Security Group
- **Entrant**:
  - Port base de données depuis Security Group ECS
- **Sortant**:
  - Aucun (blocage complet)

#### Redis Security Group
- **Entrant**:
  - Port Redis (6379) depuis Security Group ECS
- **Sortant**:
  - Aucun (blocage complet)

## 📝 Configuration et Utilisation

### Intégration dans d'autres modules

Les Security Groups sont créés et gérés dans les modules respectifs (ALB, ECS, RDS, Redis) mais sont conçus pour fonctionner ensemble avec des références croisées.

```hcl
# Exemple d'intégration dans le module ECS
resource "aws_security_group" "ecs_services" {
  name        = "accessweaver-${var.environment}-ecs-sg"
  description = "Groupe de sécurité pour les services ECS AccessWeaver"
  vpc_id      = var.vpc_id

  # Règle entrante depuis ALB
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = var.alb_security_group_ids
    description     = "Trafic depuis ALB"
  }

  # Règle sortante vers RDS
  egress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.rds_security_group_id]
    description     = "Accès à la base de données RDS"
  }

  # Règle sortante vers Redis
  egress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.redis_security_group_id]
    description     = "Accès au cache Redis"
  }

  tags = {
    Name        = "accessweaver-${var.environment}-ecs-sg"
    Environment = var.environment
    Project     = "AccessWeaver"
  }
}
```

### Exemple d'application complète

```hcl
module "vpc" {
  source = "./modules/vpc"
  # ...
}

module "alb" {
  source = "./modules/alb"
  # ...
  ecs_security_group_id = module.ecs.security_group_id
}

module "ecs" {
  source = "./modules/ecs"
  # ...
  alb_security_group_ids = [module.alb.security_group_id]
  rds_security_group_id  = module.rds.security_group_id
  redis_security_group_id = module.redis.security_group_id
}

module "rds" {
  source = "./modules/rds"
  # ...
  allowed_security_groups = [module.ecs.security_group_id]
}

module "redis" {
  source = "./modules/redis"
  # ...
  allowed_security_groups = [module.ecs.security_group_id]
}
```

## 📊 Bonnes Pratiques et Recommandations

### 🔒 Sécurité Avancée
- Implémenter AWS Config Rules pour valider la conformité des Security Groups
- Utiliser AWS Network Firewall pour une protection réseau avancée
- Activer VPC Flow Logs pour auditer tout le trafic réseau
- Considérer l'utilisation d'AWS Security Hub pour centraliser la sécurité

### 🧪 Tests de Sécurité
- Effectuer des tests de pénétration réguliers
- Valider l'isolation entre environnements
- Vérifier que seules les communications nécessaires sont autorisées
- Tester les scénarios de révocation d'accès

### 🔄 Maintenance
- Revoir périodiquement les règles de sécurité
- Automatiser la détection des règles trop permissives
- Implémenter une procédure d'approbation pour les modifications
- Documenter les justifications pour chaque règle