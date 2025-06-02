# 🌐 Sécurité Réseau - AccessWeaver Infrastructure

**Version :** 1.0  
**Date :** Juin 2025  
**Module :** security/network  
**Responsable :** Équipe Platform AccessWeaver

---

## 🎯 Vue d'Ensemble

### Objectif Principal
Ce document détaille l'**architecture réseau sécurisée** implémentée dans l'infrastructure AWS d'AccessWeaver. Notre conception réseau constitue une couche fondamentale de défense, assurant l'isolation des ressources critiques tout en permettant les communications légitimes nécessaires au fonctionnement du système.

AccessWeaver implémente une architecture réseau multi-couches sur AWS, conçue selon une approche "security-by-design" avec des VPCs isolés par environnement, une segmentation stricte via subnets dédiés, et un ensemble cohérent de contrôles d'accès réseau.

### Principes Fondamentaux

| Principe | Description | Implémentation |
|----------|-------------|----------------|
| **Défense en profondeur** | Multiples couches de sécurité, chacune avec ses propres contrôles | VPC + Subnets + SG + NACLs + WAF |
| **Segmentation réseau** | Isolation stricte entre les composants par fonction et sensibilité | Zones de sécurité distinctes avec contrôles d'accès spécifiques |
| **Principe du moindre privilège** | Communications minimales nécessaires entre services | Security Groups restrictifs, ingress/egress limités |
| **Connectivité privée** | Utilisation maximale des services AWS privés | VPC Endpoints, PrivateLink, pas de NAT Gateways quand évitable |
| **Monitoring continu** | Surveillance des flux réseau et détection d'anomalies | VPC Flow Logs, Traffic Mirroring, CloudWatch Anomaly Detection |

### Composants Clés

```
┌─────────────────────────────────────────────────────────────────┐
│                        Sécurité Réseau                          │
│                                                                 │
│  ┌───────────────┐   ┌───────────────┐   ┌───────────────┐     │
│  │ Segmentation  │   │ Contrôles     │   │ Connectivité  │     │
│  │ & Isolation   │   │ d'Accès       │   │ Sécurisée     │     │
│  └───────────────┘   └───────────────┘   └───────────────┘     │
│         │                   │                   │               │
│         ▼                   ▼                   ▼               │
│  ┌───────────────┐   ┌───────────────┐   ┌───────────────┐     │
│  │ - VPC         │   │ - Security    │   │ - TLS/HTTPS   │     │
│  │ - Subnets     │   │   Groups      │   │ - VPC         │     │
│  │ - AZs         │   │ - NACLs       │   │   Endpoints   │     │
│  │ - Route       │   │ - WAF         │   │ - Private     │     │
│  │   Tables      │   │ - Shield      │   │   DNS         │     │
│  └───────────────┘   └───────────────┘   └───────────────┘     │
│                                                                 │
│                    ┌───────────────────┐                        │
│                    │ Validation &      │                        │
│                    │ Monitoring        │                        │
│                    └───────────────────┘                        │
│                             │                                   │
│                             ▼                                   │
│                    ┌───────────────────┐                        │
│                    │ - VPC Flow Logs   │                        │
│                    │ - GuardDuty       │                        │
│                    │ - Network Firewall│                        │
│                    │ - Network Analyzer│                        │
│                    └───────────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
```
## 🏗 Architecture Réseau Sécurisée

### VPC et Segmentation

AccessWeaver utilise une architecture VPC isolée par environnement avec une segmentation rigoureuse pour limiter la surface d'attaque et minimiser l'impact potentiel d'une compromission.

```
┌────────────────────────────────────────────────────────────────┐
│                 VPC AccessWeaver                                │
│                                                                 │
│  ┌─────────────────────────┐   ┌─────────────────────────┐     │
│  │    Zone Publique        │   │    Zone Privée          │     │
│  │    (DMZ)                │   │    Applicative          │     │
│  │                         │   │                         │     │
│  │  ┌───────────────────┐  │   │  ┌───────────────────┐  │     │
│  │  │ ALB / API Gateway │  │   │  │  ECS Services     │  │     │
│  │  └─────────┬─────────┘  │   │  │  (Fargate)        │  │     │
│  │            │            │   │  └─────────┬─────────┘  │     │
│  │            ▼            │   │            │            │     │
│  │  ┌───────────────────┐  │   │            ▼            │     │
│  │  │   WAF / Shield    │  │   │  ┌───────────────────┐  │     │
│  │  └───────────────────┘  │   │  │ Security Groups   │  │     │
│  └───────────┬─────────────┘   │  └───────────────────┘  │     │
│              │                 └───────────┬─────────────┘     │
│              │                             │                   │
│              ▼                             ▼                   │
│  ┌─────────────────────────┐   ┌─────────────────────────┐    │
│  │  Zone Privée Data       │   │  Zone Gestion           │    │
│  │                         │   │                         │    │
│  │  ┌───────────────────┐  │   │  ┌───────────────────┐  │    │
│  │  │  RDS / Redis      │  │   │  │ Bastion / VPN     │  │    │
│  │  │  ElastiCache      │  │   │  │ Session Manager   │  │    │
│  │  └───────────────────┘  │   │  └───────────────────┘  │    │
│  │                         │   │                         │    │
│  └─────────────────────────┘   └─────────────────────────┘    │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

#### Structure CIDR

| Environnement | VPC CIDR       | Description                               |
|---------------|----------------|-------------------------------------------|
| Development   | 10.0.0.0/16    | VPC développement isolé                   |
| Staging       | 10.1.0.0/16    | VPC staging pré-production                |
| Production    | 10.2.0.0/16    | VPC production multi-AZ                   |
| Management    | 10.3.0.0/16    | VPC pour outils DevOps et monitoring      |

#### Découpage des Subnets

| Type de Subnet | CIDR (Production) | Zone de Disponibilité | Usage                           |
|----------------|-------------------|----------------------|----------------------------------|
| Public A       | 10.2.0.0/24       | eu-west-1a           | ALB, API Gateway                |
| Public B       | 10.2.1.0/24       | eu-west-1b           | ALB, API Gateway                |
| Public C       | 10.2.2.0/24       | eu-west-1c           | ALB, API Gateway                |
| App Privé A    | 10.2.10.0/24      | eu-west-1a           | ECS Fargate, Lambda             |
| App Privé B    | 10.2.11.0/24      | eu-west-1b           | ECS Fargate, Lambda             |
| App Privé C    | 10.2.12.0/24      | eu-west-1c           | ECS Fargate, Lambda             |
| Data Privé A   | 10.2.20.0/24      | eu-west-1a           | RDS, ElastiCache                |
| Data Privé B   | 10.2.21.0/24      | eu-west-1b           | RDS, ElastiCache                |
| Data Privé C   | 10.2.22.0/24      | eu-west-1c           | RDS, ElastiCache                |
| Mgmt Privé A   | 10.2.30.0/24      | eu-west-1a           | Bastion, Session Manager        |
| Mgmt Privé B   | 10.2.31.0/24      | eu-west-1b           | Bastion, Session Manager        |

### Zones de Sécurité

La segmentation réseau d'AccessWeaver s'articule autour de quatre zones de sécurité distinctes, chacune avec des contrôles d'accès spécifiques :

#### 1. Zone Publique (DMZ)
- **Composants** : Application Load Balancers, API Gateway
- **Contrôles** : WAF, Shield, Security Groups restrictifs
- **Accès** : Trafic Internet entrant filtré, uniquement HTTPS (TCP 443)
- **Objectif** : Minimiser la surface d'attaque exposée à Internet

#### 2. Zone Applicative Privée
- **Composants** : ECS Fargate, Lambda, conteneurs d'application
- **Contrôles** : Security Groups avec accès strict depuis la DMZ
- **Accès** : Uniquement depuis la DMZ, pas d'accès Internet direct
- **Objectif** : Isoler la logique métier et les services applicatifs

#### 3. Zone Données Privée
- **Composants** : RDS, Aurora, ElastiCache, DynamoDB
- **Contrôles** : Security Groups hyper-restrictifs, authentification forte
- **Accès** : Uniquement depuis la zone applicative, pas de route Internet
- **Objectif** : Protection maximale des données sensibles

#### 4. Zone Gestion Privée
- **Composants** : Bastion hosts, VPN, AWS Systems Manager
- **Contrôles** : Authentification MFA, IPs sources limitées, journalisation
- **Accès** : Uniquement depuis IPs autorisées avec authentification forte
- **Objectif** : Administration sécurisée et auditée
## 🛡 Contrôles d'Accès Réseau

AccessWeaver implémente plusieurs couches de contrôles d'accès réseau, conformément au principe de défense en profondeur.

### Security Groups

Les Security Groups sont configurés selon le principe du moindre privilège, avec des règles strictes d'entrée et de sortie :

| Groupe de Sécurité | Ingress (Entrée) | Egress (Sortie) | Description |
|-----------------|---------|--------|-------------|
| **alb-sg** | TCP:443 (0.0.0.0/0)<br>TCP:80 (0.0.0.0/0) | TCP:8080 (ecs-sg) | Load Balancer public |
| **api-gw-sg** | TCP:443 (0.0.0.0/0) | TCP:8443 (ecs-sg) | API Gateway |
| **ecs-sg** | TCP:8080 (alb-sg)<br>TCP:8443 (api-gw-sg) | TCP:5432 (db-sg)<br>TCP:6379 (redis-sg)<br>TCP:443 (VPC Endpoints) | Services applicatifs |
| **db-sg** | TCP:5432 (ecs-sg) | - | Base de données |
| **redis-sg** | TCP:6379 (ecs-sg) | - | Cache Redis |
| **lambda-sg** | - | TCP:5432 (db-sg)<br>TCP:6379 (redis-sg)<br>TCP:443 (VPC Endpoints) | Fonctions Lambda |
| **mgmt-sg** | TCP:22 (IP Admins) | ALL | Accès administrateurs |
| **vpc-endpoint-sg** | TCP:443 (ecs-sg, lambda-sg) | - | VPC Endpoints AWS |

#### Exemple de règles Security Group pour ECS (Production)

```hcl
resource "aws_security_group" "ecs_sg" {
  name        = "accessweaver-${var.environment}-ecs-sg"
  description = "Security group for ECS services in ${var.environment}"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow traffic from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description     = "Allow traffic from API Gateway"
    from_port       = 8443
    to_port         = 8443
    protocol        = "tcp"
    security_groups = [aws_security_group.api_gw_sg.id]
  }

  egress {
    description     = "Allow traffic to RDS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.db_sg.id]
  }

  egress {
    description     = "Allow traffic to Redis"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.redis_sg.id]
  }

  egress {
    description     = "Allow traffic to VPC Endpoints"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_endpoint_sg.id]
  }

  tags = {
    Name        = "accessweaver-${var.environment}-ecs-sg"
    Environment = var.environment
    Service     = "security"
    Terraform   = "true"
  }
}
```

### Network ACLs (NACLs)

Les NACLs constituent une couche supplémentaire de protection au niveau subnet. Contrairement aux Security Groups, les NACLs sont apatrides et évaluent les règles dans l'ordre numérique.

#### NACL pour Subnets Publics

| Règle # | Type | Protocole | Port | Source/Destination | Allow/Deny | Description |
|---------|------|-----------|------|-------------------|------------|-------------|
| 100 | Ingress | TCP | 80, 443 | 0.0.0.0/0 | ALLOW | Trafic HTTP/HTTPS entrant |
| 110 | Ingress | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW | Trafic de retour |
| 120 | Ingress | TCP | 22 | IPs Bureau | ALLOW | SSH d'urgence (Production uniquement) |
| * | Ingress | ALL | ALL | 0.0.0.0/0 | DENY | Bloquer tout autre trafic entrant |
| 100 | Egress | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW | Trafic de retour |
| 110 | Egress | TCP | 8080, 8443 | App Subnet CIDR | ALLOW | Trafic vers services app |
| * | Egress | ALL | ALL | 0.0.0.0/0 | DENY | Bloquer tout autre trafic sortant |

#### NACL pour Subnets Applicatifs

| Règle # | Type | Protocole | Port | Source/Destination | Allow/Deny | Description |
|---------|------|-----------|------|-------------------|------------|-------------|
| 100 | Ingress | TCP | 8080, 8443 | Public Subnet CIDR | ALLOW | Trafic depuis ALB/API GW |
| 110 | Ingress | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW | Trafic de retour |
| * | Ingress | ALL | ALL | 0.0.0.0/0 | DENY | Bloquer tout autre trafic entrant |
| 100 | Egress | TCP | 443 | 0.0.0.0/0 | ALLOW | HTTPS sortant (VPC Endpoints) |
| 110 | Egress | TCP | 5432 | Data Subnet CIDR | ALLOW | Trafic vers RDS |
| 120 | Egress | TCP | 6379 | Data Subnet CIDR | ALLOW | Trafic vers Redis |
| 130 | Egress | TCP | 1024-65535 | Public Subnet CIDR | ALLOW | Trafic de retour vers ALB |
| * | Egress | ALL | ALL | 0.0.0.0/0 | DENY | Bloquer tout autre trafic sortant |

### Filtrage Avancé

En plus des contrôles AWS natifs, AccessWeaver implémente des couches de filtrage avancées :

1. **Inspection TLS** : Pour les environnements Production et Staging, le trafic HTTPS est inspecté par les ALBs avec terminaison TLS et re-chiffrement vers les services backend.

2. **Filtrage par URI/Path** : Les Access Control Lists au niveau applicatif filtrent les requêtes par chemin d'URI et méthode HTTP.

3. **Détection de Signature** : Protection contre les patterns d'attaque connus (injection SQL, XSS, etc.) via le WAF.

4. **Rate Limiting Avancé** : Limitation de taux basée sur l'IP client, le User-Agent, et autres attributs HTTP.

5. **Validation de Schéma API** : Les requêtes API sont validées contre un schéma OpenAPI avant d'atteindre les services backend.
## 🔒 Connectivité Privée

AccessWeaver utilise des services de connectivité privée AWS pour éviter l'exposition de trafic sur l'internet public, réduisant ainsi la surface d'attaque.

### VPC Endpoints

Les VPC Endpoints permettent une communication privée avec les services AWS sans passer par l'internet public. AccessWeaver déploie systématiquement les endpoints suivants :

| Service AWS | Type d'Endpoint | Environnements | Justification |
|-------------|----------------|----------------|---------------|
| S3 | Gateway | Tous | Stockage sécurisé pour configurations et backups |
| DynamoDB | Gateway | Tous | Stockage des sessions et états distribués |
| ECR | Interface | Tous | Récupération des images de conteneurs |
| ECS | Interface | Tous | Communications avec l'API ECS |
| CloudWatch | Interface | Tous | Envoi de logs et métriques |
| SSM | Interface | Tous | Gestion sécurisée des instances |
| Secrets Manager | Interface | Tous | Récupération des secrets |
| STS | Interface | Tous | Tokens d'authentification temporaires |
| KMS | Interface | Tous | Opérations de chiffrement et déchiffrement |

#### Implémentation Terraform des VPC Endpoints

```hcl
# Endpoint de passerelle S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [
    aws_route_table.private_app.id,
    aws_route_table.private_data.id
  ]

  tags = {
    Name        = "accessweaver-${var.environment}-s3-endpoint"
    Environment = var.environment
    Service     = "security"
  }
}

# Endpoint d'interface pour ECR API
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]

  tags = {
    Name        = "accessweaver-${var.environment}-ecr-api-endpoint"
    Environment = var.environment
    Service     = "security"
  }
}

# Endpoint d'interface pour ECR DKR
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]

  tags = {
    Name        = "accessweaver-${var.environment}-ecr-dkr-endpoint"
    Environment = var.environment
    Service     = "security"
  }
}
```

### AWS PrivateLink

Pour les services tiers et partenaires, AccessWeaver utilise AWS PrivateLink pour établir une connectivité privée sans exposition à Internet.

#### Cas d'Utilisation PrivateLink

| Service | Type | Utilisation | Environnements |
|---------|------|-------------|----------------|
| Services Partenaires | Consommateur | Accès aux APIs des partenaires | Production, Staging |
| AccessWeaver API | Fournisseur | Exposition des APIs aux clients VPC | Production |
| Service de Monitoring | Consommateur | Télémétrie et observabilité | Tous |

#### Configuration PrivateLink pour Exposition de Service

```hcl
# Service VPC Endpoint pour exposition des APIs AccessWeaver
resource "aws_vpc_endpoint_service" "accessweaver_api" {
  acceptance_required        = true
  network_load_balancer_arns = [aws_lb.internal_nlb.arn]
  allowed_principals         = var.allowed_consumer_principals

  tags = {
    Name        = "accessweaver-${var.environment}-api-endpoint-service"
    Environment = var.environment
    Service     = "security"
  }
}

# Configuration de la politique d'acceptation
resource "aws_vpc_endpoint_service_allowed_principal" "customer_accounts" {
  for_each                = toset(var.customer_account_ids)
  vpc_endpoint_service_id = aws_vpc_endpoint_service.accessweaver_api.id
  principal_arn           = "arn:aws:iam::${each.value}:root"
}
```

### Transit Gateway (Multi-VPC)

Pour les environnements Production et Management, AccessWeaver déploie un AWS Transit Gateway pour une connectivité sécurisée entre VPCs.

#### Architecture Transit Gateway

```
┌────────────────────┐      ┌────────────────────┐
│                    │      │                    │
│   VPC Production   │      │   VPC Management   │
│                    │      │                    │
└────────┬───────────┘      └────────┬───────────┘
         │                           │
         │                           │
         ▼                           ▼
┌────────────────────────────────────────────────┐
│                                                │
│           AWS Transit Gateway                  │
│                                                │
└────────────────────────────────────────────────┘
         ▲                           ▲
         │                           │
         │                           │
┌────────┴───────────┐      ┌────────┴───────────┐
│                    │      │                    │
│    VPC Staging     │      │   VPC Client       │
│                    │      │   (Optionnel)      │
└────────────────────┘      └────────────────────┘
```

#### Sécurité Transit Gateway

| Aspect | Implémentation | Description |
|--------|----------------|-------------|
| Route Tables | Tables de routage séparées | Isolation du trafic par environnement |
| Attachment | Blackhole routes | Blocage du trafic non autorisé |
| Inspection | Gateway Load Balancer | Inspection du trafic inter-VPC (Production) |
| Logging | Flow Logs | Journalisation de tout le trafic Transit Gateway |
| Chiffrement | VPN attachments | Chiffrement du trafic si hybride |
## 💻 Configuration par Environnement

AccessWeaver applique des configurations réseau spécifiques à chaque environnement, équilibrant la sécurité et les contraintes opérationnelles.

### Environnement Development

L'environnement de développement utilise une architecture simplifiée mais maintient des principes de sécurité essentiels.

| Aspect | Configuration | Justification |
|--------|--------------|---------------|
| **VPC** | VPC unique avec CIDR 10.0.0.0/16 | Isolation mais simplicité |
| **Zones de disponibilité** | Mono-AZ (eu-west-1a) | Réduction des coûts |
| **Segmentation** | 3 couches (Public, App, Data) | Simplification mais garde la segmentation essentielle |
| **Internet Access** | NAT Gateway unique | Accès sortant pour tests et développement |
| **VPC Endpoints** | Endpoints essentiels uniquement (S3, ECR, DynamoDB) | Réduction des coûts |
| **Security Groups** | Règles plus permissives entre services | Facilite le développement et debugging |
| **NACLs** | Basiques uniquement | Protection fondamentale |
| **WAF** | En mode surveillance uniquement | Détection sans blocage |
| **Flow Logs** | Échantillonnage 10% | Réduction des coûts |

#### Diagramme Simplifié

```
┌────────────────────────────────────────────────────────┐
│                 VPC Dev AccessWeaver                   │
│                                                        │
│  ┌─────────────────────┐   ┌─────────────────────┐    │
│  │    Zone Publique    │   │    Zone App/Data    │    │
│  │                     │   │                     │    │
│  │  ┌───────────────┐  │   │  ┌───────────────┐  │    │
│  │  │ ALB / Bastion │  │   │  │ECS + DB + Redis│  │    │
│  │  └───────────────┘  │   │  └───────────────┘  │    │
│  │                     │   │                     │    │
│  └─────────────────────┘   └─────────────────────┘    │
│                                                        │
└────────────────────────────────────────────────────────┘
```

### Environnement Staging

L'environnement de staging reproduit plus fidèlement la production avec des contrôles de sécurité renforcés.

| Aspect | Configuration | Justification |
|--------|--------------|---------------|
| **VPC** | VPC unique avec CIDR 10.1.0.0/16 | Isolation complète |
| **Zones de disponibilité** | Multi-AZ (eu-west-1a, eu-west-1b) | Haute disponibilité partielle |
| **Segmentation** | 4 couches complètes | Reflète la production |
| **Internet Access** | NAT Gateways redondants | Fiabilité accrue |
| **VPC Endpoints** | Ensemble complet | Comme en production |
| **Security Groups** | Règles restrictives | Comme en production |
| **NACLs** | Configuration complète | Comme en production |
| **WAF** | Mode actif | Blocage des attaques |
| **Flow Logs** | 100% | Analyse complète |

#### Exemple de Configuration NACL Staging

```hcl
resource "aws_network_acl" "private_app_staging" {
  vpc_id     = aws_vpc.staging.id
  subnet_ids = aws_subnet.private_app[*].id

  # Autoriser le trafic depuis ALB
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = join("", aws_subnet.public[*].cidr_block)
    from_port  = 8080
    to_port    = 8443
  }
  
  # Bloquer tout autre trafic entrant
  ingress {
    protocol   = -1
    rule_no    = 32766
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Trafic sortant vers RDS
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = join("", aws_subnet.private_data[*].cidr_block)
    from_port  = 5432
    to_port    = 5432
  }
  
  # Autres règles...

  tags = {
    Name        = "accessweaver-staging-private-app-nacl"
    Environment = "staging"
    Service     = "security"
  }
}
```

### Environnement Production

L'environnement de production implémente l'architecture de sécurité réseau la plus stricte et complète.

| Aspect | Configuration | Justification |
|--------|--------------|---------------|
| **VPC** | VPC unique avec CIDR 10.2.0.0/16 | Isolation complète |
| **Zones de disponibilité** | Multi-AZ (eu-west-1a, eu-west-1b, eu-west-1c) | Haute disponibilité maximale |
| **Segmentation** | 4 couches avec micro-segmentation | Défense en profondeur maximale |
| **Internet Access** | NAT Gateways hautement disponibles | Résilience maximale |
| **VPC Endpoints** | Ensemble complet avec haute disponibilité | Communication privée complète |
| **Security Groups** | Règles hautement restrictives | Principe du moindre privilège strict |
| **NACLs** | Configuration avancée avec filtrage strict | Protection multicouche |
| **WAF** | Mode protection avancé avec règles personnalisées | Protection maximale |
| **DDoS Protection** | AWS Shield Advanced | Protection contre les attaques volumétriques |
| **Flow Logs** | 100% avec analyse en temps réel | Détection d'anomalies |
| **Network Firewall** | Déployé en mode inspection | Analyse de paquets profonde |

#### Matrice de Communication Inter-Services (Production)

| Source | Destination | Ports | Protocole | Justification |
|--------|------------|-------|-----------|---------------|
| Internet | ALB | 443 | HTTPS | API publique |
| ALB | ECS Services | 8080 | HTTP (interne) | Communication API |
| ECS Services | RDS | 5432 | PostgreSQL | Accès base de données |
| ECS Services | Redis | 6379 | Redis | Cache de session |
| ECS Services | S3 Endpoint | 443 | HTTPS | Stockage de fichiers |
| ECS Services | Secrets Manager | 443 | HTTPS | Récupération de secrets |
| Bastion | ECS Services | 22 | SSH | Administration d'urgence |
| Bastion | RDS | 5432 | PostgreSQL | Administration d'urgence |

Cette matrice est implémentée via une combinaison de Security Groups, NACLs et politiques IAM pour un contrôle d'accès granulaire.
## 📟 Implémentation Terraform

AccessWeaver utilise Terraform pour implémenter et maintenir l'infrastructure réseau sécurisée de manière cohérente et reproductible.

### Module VPC Principal

```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = "accessweaver-${var.environment}"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = concat(var.app_subnet_cidrs, var.data_subnet_cidrs, var.mgmt_subnet_cidrs)
  
  # Subnets par type (utilisation de tags)
  public_subnet_tags = {
    Type = "Public"
    Tier = "DMZ"
  }
  
  private_subnet_tags = {
    for i, subnet in concat(var.app_subnet_cidrs, var.data_subnet_cidrs, var.mgmt_subnet_cidrs) :
    "Name" => i < length(var.app_subnet_cidrs) ? "App" : 
             (i < length(var.app_subnet_cidrs) + length(var.data_subnet_cidrs) ? "Data" : "Management")
  }

  # NAT Gateway - Un par AZ en production et staging, un seul en dev
  enable_nat_gateway = true
  single_nat_gateway = var.environment == "development" ? true : false
  one_nat_gateway_per_az = var.environment == "production" || var.environment == "staging" ? true : false

  # VPC Flow Logs
  enable_flow_log = true
  flow_log_destination_type = "s3"
  flow_log_destination_arn = aws_s3_bucket.flow_logs.arn
  flow_log_traffic_type = "ALL"
  flow_log_max_aggregation_interval = 60

  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Endpoints VPC (Gateway)
  enable_s3_endpoint = true
  enable_dynamodb_endpoint = true

  tags = {
    Environment = var.environment
    Service     = "network"
    Terraform   = "true"
    Security    = "high"
  }
}
```

### Security Groups Essentiels

```hcl
# Security Group pour Application Load Balancer
resource "aws_security_group" "alb" {
  name        = "accessweaver-${var.environment}-alb-sg"
  description = "Controls access to the ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from world"
  }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from world (redirected to HTTPS)"
  }

  egress {
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080
    security_groups = [aws_security_group.ecs.id]
    description = "Traffic to ECS services"
  }

  tags = {
    Name        = "accessweaver-${var.environment}-alb-sg"
    Environment = var.environment
    Service     = "security"
  }
}

# Security Group pour Services ECS
resource "aws_security_group" "ecs" {
  name        = "accessweaver-${var.environment}-ecs-sg"
  description = "Controls access to the ECS services"
  vpc_id      = module.vpc.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = 8080
    to_port         = 8080
    security_groups = [aws_security_group.alb.id]
    description     = "Requests from ALB"
  }

  egress {
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [aws_security_group.db.id]
    description     = "PostgreSQL access"
  }

  egress {
    protocol        = "tcp"
    from_port       = 6379
    to_port         = 6379
    security_groups = [aws_security_group.redis.id]
    description     = "Redis access"
  }

  egress {
    protocol        = "tcp"
    from_port       = 443
    to_port         = 443
    security_groups = [aws_security_group.vpc_endpoints.id]
    description     = "VPC Endpoints access"
  }

  tags = {
    Name        = "accessweaver-${var.environment}-ecs-sg"
    Environment = var.environment
    Service     = "security"
  }
}

# Security Group pour RDS
resource "aws_security_group" "db" {
  name        = "accessweaver-${var.environment}-db-sg"
  description = "Controls access to the RDS database"
  vpc_id      = module.vpc.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [aws_security_group.ecs.id]
    description     = "PostgreSQL from ECS services"
  }

  # En production, backup emergency access
  dynamic "ingress" {
    for_each = var.environment == "production" ? [1] : []
    content {
      protocol        = "tcp"
      from_port       = 5432
      to_port         = 5432
      security_groups = [aws_security_group.bastion.id]
      description     = "Emergency DB access from Bastion"
    }
  }

  tags = {
    Name        = "accessweaver-${var.environment}-db-sg"
    Environment = var.environment
    Service     = "security"
  }
}
```

### NACLs et Routes

```hcl
# NACL pour Subnet Applicatif
resource "aws_network_acl" "app_subnet" {
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets_app

  # Trafic entrant depuis ALB
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = join(",", module.vpc.public_subnets_cidr_blocks)
    from_port  = 8080
    to_port    = 8080
  }

  # Trafic de retour
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Bloquer tout autre trafic entrant
  ingress {
    protocol   = -1
    rule_no    = 32766
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Trafic sortant vers RDS
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = join(",", module.vpc.private_subnets_data_cidr_blocks)
    from_port  = 5432
    to_port    = 5432
  }

  # Trafic sortant vers Redis
  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = join(",", module.vpc.private_subnets_data_cidr_blocks)
    from_port  = 6379
    to_port    = 6379
  }

  # Trafic de retour
  egress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Bloquer tout autre trafic sortant
  egress {
    protocol   = -1
    rule_no    = 32766
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name        = "accessweaver-${var.environment}-app-nacl"
    Environment = var.environment
    Service     = "security"
  }
}
```
## 📊 Monitoring et Validation

AccessWeaver implémente une surveillance continue de la sécurité réseau pour détecter et répondre rapidement aux anomalies ou tentatives d'intrusion.

### VPC Flow Logs

Les Flow Logs capturent les informations sur le trafic IP vers et depuis les interfaces réseau dans les VPC.

#### Configuration Flow Logs

```hcl
resource "aws_flow_log" "main" {
  log_destination      = aws_s3_bucket.flow_logs.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = module.vpc.vpc_id
  
  # Format personnalisé pour une analyse approfondie
  log_format = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${vpc-id} $${subnet-id} $${instance-id} $${tcp-flags} $${type} $${pkt-srcaddr} $${pkt-dstaddr} $${region} $${az-id} $${sublocation-type} $${sublocation-id}"

  tags = {
    Name        = "accessweaver-${var.environment}-flow-logs"
    Environment = var.environment
    Service     = "security"
  }
}
```

#### Analyse Flow Logs avec Athena

```hcl
resource "aws_athena_named_query" "suspicious_traffic" {
  name        = "accessweaver-${var.environment}-suspicious-traffic"
  description = "Détecte les modèles de trafic suspects dans les Flow Logs"
  database    = aws_athena_database.security_analytics.name
  query       = <<-EOF
    SELECT
      interface_id,
      srcaddr,
      dstaddr,
      srcport,
      dstport,
      protocol,
      action,
      COUNT(*) as connection_count
    FROM
      ${aws_athena_database.security_analytics.name}.flow_logs
    WHERE
      date_partition = '$${date:yyyy-MM-dd}'
      AND action = 'REJECT'
      -- Filtrer les tentatives de connexion rejetées
    GROUP BY
      interface_id, srcaddr, dstaddr, srcport, dstport, protocol, action
    HAVING
      COUNT(*) > 10
    ORDER BY
      connection_count DESC
  EOF
}
```

### AWS Network Analyzer

Network Analyzer est utilisé pour valider continuellement les configurations réseau et identifier les problèmes potentiels de sécurité.

#### Vérifications Réalisées

| Type de Vérification | Description | Environnements |
|---------------------|-------------|----------------|
| Accessibilité | Vérification des ressources exposées non intentionnellement | Tous |
| Redondance | Validation de la redondance des chemins réseau | Production, Staging |
| Connectivité | Tests de connectivité entre composants | Tous |
| Blocage inattendu | Détection de routes, NACL ou SG bloquant du trafic légitime | Tous |
| Routage Internet | Identification des routes Internet non autorisées | Production |

### Alertes de Sécurité

AccessWeaver a configuré plusieurs alertes pour détecter et répondre aux anomalies réseau.

| Alerte | Description | Seuil | Action |
|--------|-------------|-------|--------|
| **Trafic anormal entrant** | Volume élevé de trafic entrant | >2x baseline | Notification + Auto-scaling |
| **Trafic anormal sortant** | Volume élevé de trafic sortant (possible exfiltration) | >3x baseline | Notification + Investigation |
| **Connexions bloquées répétées** | Tentatives répétées de connexion bloquées depuis la même source | >10 en 5 min | Notification + Blocage temporaire |
| **Pics d'utilisation API** | Utilisation anormale des API (possible scan) | >5x baseline | Notification + Throttling temporaire |
| **Modification de SG/NACL** | Modification des règles de sécurité réseau | Tout changement | Notification + Vérification |

#### CloudWatch Alarm pour Trafic Suspect

```hcl
resource "aws_cloudwatch_metric_alarm" "suspicious_traffic" {
  alarm_name          = "accessweaver-${var.environment}-suspicious-traffic"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/NetworkFirewall"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.environment == "production" ? "50" : "100"
  alarm_description   = "Cette alarme se déclenche quand un nombre élevé de requêtes est bloqué"
  
  dimensions = {
    Firewall = aws_networkfirewall_firewall.main[0].name
  }
  
  alarm_actions = [aws_sns_topic.security_alerts.arn]
}
```

### Tests de Pénétration

AccessWeaver réalise régulièrement des tests de pénétration de l'infrastructure réseau.

#### Méthodologie et Fréquence

| Type de Test | Fréquence | Environnements | Cible |
|--------------|-----------|----------------|-------|
| **External Pentest** | Trimestriel | Production | Périmètre externe, APIs publiques |
| **Internal Pentest** | Semestriel | Production, Staging | Segments réseau internes |
| **Test de Segmentation** | Trimestriel | Tous | Validation de l'isolation des zones |
| **Scan de Vulnérabilité** | Hebdomadaire | Tous | Tous les composants exposés |
| **Red Team** | Annuel | Production | Infrastructure complète |

### Infrastructure as Code Validation

Toutes les modifications de l'infrastructure réseau passent par une validation automatisée.

```hcl
# Pipeline CI/CD pour validation de l'infrastructure
resource "aws_codepipeline" "network_validation" {
  name     = "accessweaver-${var.environment}-network-validation"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifact_store.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "accessweaver/aw-infrastructure-as-code"
        BranchName       = var.branch_name
      }
    }
  }

  stage {
    name = "SecurityValidation"
    action {
      name             = "TerraformValidate"
      category         = "Test"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["validate_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.terraform_validate.name
      }
    }
    action {
      name             = "CheckovScan"
      category         = "Test"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.checkov_scan.name
      }
    }
  }

  # Autres étapes...
}
```

## 📝 Références

- [AWS Security Best Practices](https://docs.aws.amazon.com/whitepapers/latest/aws-security-best-practices/welcome.html)
- [AWS VPC Security](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [Network Segmentation Strategies](https://d1.awsstatic.com/whitepapers/Security/security-pillar-workload-separation.pdf)
- [NIST Security Guidelines](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-53r5.pdf)
- [CIS AWS Benchmarks](https://www.cisecurity.org/benchmark/amazon_web_services/)
- [Cloud Security Alliance](https://cloudsecurityalliance.org/research/guidance/)
- [OWASP Network Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
