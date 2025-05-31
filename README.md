# 🏗 AccessWeaver Infrastructure as Code

Infrastructure AWS pour AccessWeaver - Système d'autorisation enterprise open-source

## 🎯 Vue d'ensemble

Ce repository contient l'infrastructure Terraform pour déployer AccessWeaver sur AWS avec :
- **Architecture haute disponibilité** sur multiple AZ
- **Multi-environnements** (dev/staging/prod) avec isolation complète
- **Sécurité enterprise** (VPC, Security Groups, encryption at-rest/in-transit)
- **Monitoring et observabilité** intégrés
- **Auto-scaling** et résilience

## 🏗 Architecture Cible

```
Internet
    ↓
┌────────────────────────────────────────────┐
│            Application Load Balancer        │ ← SSL Termination
│              (Multi-AZ)                    │
└─────────────────┬──────────────────────────┘
                  │
    ┌─────────────┼───────────┐
    │             │           │
┌───▼───┐    ┌───▼───┐     ┌──▼──┐
│OPAL   │    │ PDP   │     │ PAP │  ← ECS Fargate Services
│Server │    │+OPA   │     │ UI  │    (Auto-scaling)
└───────┘    └───────┘     └─────┘
                  │
    ┌─────────────┼─────────────┐
    │             │             │
┌───▼───────┐              ┌────▼────┐
│PostgreSQL │              │ Redis   │  ← Managed Services
│(Multi-AZ) │              │Cluster  │    (High Availability)
└───────────┘              └─────────┘
```

## 💰 Coûts Estimés

| Environment | Coût/mois | Configuration |
|-------------|-----------|---------------|
| **Dev**     | ~$80      | Single AZ, t3.micro instances |
| **Staging** | ~$150     | Multi-AZ, t3.small instances |
| **Prod**    | ~$300     | Multi-AZ, optimized instances + backup |

## 🚀 Quick Start

### Prérequis
```bash
# Installer les outils requis
brew install terraform awscli jq
aws configure  # Configurer vos credentials AWS

# Vérifier les versions
terraform --version  # >= 1.6.0
aws --version        # >= 2.0
```

### Déploiement Rapide (Dev)
```bash
# 1. Cloner le repository
git clone https://github.com/accessweaver/aw-infrastructure-as-code.git
cd aw-infrastructure-as-code

# 2. Initialiser le backend S3/DynamoDB
make setup-backend ENV=dev

# 3. Configurer les variables (copier et adapter)
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
# Éditer terraform.tfvars avec vos valeurs

# 4. Déployer l'infrastructure
make deploy ENV=dev

# 5. Vérifier le déploiement
make validate ENV=dev
```

## 📁 Structure du Repository

```
aw-infrastructure-as-code/
├── environments/           # Configurations par environnement
│   ├── dev/               # Développement
│   ├── staging/           # Pre-production
│   └── prod/              # Production
├── modules/               # Modules Terraform réutilisables
│   ├── vpc/              # Virtual Private Cloud
│   ├── ecs/              # Elastic Container Service
│   ├── rds/              # PostgreSQL Database
│   ├── redis/            # ElastiCache Redis
│   ├── alb/              # Application Load Balancer
│   └── monitoring/       # CloudWatch + X-Ray
├── scripts/              # Scripts d'automatisation
└── docs/                 # Documentation détaillée
```

## 🔧 Commandes Principales

```bash
# Opérations sur l'infrastructure
make plan ENV=dev        # 📋 Voir les changements prévus
make apply ENV=dev       # 🚀 Appliquer les changements
make destroy ENV=dev     # 💥 Détruire l'environnement
make validate ENV=dev    # ✅ Valider la configuration

# Utilitaires
make fmt                 # 🎨 Formatter le code Terraform
make security-scan       # 🛡 Scanner la sécurité (tfsec)
make costs ENV=dev       # 💰 Estimer les coûts
make outputs ENV=dev     # 📊 Afficher les outputs Terraform
```

## 🛡 Sécurité

### Mesures Implémentées
- ✅ **VPC isolé** avec subnets public/privé sur 2 AZ minimum
- ✅ **Security Groups** restrictifs (principe du moindre privilège)
- ✅ **Encryption at-rest** : RDS, EBS, S3 avec KMS
- ✅ **Encryption in-transit** : TLS 1.3 pour tous les services
- ✅ **Secrets management** : AWS Systems Manager Parameter Store
- ✅ **IAM roles** : Permissions minimales par service
- ✅ **Network ACLs** : Firewall au niveau subnet
- ✅ **Flow logs** : Monitoring du trafic réseau

### Compliance
- **RGPD** : Encryption, audit logs, data residency EU
- **SOC2** : Access controls, monitoring, incident response
- **ISO27001** : Security controls, risk management

## 📊 Monitoring & Observabilité

### Métriques Collectées
- **Application** : Latence, throughput, erreurs par service
- **Infrastructure** : CPU, mémoire, réseau, disque
- **Business** : Nombre de décisions/sec, cache hit rate
- **Sécurité** : Tentatives d'accès, anomalies

### Dashboards
- **Grafana** : Métriques temps réel + alerting
- **CloudWatch** : Logs centralisés + métriques AWS
- **X-Ray** : Tracing distribué des requêtes

## 🚨 Gestion d'Incidents

### Alertes Automatiques
```yaml
Alertes configurées:
  - Latence > 100ms (P95)
  - Taux d'erreur > 1%
  - CPU > 80% sustained
  - Mémoire > 85%
  - Disk > 80%
  - Database connections > 80%
```

### Playbooks
- [Incident Response](docs/incident-response.md)
- [Disaster Recovery](docs/disaster-recovery.md)
- [Scaling Procedures](docs/scaling.md)

## 🔄 CI/CD Integration

### GitHub Actions
- **Terraform Plan** : Sur chaque PR
- **Security Scan** : tfsec + Checkov
- **Cost Estimation** : Infracost analysis
- **Auto-Apply** : Sur merge vers main (staging/prod)

### Environnements
```yaml
Workflow:
  feature-branch → dev (auto-deploy)
  dev → staging (manual approval)
  staging → prod (manual approval + change window)
```

## 📚 Documentation

- 📋 [Architecture détaillée](docs/architecture.md)
- 🚀 [Guide de déploiement](docs/deployment-guide.md)
- 🔧 [Dépannage](docs/troubleshooting.md)
- 💰 [Optimisation des coûts](docs/cost-optimization.md)
- 🛡 [Guide de sécurité](docs/security-guide.md)
- 📊 [Monitoring](docs/monitoring.md)

## 🤝 Contribution

### Workflow
1. **Fork** le repository
2. **Créer** une feature branch
3. **Tester** localement avec `make validate`
4. **Soumettre** une Pull Request

### Standards
- Code **formaté** avec `terraform fmt`
- **Tests** passants
- **Documentation** mise à jour
- **Security scan** clean

## 📞 Support

- **Issues** : [GitHub Issues](https://github.com/accessweaver/aw-infrastructure-as-code/issues)
- **Discussions** : [GitHub Discussions](https://github.com/accessweaver/aw-infrastructure-as-code/discussions)
- **Documentation** : [Wiki](https://github.com/accessweaver/aw-infrastructure-as-code/wiki)
- **Slack** : #infrastructure channel

## 📄 License

Ce projet est sous licence **Apache 2.0** - voir le fichier [LICENSE](LICENSE) pour plus de détails.

---

**Version** : 1.0  
**Dernière mise à jour** : Mai 2025  
**Mainteneur** : Équipe Infrastructure AccessWeaver