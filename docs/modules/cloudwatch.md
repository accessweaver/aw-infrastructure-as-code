# Module CloudWatch Monitoring - AccessWeaver

Module transversal pour la surveillance unifiée de l'infrastructure AccessWeaver avec CloudWatch, fournissant métriques, alertes, dashboards et logs centralisés pour une observabilité complète.

## Objectifs

### Observabilité Complète
- **Monitoring unifié** de tous les composants
- **Métriques personnalisées** pour les KPIs métier
- **Logs centralisés** pour tous les services
- **Dashboards multi-service** pour vue d'ensemble
- **Alertes configurables** selon l'environnement

### Détection Proactive des Problèmes
- **Alarmes prédictives** basées sur ML
- **Détection d'anomalies** automatique
- **Corrélation de métriques** cross-service
- **Alertes multi-seuil** avec escalade progressive
- **Notifications en temps réel** par SNS/Slack

### Diagnostics et Résolution
- **Logs Insights** pour analyses avancées
- **Traces distribuées** avec X-Ray
- **Métriques haute résolution** (1s) en production
- **Rétention configurable** selon environnement
- **Exportation vers S3** pour analyses long terme

### Intégration Multi-Service
- **ECS Container Insights** pour les services
- **RDS Enhanced Monitoring** pour les bases de données
- **ElastiCache Redis Metrics** pour le cache
- **ALB Request Tracing** pour le load balancer
- **VPC Flow Logs** pour le trafic réseau

## Architecture par Environnement

### Développement
```markdown
┌──────────────────────────────────────────────────────────────┐
│                        AWS CloudWatch                       │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                    Log Groups                         │  │
│  │  - ECS Logs: Rétention 3 jours                        │  │
│  │  - RDS Logs: Rétention 1 jour                         │  │
│  │  - ALB Logs: Désactivés                               │  │
│  │  - VPC Flow Logs: Désactivés                          │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                    Alarmes                             │  │
│  │  - ECS: CPU > 80% pendant 5 min                        │  │
│  │  - RDS: CPU > 80% pendant 5 min                        │  │
│  │  - Redis: Mémoire > 80% pendant 5 min                  │  │
│  │  - Notifications: Email uniquement                     │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                    Dashboards                          │  │
│  │  - Dashboard de base par service                       │  │
│  │  - Pas de dashboard global                             │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### Staging (Pré-production)
```markdown
┌──────────────────────────────────────────────────────────────┐
│                        AWS CloudWatch                       │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                    Log Groups                         │  │
│  │  - ECS Logs: Rétention 14 jours                       │  │
│  │  - RDS Logs: Rétention 7 jours                        │  │
│  │  - ALB Logs: Rétention 7 jours                        │  │
│  │  - VPC Flow Logs: Rétention 7 jours                   │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                    Alarmes                             │  │
│  │  - ECS: CPU > 75% pendant 3 min                        │  │
│  │  - RDS: CPU > 75% pendant 3 min                        │  │
│  │  - Redis: Mémoire > 75% pendant 3 min                  │  │
│  │  - ALB: 5XX Errors > 5% pendant 3 min                  │  │
│  │  - Notifications: Email, Slack                         │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                    Dashboards                          │  │
│  │  - Dashboard détaillé par service                      │  │
│  │  - Dashboard global de l'environnement                 │  │
│  │  - Container Insights activés                          │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### Production
```markdown
┌──────────────────────────────────────────────────────────────┐
│                        AWS CloudWatch                       │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                    Log Groups                         │  │
│  │  - ECS Logs: Rétention 30 jours, export S3            │  │
│  │  - RDS Logs: Rétention 30 jours, export S3            │  │
│  │  - ALB Logs: Rétention 30 jours, export S3            │  │
│  │  - VPC Flow Logs: Rétention 30 jours, export S3       │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                    Alarmes                             │  │
│  │  - ECS: CPU > 70% pendant 2 min                        │  │
│  │  - RDS: CPU > 70% pendant 2 min                        │  │
│  │  - Redis: Mémoire > 70% pendant 2 min                  │  │
│  │  - ALB: 5XX Errors > 1% pendant 1 min                  │  │
│  │  - Latence API > 500ms pendant 2 min                   │  │
│  │  - Notifications: Email, Slack, PagerDuty              │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                    Dashboards                          │  │
│  │  - Dashboard complet par service                       │  │
│  │  - Dashboard global avec KPIs                          │  │
│  │  - Dashboard business metrics                          │  │
│  │  - Container Insights + X-Ray                          │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

## Configuration et Métriques

### Matrice de Monitoring par Service

| Service | Logs | Métriques | Alertes | Dashboards |
|---------|------|-----------|---------|------------|
| **ECS Services** | Logs de conteneur | CPU, Mémoire, Tâches | CPU, Mémoire, Erreurs | Par service + Global |
| **RDS Database** | Error, Slow Query | CPU, Mémoire, IO, Connexions | CPU, Storage, Replica Lag | Database Performance |
| **Redis Cache** | Slow Log | CPU, Mémoire, Hit/Miss | Evictions, Memory, CPU | Cache Performance |
| **ALB** | Access Logs | Requests, Latence, Erreurs | 5XX, 4XX, Latence | Traffic & Errors |
| **VPC** | Flow Logs | Traffic | Rejected Connections | Network Dashboard |

### Métriques personnalisées par module

#### ECS Services
- `AccessWeaver/api/RequestCount` - Nombre de requêtes API par endpoint
- `AccessWeaver/api/ResponseTime` - Temps de réponse par endpoint
- `AccessWeaver/api/ErrorRate` - Taux d'erreur par endpoint
- `AccessWeaver/authorization/DecisionTime` - Temps de décision d'autorisation
- `AccessWeaver/authorization/CacheHitRatio` - Taux de cache hit pour les décisions

#### RDS Database
- `AccessWeaver/database/QueryCount` - Nombre de requêtes par type
- `AccessWeaver/database/SlowQueryCount` - Nombre de requêtes lentes
- `AccessWeaver/database/RowsProcessed` - Nombre de lignes traitées
- `AccessWeaver/database/TenantQueryCount` - Requêtes par tenant

#### Redis Cache
- `AccessWeaver/cache/CommandLatency` - Latence par commande Redis
- `AccessWeaver/cache/EvictionCount` - Nombre d'évictions par type
- `AccessWeaver/cache/KeyspaceHits` - Hits de cache par tenant
- `AccessWeaver/cache/UsedMemory` - Mémoire utilisée par tenant

## Implémentation et Utilisation

### CloudWatch Log Groups

Les Log Groups sont créés dans chaque module correspondant:

```hcl
# Exemple d'alarme CPU pour RDS
resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "accessweaver-${var.environment}-rds-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = lookup(local.alarm_thresholds[var.environment], "cpu_threshold", 80)
  alarm_description   = "Alarme de haute utilisation CPU pour la base de données AccessWeaver"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : []
  
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.id
  }
  
  tags = {
    Environment = var.environment
    Project     = "AccessWeaver"
  }
}
```

### Dashboards CloudWatch

```hcl
# Exemple de dashboard pour un service ECS
resource "aws_cloudwatch_dashboard" "service_dashboard" {
  dashboard_name = "accessweaver-${var.environment}-${each.key}-dashboard"
  
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
            ["AWS/ECS", "CPUUtilization", "ServiceName", each.key, "ClusterName", aws_ecs_cluster.this.name]
          ]
          period = 60
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "CPU Utilization"
        }
      },
      # ... autres widgets
    ]
  })
}
```

### Bonnes Pratiques et Recommandations
 Observabilité Avancée
 - Centraliser les logs dans un service comme Elasticsearch/OpenSearch pour des analyses avancées
 - Implémenter OpenTelemetry pour la collecte de métriques et traces standardisées
 - Utiliser des métriques haute résolution (1s) pour les services critiques
 - Implémenter une corrélation entre logs, métriques et traces
 Performance et Coûts
 - Filtrer les logs inutiles avant de les envoyer à CloudWatch
 - Utiliser des politiques de rétention adaptées à chaque type de log
 - Considérer l'exportation vers S3 pour l'archivage à long terme
 - Utiliser des métriques agrégées pour les dashboards de haut niveau
 Alertes Efficaces
 - Éviter le "alert fatigue" en définissant des seuils pertinents
 - Implémenter des alertes composites (plusieurs conditions)
 - Utiliser des périodes d'évaluation adaptées à la métrique
 - Définir clairement les procédures d'escalade pour chaque type d'alerte