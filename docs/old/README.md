# 📚 Documentation Architecture AccessWeaver

Documentation complète de l'infrastructure AWS pour AccessWeaver - Système d'autorisation enterprise open-source.

## 🏗 Vue d'Ensemble de l'Architecture

AccessWeaver est déployé sur AWS avec une architecture microservices moderne, scalable et sécurisée utilisant les services managés AWS pour une maintenance minimale et une haute disponibilité.

### Architecture Globale

```
                    🌐 Internet
                        ↓
              ┌─────────────────────┐
              │     Route 53        │
              │ accessweaver.com    │
              └─────────┬───────────┘
                        │
              ┌─────────▼───────────┐
              │      AWS WAF        │
              │   🛡️ Protection      │
              └─────────┬───────────┘
                        │
              ┌─────────▼───────────┐
              │   ALB + SSL Term    │
              │  Load Balancer      │
              └─────────┬───────────┘
                        │
              ┌─────────▼───────────┐
              │   ECS Fargate       │
              │  5 Microservices    │
              │                     │
              │ API-GTW │ PDP │ PAP │
              │ TENANT  │ AUDIT     │
              └──┬────────────┬─────┘
                 │            │
    ┌────────────▼─┐      ┌───▼──────────┐
    │ PostgreSQL   │      │ Redis Cache  │
    │ Multi-tenant │      │ <1ms latency │
    │ RLS Security │      │ Cluster Mode │
    └──────────────┘      └──────────────┘
                 │            │
              ┌──▼────────────▼──┐
              │   VPC Network     │
              │  Multi-AZ + NAT   │
              └───────────────────┘
```

## 📋 Table des Matières

### 🚀 Getting Started
- **[Quick Start Guide](./quick-start.md)** - Déploiement en 30 minutes
- **[Prerequisites](./prerequisites.md)** - Prérequis et setup initial
- **[Environment Setup](./environment-setup.md)** - Configuration AWS et Terraform

### 🏗 Architecture Détaillée
- **[Architecture Overview](./architecture/overview.md)** - Vue d'ensemble technique
- **[Network Architecture](./architecture/network.md)** - VPC, subnets, routing
- **[Security Architecture](./architecture/security.md)** - IAM, security groups, encryption
- **[Data Architecture](./architecture/data.md)** - PostgreSQL, Redis, backup strategy

### 📦 Modules Infrastructure
- **[Module VPC](./modules/vpc.md)** - Réseau et connectivité
- **[Module RDS](./modules/rds.md)** - Base de données PostgreSQL
- **[Module Redis](./modules/redis.md)** - Cache distribué ElastiCache
- **[Module ECS](./modules/ecs.md)** - Orchestration microservices
- **[Module ALB](./modules/alb.md)** - Load balancer et SSL

### 🛠 Guides de Déploiement
- **[Development Environment](./deployment/development.md)** - Setup environnement de dev
- **[Staging Environment](./deployment/staging.md)** - Déploiement staging
- **[Production Environment](./deployment/production.md)** - Déploiement production
- **[CI/CD Pipeline](./deployment/cicd.md)** - Automation et déploiement continu

### 🔧 Configuration et Maintenance
- **[Terraform Configuration](./configuration/terraform.md)** - Variables, backend, providers
- **[Secrets Management](./configuration/secrets.md)** - AWS Secrets Manager et SSM
- **[Environment Variables](./configuration/environment.md)** - Configuration par environnement
- **[Scaling Configuration](./configuration/scaling.md)** - Auto-scaling et capacity planning

### 🔐 Sécurité
- **[Security Best Practices](./security/best-practices.md)** - Guidelines sécurité
- **[IAM Policies](./security/iam.md)** - Rôles et permissions
- **[Network Security](./security/network.md)** - Security groups et NACLs
- **[Data Encryption](./security/encryption.md)** - Chiffrement at-rest et in-transit

### 📊 Monitoring et Observabilité
- **[Monitoring Setup](./monitoring/setup.md)** - Configuration monitoring
- **[CloudWatch Dashboards](./monitoring/cloudwatch.md)** - Métriques et dashboards
- **[Alerting](./monitoring/alerting.md)** - Configuration des alertes
- **[Log Management](./monitoring/logs.md)** - Aggregation et analyse des logs

### 💰 Coûts et Optimisation
- **[Cost Analysis](./costs/analysis.md)** - Breakdown des coûts par service
- **[Cost Optimization](./costs/optimization.md)** - Stratégies d'économies
- **[Budgets and Alerts](./costs/budgets.md)** - Contrôle budgétaire

### 🛠 Maintenance et Opérations
- **[Backup Strategy](./operations/backup.md)** - Sauvegarde et restauration
- **[Disaster Recovery](./operations/disaster-recovery.md)** - Plan de continuité
- **[Troubleshooting](./operations/troubleshooting.md)** - Guide de dépannage
- **[Maintenance Tasks](./operations/maintenance.md)** - Tâches récurrentes

### 📈 Performance et Scaling
- **[Performance Tuning](./performance/tuning.md)** - Optimisation des performances
- **[Load Testing](./performance/testing.md)** - Tests de charge
- **[Capacity Planning](./performance/capacity.md)** - Planification de capacité

### 🔄 Migration et Upgrades
- **[Migration Guide](./migration/guide.md)** - Migration vers AccessWeaver
- **[Version Upgrades](./migration/upgrades.md)** - Mise à jour des versions
- **[Rollback Procedures](./migration/rollback.md)** - Procédures de rollback

### 🧪 Testing
- **[Infrastructure Testing](./testing/infrastructure.md)** - Tests d'infrastructure
- **[Integration Testing](./testing/integration.md)** - Tests d'intégration
- **[Chaos Engineering](./testing/chaos.md)** - Tests de résilience

## 🎯 Configurations par Environnement

| Aspect | Development | Staging | Production |
|--------|-------------|---------|------------|
| **Coût estimé** | ~$188/mois | ~$385/mois | ~$902/mois |
| **Instances** | Single-AZ, micro | Multi-AZ, small | Multi-AZ, optimized |
| **Monitoring** | Basique | Complet | Enhanced + alerting |
| **Backup** | 1-7 jours | 7-30 jours | 30-90 jours |
| **Security** | Permissif | Équilibré | Maximum |
| **Scaling** | Manuel | Semi-auto | Full auto |

## 🚨 Quick Reference

### Commandes Terraform Essentielles
```bash
# Initialisation
terraform init

# Plan des changements
terraform plan -var-file="environments/prod/terraform.tfvars"

# Application
terraform apply -var-file="environments/prod/terraform.tfvars"

# Destruction (attention !)
terraform destroy -var-file="environments/prod/terraform.tfvars"
```

### URLs Importantes
```bash
# Health Check
curl https://accessweaver.com/actuator/health

# API Documentation
https://accessweaver.com/swagger-ui/index.html

# Monitoring Dashboard
https://console.aws.amazon.com/cloudwatch/home#dashboards:
```

### Support d'Urgence
```bash
# Logs en temps réel
aws logs tail /ecs/accessweaver-prod/aw-api-gateway --follow

# Status des services
aws ecs describe-services --cluster accessweaver-prod-cluster

# Métriques critiques
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB
```

## 📞 Contacts et Support

| Rôle | Contact | Responsabilité |
|------|---------|----------------|
| **Platform Team** | platform@accessweaver.com | Infrastructure et déploiements |
| **Security Team** | security@accessweaver.com | Sécurité et compliance |
| **DevOps On-Call** | +33 X XX XX XX XX | Incidents production 24/7 |

## 🔄 Historique des Versions

| Version | Date | Changements Majeurs |
|---------|------|-------------------|
| **v1.0.0** | 2025-01-01 | Architecture initiale AWS |
| **v1.1.0** | 2025-02-01 | Ajout WAF et monitoring |
| **v1.2.0** | 2025-03-01 | Optimisation coûts |

## 📚 Ressources Externes

### Documentation AWS
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Security Best Practices](https://aws.amazon.com/security/security-learning/)
- [ECS Best Practices Guide](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)

### Outils Recommandés
- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

---

**📝 Note :** Cette documentation est maintenue par l'équipe Platform et mise à jour à chaque release. Pour contribuer ou signaler des erreurs, créer une issue dans le repository GitHub.