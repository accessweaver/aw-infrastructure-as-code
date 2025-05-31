# 🌐 Module VPC - AccessWeaver Infrastructure

Documentation complète du module VPC pour AccessWeaver - Réseau et connectivité AWS.

---

## 📋 Table des Matières

- [Vue d'Ensemble](#vue-densemble)
- [Architecture Réseau](#architecture-réseau)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
- [Sécurité](#sécurité)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Vue d'Ensemble

### **Objectif du Module**
Le module VPC crée l'infrastructure réseau complète pour AccessWeaver avec :
- **Isolation multi-environnements** avec des CIDR blocks distincts
- **Haute disponibilité** avec multi-AZ deployment
- **Sécurité réseau** avec subnets publics/privés séparés
- **Connectivité internet** optimisée avec NAT Gateways

### **Ressources Créées**
```
🌐 VPC Principal
├── 📡 Internet Gateway
├── 🔀 Route Tables (publiques/privées)
├── 🌍 Public Subnets (ALB, NAT Gateway)
├── 🔒 Private Subnets (ECS, applications)
├── 🗄️ Database Subnets (RDS, Redis)
├── 🚪 NAT Gateways (connectivité sortante)
└── 🛡️ Network ACLs (sécurité supplémentaire)
```

### **Avantages**
- ✅ **Multi-AZ natif** pour haute disponibilité
- ✅ **Isolation par couches** (web/app/data)
- ✅ **Évolutivité** avec réservation d'IP addresses
- ✅ **Sécurité** avec défense en profondeur
- ✅ **Cost optimization** avec NAT instances vs NAT Gateway selon l'environnement

---

## 🏗 Architecture Réseau

### **Structure par Environnement**

```
┌─────────────────────────────────────────────────────────────────┐
│                           VPC                                   │
│  ┌─────────────────┬─────────────────┬─────────────────────────┐ │
│  │   AZ-1a         │   AZ-1b         │   AZ-1c                 │ │
│  │                 │                 │                         │ │
│  │ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────────────┐ │ │
│  │ │Public Subnet│ │ │Public Subnet│ │ │Public Subnet        │ │ │
│  │ │ALB + NAT GW │ │ │ALB + NAT GW │ │ │ALB + NAT GW         │ │ │
│  │ └─────────────┘ │ └─────────────┘ │ └─────────────────────┘ │ │
│  │                 │                 │                         │ │
│  │ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────────────┐ │ │
│  │ │Private      │ │ │Private      │ │ │Private              │ │ │
│  │ │Subnet       │ │ │Subnet       │ │ │Subnet               │ │ │
│  │ │ECS Tasks    │ │ │ECS Tasks    │ │ │ECS Tasks            │ │ │
│  │ └─────────────┘ │ └─────────────┘ │ └─────────────────────┘ │ │
│  │                 │                 │                         │ │
│  │ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────────────┐ │ │
│  │ │Database     │ │ │Database     │ │ │Database             │ │ │
│  │ │Subnet       │ │ │Subnet       │ │ │Subnet               │ │ │
│  │ │RDS + Redis  │ │ │RDS + Redis  │ │ │RDS + Redis          │ │ │
│  │ └─────────────┘ │ └─────────────┘ │ └─────────────────────┘ │ │
│  └─────────────────┴─────────────────┴─────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### **CIDR Allocation Strategy**

| Environment | VPC CIDR | Public Subnets | Private Subnets | DB Subnets |
|-------------|----------|----------------|-----------------|------------|
| **Dev** | 10.0.0.0/16 | 10.0.1-3.0/24 | 10.0.10-12.0/24 | 10.0.20-22.0/24 |
| **Staging** | 10.1.0.0/16 | 10.1.1-3.0/24 | 10.1.10-12.0/24 | 10.1.20-22.0/24 |
| **Prod** | 10.2.0.0/16 | 10.2.1-3.0/24 | 10.2.10-12.0/24 | 10.2.20-22.0/24 |

### **Répartition des IP Addresses**

```hcl
# Calcul automatique des subnets
locals {
  # Public subnets: .1.0/24, .2.0/24, .3.0/24
  public_subnet_cidrs = [
    for i in range(length(var.availability_zones)) : 
    cidrsubnet(var.vpc_cidr, 8, i + 1)
  ]
  
  # Private subnets: .10.0/24, .11.0/24, .12.0/24  
  private_subnet_cidrs = [
    for i in range(length(var.availability_zones)) : 
    cidrsubnet(var.vpc_cidr, 8, i + 10)
  ]
  
  # Database subnets: .20.0/24, .21.0/24, .22.0/24
  database_subnet_cidrs = [
    for i in range(length(var.availability_zones)) : 
    cidrsubnet(var.vpc_cidr, 8, i + 20)
  ]
}
```

---

## ⚙️ Configuration

### **Variables d'Entrée**

```hcl
# modules/vpc/variables.tf

variable "project_name" {
  description = "Nom du projet AccessWeaver"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.project_name))
    error_message = "Le nom du projet doit contenir uniquement des lettres minuscules, chiffres et tirets."
  }
}

variable "environment" {
  description = "Environnement de déploiement"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être: dev, staging ou prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block pour le VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Le CIDR VPC doit être valide."
  }
}

variable "availability_zones" {
  description = "Liste des zones de disponibilité"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  
  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Au moins 2 zones de disponibilité sont requises pour la haute disponibilité."
  }
}

variable "enable_dns_hostnames" {
  description = "Activer les noms d'hôtes DNS dans le VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Activer le support DNS dans le VPC"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Créer des NAT Gateways pour la connectivité sortante"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Utiliser un seul NAT Gateway (économies pour dev)"
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Activer les logs de flux VPC"
  type        = bool
  default     = false
}

variable "additional_tags" {
  description = "Tags additionnels à appliquer aux ressources"
  type        = map(string)
  default     = {}
}
```

### **Configuration par Environnement**

#### **Development - Optimisé Coût**
```hcl
# Configuration économique pour développement
vpc_cidr = "10.0.0.0/16"
availability_zones = ["eu-west-1a"]      # Single AZ
enable_nat_gateway = true
single_nat_gateway = true                # Un seul NAT Gateway
enable_flow_logs = false                 # Pas de logs pour économiser
```

#### **Staging - Production-like**
```hcl
# Configuration similaire à la production
vpc_cidr = "10.1.0.0/16" 
availability_zones = ["eu-west-1a", "eu-west-1b"]
enable_nat_gateway = true
single_nat_gateway = false               # Multi-AZ NAT
enable_flow_logs = true                  # Logs pour debug
```

#### **Production - Haute Disponibilité**
```hcl
# Configuration production avec redondance maximale
vpc_cidr = "10.2.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
enable_nat_gateway = true
single_nat_gateway = false               # NAT Gateway par AZ
enable_flow_logs = true                  # Monitoring complet
```

---

## 🛠 Utilisation

### **1. Intégration dans l'Infrastructure**

```hcl
# environments/prod/main.tf

module "vpc" {
  source = "../../modules/vpc"
  
  # Configuration de base
  project_name = var.project_name
  environment  = var.environment
  
  # Réseau
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  
  # Options de connectivité
  enable_nat_gateway = var.environment == "dev" ? true : true
  single_nat_gateway = var.environment == "dev" ? true : false
  
  # Monitoring
  enable_flow_logs = var.environment != "dev"
  
  # Tags
  additional_tags = var.additional_tags
}
```

### **2. Outputs Disponibles**

```hcl
# modules/vpc/outputs.tf

output "vpc_id" {
  description = "ID du VPC créé"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block du VPC"
  value       = aws_vpc.main.cidr_block
}

output "internet_gateway_id" {
  description = "ID de l'Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "public_subnet_ids" {
  description = "Liste des IDs des subnets publics"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Liste des IDs des subnets privés"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "Liste des IDs des subnets database"
  value       = aws_subnet.database[*].id
}

output "database_subnet_group_name" {
  description = "Nom du subnet group pour RDS"
  value       = aws_db_subnet_group.database.name
}

output "elasticache_subnet_group_name" {
  description = "Nom du subnet group pour ElastiCache"
  value       = aws_elasticache_subnet_group.database.name
}

output "nat_gateway_ids" {
  description = "Liste des IDs des NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "public_route_table_ids" {
  description = "Liste des IDs des tables de routage publiques"
  value       = aws_route_table.public[*].id
}

output "private_route_table_ids" {
  description = "Liste des IDs des tables de routage privées"
  value       = aws_route_table.private[*].id
}
```

### **3. Utilisation des Outputs**

```hcl
# Utilisation dans d'autres modules

module "security_groups" {
  source = "../../modules/security-groups"
  
  vpc_id = module.vpc.vpc_id
  # ...
}

module "rds" {
  source = "../../modules/rds"
  
  vpc_id                = module.vpc.vpc_id
  database_subnet_ids   = module.vpc.database_subnet_ids
  subnet_group_name     = module.vpc.database_subnet_group_name
  # ...
}

module "ecs" {
  source = "../../modules/ecs"
  
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  # ...
}

module "alb" {
  source = "../../modules/alb"
  
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  # ...
}
```

---

## 🛡️ Sécurité

### **1. Network ACLs**

#### **Configuration par Défaut**
```hcl
# Network ACL pour subnets publics
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  # Entrée HTTP/HTTPS
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Trafic de retour éphémère
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Sortie autorisée
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-nacl"
    Type = "Public"
  })
}

# Network ACL pour subnets privés (plus restrictif)
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  # Trafic depuis subnets publics seulement
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = aws_subnet.public[0].cidr_block
    from_port  = 8080
    to_port    = 8090
  }

  # Trafic interne VPC
  ingress {
    protocol   = "-1"
    rule_no    = 200
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Trafic de retour éphémère
  ingress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Sortie autorisée
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-nacl"
    Type = "Private"
  })
}
```

### **2. VPC Flow Logs**

```hcl
# VPC Flow Logs pour monitoring sécurité
resource "aws_flow_log" "vpc" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_log[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc-flow-logs"
  })
}

# CloudWatch Log Group pour les flow logs
resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.project_name}-${var.environment}-flow-logs"
  retention_in_days = var.environment == "prod" ? 90 : 30

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc-flow-logs"
  })
}

# IAM Role pour les flow logs
resource "aws_iam_role" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.project_name}-${var.environment}-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.project_name}-${var.environment}-flow-log-policy"
  role = aws_iam_role.flow_log[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
```

### **3. Security Best Practices**

#### **Isolation des Couches**
```bash
# Vérification de l'isolation réseau
# Public subnets - doivent avoir route vers IGW
aws ec2 describe-route-tables --filters "Name=tag:Type,Values=Public" \
  --query 'RouteTables[*].Routes[?DestinationCidrBlock==`0.0.0.0/0`]'

# Private subnets - doivent avoir route vers NAT Gateway  
aws ec2 describe-route-tables --filters "Name=tag:Type,Values=Private" \
  --query 'RouteTables[*].Routes[?DestinationCidrBlock==`0.0.0.0/0`]'

# Database subnets - pas de route internet directe
aws ec2 describe-route-tables --filters "Name=tag:Type,Values=Database" \
  --query 'RouteTables[*].Routes[?DestinationCidrBlock==`0.0.0.0/0`]'
```

---

## 📊 Monitoring

### **1. CloudWatch Métriques**

#### **Métriques VPC Natives**
```bash
# Métriques automatiques disponibles
- VPC Flow Logs volume
- NAT Gateway data transfer
- NAT Gateway active connections
- Internet Gateway data transfer
```

#### **Custom Metrics via Flow Logs**
```sql
-- Query CloudWatch Insights pour analyser le trafic
fields @timestamp, srcaddr, dstaddr, srcport, dstport, protocol, action
| filter action = "REJECT"
| stats count() by srcaddr
| sort count desc
| limit 20
```

### **2. Alarms Recommandées**

```hcl
# Alarm sur trafic rejeté élevé (signe d'attaque)
resource "aws_cloudwatch_metric_alarm" "high_rejected_traffic" {
  count = var.enable_flow_logs && var.environment == "prod" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-high-rejected-traffic"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RejectedConnectionCount"
  namespace           = "AWS/VPC"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "High number of rejected connections detected"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    VpcId = aws_vpc.main.id
  }
}

# Alarm sur utilisation NAT Gateway élevée
resource "aws_cloudwatch_metric_alarm" "nat_gateway_high_usage" {
  count = var.enable_nat_gateway && var.environment != "dev" ? length(aws_nat_gateway.main) : 0

  alarm_name          = "${var.project_name}-${var.environment}-nat-gateway-high-usage-${count.index}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BytesOutToDestination"
  namespace           = "AWS/NATGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10000000000" # 10 GB
  alarm_description   = "High NAT Gateway usage detected"

  dimensions = {
    NatGatewayId = aws_nat_gateway.main[count.index].id
  }
}
```

### **3. Dashboard VPC**

```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/NATGateway", "BytesOutToDestination"],
          [".", "BytesInFromDestination"],
          [".", "PacketsOutToDestination"],
          [".", "PacketsInFromDestination"]
        ],
        "period": 300,
        "stat": "Sum",
        "region": "eu-west-1",
        "title": "NAT Gateway Traffic"
      }
    },
    {
      "type": "log",
      "properties": {
        "query": "SOURCE '/aws/vpc/accessweaver-prod-flow-logs'\n| fields @timestamp, srcaddr, dstaddr, action\n| filter action = \"REJECT\"\n| stats count() by srcaddr\n| sort count desc\n| limit 10",
        "region": "eu-west-1",
        "title": "Top Rejected Source IPs"
      }
    }
  ]
}
```

---

## 🚨 Troubleshooting

### **1. Problèmes de Connectivité**

#### **Symptôme : Services ne peuvent pas accéder à Internet**
```bash
# Diagnostic étape par étape

# 1. Vérifier les routes privées
aws ec2 describe-route-tables \
  --filters "Name=tag:Type,Values=Private" \
  --query 'RouteTables[*].{TableId:RouteTableId,Routes:Routes[?DestinationCidrBlock==`0.0.0.0/0`]}'

# 2. Vérifier l'état des NAT Gateways
aws ec2 describe-nat-gateways \
  --filter "Name=tag:Environment,Values=prod" \
  --query 'NatGateways[*].{Id:NatGatewayId,State:State,SubnetId:SubnetId}'

# 3. Vérifier les Elastic IPs
aws ec2 describe-addresses \
  --filters "Name=domain,Values=vpc" \
  --query 'Addresses[*].{AllocationId:AllocationId,AssociationId:AssociationId,PublicIp:PublicIp}'
```

#### **Solution**
```bash
# Recréer les routes si nécessaire
# Via Terraform:
terraform taint 'module.vpc.aws_route.private_nat_gateway[0]'
terraform apply
```

### **2. Problèmes de Résolution DNS**

#### **Symptôme : Noms d'hôtes ne se résolvent pas**
```bash
# Vérifier la configuration DNS du VPC
aws ec2 describe-vpcs --vpc-ids vpc-12345678 \
  --query 'Vpcs[0].{DnsHostnames:DnsHostnames,DnsSupport:DnsSupport}'

# Doit retourner: DnsHostnames: true, DnsSupport: true
```

#### **Solution**
```hcl
# S'assurer que DNS est activé dans le module
enable_dns_hostnames = true
enable_dns_support   = true
```

### **3. Problèmes de Connectivité Inter-AZ**

#### **Symptôme : Services dans différentes AZ ne communiquent pas**
```bash
# Vérifier les NACLs
aws ec2 describe-network-acls \
  --filters "Name=vpc-id,Values=vpc-12345678" \
  --query 'NetworkAcls[*].{AclId:NetworkAclId,Rules:Entries[?RuleAction==`deny`]}'
```

#### **Solution**
```bash
# Vérifier que les NACLs permettent le trafic interne VPC
# Règle ingress pour trafic interne:
# Protocol: -1, CIDR: 10.x.0.0/16, Action: ALLOW
```

### **4. Coûts NAT Gateway Élevés**

#### **Symptôme : Facture NAT Gateway importante**
```bash
# Analyser l'utilisation des NAT Gateways
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination \
  --dimensions Name=NatGatewayId,Value=nat-12345678 \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-31T23:59:59Z \
  --period 86400 \
  --statistics Sum
```

#### **Solutions d'Optimisation**
```hcl
# Option 1: Single NAT Gateway pour dev/staging
single_nat_gateway = var.environment != "prod"

# Option 2: NAT Instance pour très petits environnements
# (Remplacer NAT Gateway par NAT Instance dans le code)

# Option 3: VPC Endpoints pour services AWS
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  route_table_ids = aws_route_table.private[*].id
}
```

---

## 📚 Ressources et Références

### **Documentation AWS**
- [VPC User Guide](https://docs.aws.amazon.com/vpc/latest/userguide/)
- [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
- [NAT Gateways](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)
- [Network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)

### **Best Practices**
- [AWS Well-Architected - Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/)
- [VPC Security Best Practices](https://aws.amazon.com/answers/networking/aws-single-vpc-design/)

### **Outils de Diagnostic**
```bash
# Script de diagnostic VPC complet
./scripts/diagnose-vpc.sh prod

# Analyse des coûts réseau
aws ce get-cost-and-usage --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["Amazon Virtual Private Cloud"]}}'
```

---

## ✅ Checklist de Validation

### **Post-Déploiement**
- [ ] VPC créé avec bon CIDR
- [ ] Subnets dans toutes les AZ requises
- [ ] Internet Gateway attaché
- [ ] NAT Gateways fonctionnels (test ping externe depuis private subnet)
- [ ] Routes correctement configurées
- [ ] DNS resolution activée
- [ ] NACLs configurées selon les besoins
- [ ] Flow Logs activés (si requis)
- [ ] Tags appliqués correctement

### **Tests de Connectivité**
- [ ] Public subnets → Internet (✅)
- [ ] Private subnets → Internet via NAT (✅)
- [ ] Database subnets → Pas d'accès Internet direct (❌)
- [ ] Communication inter-AZ fonctionnelle (✅)
- [ ] Résolution DNS interne (✅)

### **Monitoring & Alerting**
- [ ] Métriques NAT Gateway collectées
- [ ] Alarms configurées pour usage élevé
- [ ] Flow Logs analysables dans CloudWatch
- [ ] Dashboard VPC créé

---

**🌐 Module VPC AccessWeaver configuré avec succès !**

Le réseau est maintenant prêt pour héberger les autres composants AccessWeaver avec sécurité et haute disponibilité.

**Prochaines étapes :**
- [Module RDS](./modules/rds.md) - Base de données PostgreSQL
- [Module Security Groups](./modules/security-groups.md) - Règles de sécurité
- [Module ECS](./modules/ecs.md) - Orchestration des microservices