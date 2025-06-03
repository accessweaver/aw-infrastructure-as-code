# 🌐 Services AWS

## Introduction

Ce document présente les services AWS utilisés chez AccessWeaver pour l'infrastructure, le développement, les tests et les opérations. Cette documentation aide à comprendre notre architecture cloud et les différents services que nous utilisons pour construire, tester et opérer notre plateforme.

---

## Services d'Infrastructure

### Réseau

| Service | Usage | Configuration |
|---------|-------|---------------|
| **VPC** | Isolation réseau | Multi-AZ, CIDR 10.0.0.0/16 |
| **Subnet** | Ségmentation réseau | Public/Private, 3 AZs |
| **Route 53** | DNS et routage | Zones privées et publiques |
| **API Gateway** | Gestion des API | REST et HTTP APIs |
| **CloudFront** | CDN | Distribution globale, cache |
| **VPN/Direct Connect** | Connectivité hybride | Pour intégrations entreprise |

### Calcul & Conteneurs

| Service | Usage | Configuration |
|---------|-------|---------------|
| **ECS** | Orchestration de conteneurs | Fargate, Service Discovery |
| **ECR** | Registry de conteneurs | Scan de sécurité activé |
| **Lambda** | Serverless computing | Java 21, Python 3.11 |
| **EC2** | Serveurs virtuels | Pour workloads spécifiques |
| **Batch** | Traitement par lots | Pour jobs de calcul intensif |

### Stockage & Databases

| Service | Usage | Configuration |
|---------|-------|---------------|
| **S3** | Stockage d'objets | Versioning, Lifecycle policies |
| **RDS** | Bases de données relationnelles | PostgreSQL 15.x, Multi-AZ |
| **DynamoDB** | NoSQL | Auto-scaling, DAX |
| **ElastiCache** | Cache en mémoire | Redis, Multi-AZ |
| **EFS** | Système de fichiers | Pour données partagées |

---

## Services DevOps & CI/CD

### Déploiement & Orchestration

| Service | Usage | Intégration |
|---------|-------|-------------|
| **CodePipeline** | Orchestration CI/CD | GitHub, Jenkins |
| **CodeBuild** | Build & Test | Tests d'infrastructure |
| **CodeDeploy** | Déploiement automatique | ECS, Lambda, EC2 |
| **CloudFormation** | IaC natif AWS | Pour ressources non-Terraform |
| **CDK** | IaC programmatique | Pour constructions complexes |

### Monitoring & Logs

| Service | Usage | Configuration |
|---------|-------|---------------|
| **CloudWatch** | Monitoring & Logs | Métriques personnalisées, Dashboards |
| **X-Ray** | Traçage distribué | Analyse des transactions |
| **EventBridge** | Bus d'événements | Automatisation inter-services |
| **CloudTrail** | Audit | Logs centralisés dans S3 |

---

## Services de Test

### Tests d'Infrastructure

| Service | Usage | Outils Intégrés |
|---------|-------|-------------------|
| **CodeBuild** | Exécution des tests Terratest | Terraform, Go, AWS CLI |
| **S3** | Stockage des résultats de test | Rapports HTML, XML |
| **IAM** | Rôles pour tests automatisés | Permissions temporaires |
| **Config** | Validation de conformité | Règles personnalisées |
| **CloudFormation Guard** | Validation préventive | Syntaxe, bonnes pratiques |

### Tests de Sécurité

| Service | Usage | Configuration |
|---------|-------|---------------|
| **Security Hub** | Tableau de bord central | Intégration avec autres outils |
| **GuardDuty** | Détection des menaces | ML, surveillance continue |
| **Inspector** | Analyse de vulnérabilités | Scan automatique des instances |
| **IAM Access Analyzer** | Analyse d'accès | Identification des risques |
| **WAF** | Protection des API/sites | Règles OWASP Top 10 |

### Tests de Performance

| Service | Usage | Métriques Clés |
|---------|-------|---------------|
| **CloudWatch Synthetics** | Tests synthétiques | Disponibilité, latence |
| **CloudWatch Evidently** | Tests A/B | Expérimentations |
| **Load Balancer** | Tests de charge | Connexions, TPS |
| **X-Ray** | Analyse performance | Latence par segment |

### Tests de Résilience

| Service | Usage | Scénarios |
|---------|-------|----------|
| **Fault Injection Service (FIS)** | Tests de chaos | Défaillances contrôlées |
| **Resilience Hub** | Évaluation de résilience | Recommandations |
| **Route 53 Application Recovery** | Failover | Tests de DR |
| **CloudWatch Alarms** | Détection des pannes | Alertes automatiques |

---

## Configuration d'AWS FIS pour Tests de Chaos

### Exemples de Templates d'Expérimentations

```json
{
  "description": "Test de résilience avec arrêt d'instances EC2",
  "targets": {
    "ec2-instances": {
      "resourceType": "aws:ec2:instance",
      "resourceTags": {
        "Environment": "test"
      },
      "selectionMode": "COUNT(1)"
    }
  },
  "actions": {
    "stopInstances": {
      "actionId": "aws:ec2:stop-instances",
      "parameters": {},
      "targets": {
        "Instances": "ec2-instances"
      }
    }
  },
  "stopConditions": [
    {
      "source": "aws:cloudwatch:alarm",
      "value": "arn:aws:cloudwatch:eu-west-1:123456789012:alarm:HighCPUAlarm"
    }
  ],
  "roleArn": "arn:aws:iam::123456789012:role/FISExecutionRole",
  "tags": {
    "Name": "ec2-stop-test",
    "Project": "AccessWeaver-Resilience"
  }
}
```

### Intégration FIS avec CloudWatch

```yaml
# Exemple de configuration pour surveillance d'expériences de chaos
monitoring:
  cloudwatch:
    dashboards:
      - name: FISExperimentDashboard
        widgets:
          - type: metric
            properties:
              metrics:
                - [ "AWS/EC2", "CPUUtilization", "InstanceId", "${TargetInstance}" ]
                - [ "AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", "${LoadBalancerName}" ]
              period: 60
              stat: "Average"
              title: "Impact of FIS Experiment"
    alarms:
      - name: FISExperimentGuardRail
        metric: AWS/ApplicationELB/HTTPCode_ELB_5XX_Count
        threshold: 10
        evaluationPeriods: 3
        comparisonOperator: GreaterThanThreshold
        statistic: Sum
        period: 60
        treatMissingData: notBreaching
```

---

## Services Spécifiques aux Tests pour Java 21

### CodeBuild pour Tests Java 21

```yaml
# Exemple de buildspec.yml pour tests Java 21
version: 0.2

phases:
  install:
    runtime-versions:
      java: corretto21
  pre_build:
    commands:
      - echo "Setting up Maven cache"
      - pip install --upgrade awscli
  build:
    commands:
      - echo "Running tests"
      - mvn clean verify -Pintegration-test
  post_build:
    commands:
      - echo "Publishing test results"
      - aws s3 cp target/surefire-reports/ s3://accessweaver-test-reports/java/$CODEBUILD_BUILD_ID/unit/ --recursive
      - aws s3 cp target/failsafe-reports/ s3://accessweaver-test-reports/java/$CODEBUILD_BUILD_ID/integration/ --recursive

reports:
  junit-reports:
    files:
      - "target/surefire-reports/*.xml"
      - "target/failsafe-reports/*.xml"
    file-format: "JUNITXML"

cache:
  paths:
    - '/root/.m2/**/*'
```

---

## Meilleures Pratiques pour les Services AWS

### Services de Test

- **Environnements Isolés** - Utiliser des comptes AWS dédiés pour les tests
- **IAM Temporaire** - Utiliser des crédentiels éphémères pour les tests
- **Tagging Systématique** - Taguer toutes les ressources de test pour identification et nettoyage
- **Automatisation du Nettoyage** - Utiliser EventBridge et Lambda pour nettoyer les ressources de test
- **Budgets dédiés** - Configurer des alertes de coût spécifiques pour les environnements de test

### Sécurité

- **Moindre Privilège** - Rôles IAM avec permissions minimales
- **Rotation des Clés** - Rotation automatique des clés et secrets
- **Chiffrement** - Chiffrement par défaut pour toutes les données au repos et en transit
- **VPC Endpoint** - Utiliser des endpoints VPC pour les services AWS
- **Security Groups restrictifs** - N'ouvrir que les ports nécessaires

---

## Ressources et Outils Complémentaires

### Documentation Interne

- [Stratégie de Test](../reference/testing-strategy.md)
- [AWS Docs](../reference/aws-docs.md)
- [Terraform AWS](../reference/terraform.md)

### Ressources Externes

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Fault Injection Service Documentation](https://docs.aws.amazon.com/fis/)
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)