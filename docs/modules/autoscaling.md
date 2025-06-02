# 🚀 Module Autoscaling - AccessWeaver

Module transversal pour l'autoscaling intelligent de l'infrastructure AccessWeaver, garantissant performance optimale, haute disponibilité et coûts maîtrisés grâce à l'adaptation dynamique des ressources selon la charge.

## 🎯 Objectifs

### ✅ Performances Optimales
- **Scaling prédictif** basé sur les patterns historiques
- **Scaling dynamique** basé sur métriques en temps réel
- **Gestion des pics de trafic** sans dégradation de service
- **Démarrage anticipé** pour les charges prévisibles
- **Équilibrage de charge** entre services et AZs

### ✅ Haute Disponibilité
- **Répartition multi-AZ** des instances et services
- **Circuit breakers** pour protéger les ressources downstream
- **Récupération automatique** des instances défaillantes
- **Rollback automatique** en cas d'échec de déploiement
- **Maintien d'un minimum d'instances** en toutes circonstances

### ✅ Optimisation des Coûts
- **Scaling à la demande** selon les besoins réels
- **Scaling à zéro** en environnement de développement
- **Équilibre coût/performance** configurable
- **Utilisation de Spot Instances** quand approprié
- **Hibernation automatique** en périodes creuses

### ✅ Adaptabilité Multi-Services
- **ECS Service Auto Scaling** pour les microservices
- **Aurora Serverless V2** pour les bases de données
- **ElastiCache Auto Scaling** pour Redis
- **Application Auto Scaling** unifié et cohérent
- **Adaptation aux limites de ressources AWS**

## 🏗 Architecture par Environnement

### 🔧 Développement
```markdown
┌──────────────────────────────────────────────────────────────┐
│            AWS Application Auto Scaling                      │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                  ECS Services                          │  │
│  │  - Min: 1 tâche                                        │  │
│  │  - Max: 2 tâches                                       │  │
│  │  - Target: CPU 75%, Mémoire 75%                        │  │
│  │  - Scale-in: Immédiat                                  │  │
│  │  - Scheduled scaling: Désactivé                        │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                  RDS/Aurora                            │  │
│  │  - Pas d'auto-scaling (instance fixe)                  │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                  ElastiCache Redis                     │  │
│  │  - Pas d'auto-scaling (instance fixe)                  │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### 🔧 Staging (Pré-production)
```markdown
┌──────────────────────────────────────────────────────────────┐
│            AWS Application Auto Scaling                      │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                  ECS Services                          │  │
│  │  - Min: 2 tâches                                       │  │
│  │  - Max: 6 tâches                                       │  │
│  │  - Target: CPU 65%, Mémoire 65%                        │  │
│  │  - Scale-in: 10 minutes de cooldown                    │  │
│  │  - Scheduled scaling: Heures de bureau                 │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                  RDS/Aurora                            │  │
│  │  - Min: db.t3.medium                                   │  │
│  │  - Max: db.t3.large                                    │  │
│  │  - Auto scaling: CPU > 70% pendant 5 min               │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                  ElastiCache Redis                     │  │
│  │  - Réplicas: 1 fixe (pas d'auto-scaling)               │  │
│  │  - Type: cache.t3.small fixe                           │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### 🔧 Production
```markdown
┌──────────────────────────────────────────────────────────────┐
│            AWS Application Auto Scaling                      │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                  ECS Services                          │  │
│  │  - Min: 3 tâches (Multi-AZ)                            │  │
│  │  - Max: 20 tâches                                      │  │
│  │  - Target: CPU 60%, Mémoire 70%, Requests 1000         │  │
│  │  - Scale-in: 15 minutes de cooldown                    │  │
│  │  - Scheduled scaling: Jours/Heures de pointe           │  │
│  │  - Predictive scaling: Activé                          │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                  RDS/Aurora                            │  │
│  │  - Min: db.r6g.large                                   │  │
│  │  - Max: db.r6g.2xlarge                                 │  │
│  │  - Auto scaling: CPU > 65% pendant 3 min               │  │
│  │  - Répliques: 1-3 auto-scaling                         │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                  ElastiCache Redis                     │  │
│  │  - Cluster mode: 3 shards                              │  │
│  │  - Réplicas: 1-2 auto-scaling par shard                │  │
│  │  - Type: cache.r6g.large                               │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

## 🔐 Configurations d'Autoscaling

### 📊 Matrice de Scaling par Environnement

| Configuration | Dev | Staging | Prod |
|---------------|-----|---------|------|
| **ECS Min Capacity** | 1 | 2 | 3 |
| **ECS Max Capacity** | 2 | 6 | 20 |
| **CPU Target Tracking** | 75% | 65% | 60% |
| **Memory Target Tracking** | 75% | 65% | 70% |
| **Request Count Scaling** | ❌ | ❌ | ✅ |
| **Scheduled Scaling** | ❌ | ✅ | ✅ |
| **Predictive Scaling** | ❌ | ❌ | ✅ |
| **RDS Auto Scaling** | ❌ | ✅ | ✅ |
| **Redis Auto Scaling** | ❌ | ❌ | ✅ |

### 🛠️ Politiques de Scaling par Service

#### ECS Services
- **Target Tracking**: Ajustement automatique basé sur la métrique cible
- **Step Scaling**: Ajustement par paliers selon les seuils d'alarme
- **Scheduled Scaling**: Ajustement planifié pour les charges prévisibles

## 📝 Implémentation et Utilisation

### ECS Service Auto Scaling

```hcl
# Définition de la cible d'autoscaling
resource "aws_appautoscaling_target" "ecs_targets" {
  for_each = var.services

  max_capacity       = lookup(each.value, "max_capacity", lookup(local.scaling_defaults[var.environment], "max_capacity", 4))
  min_capacity       = lookup(each.value, "min_capacity", lookup(local.scaling_defaults[var.environment], "min_capacity", 1))
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.services[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Politique de scaling basée sur CPU
resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  for_each = var.services

  name               = "accessweaver-${var.environment}-${each.key}-cpu-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_targets[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_targets[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_targets[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = lookup(each.value, "cpu_target", lookup(local.scaling_defaults[var.environment], "cpu_target", 70))
    scale_in_cooldown  = lookup(each.value, "scale_in_cooldown", lookup(local.scaling_defaults[var.environment], "scale_in_cooldown", 300))
    scale_out_cooldown = lookup(each.value, "scale_out_cooldown", lookup(local.scaling_defaults[var.environment], "scale_out_cooldown", 60))
  }
}

# Politique de scaling basée sur mémoire
resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  for_each = var.services

  name               = "accessweaver-${var.environment}-${each.key}-memory-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_targets[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_targets[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_targets[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = lookup(each.value, "memory_target", lookup(local.scaling_defaults[var.environment], "memory_target", 70))
    scale_in_cooldown  = lookup(each.value, "scale_in_cooldown", lookup(local.scaling_defaults[var.environment], "scale_in_cooldown", 300))
    scale_out_cooldown = lookup(each.value, "scale_out_cooldown", lookup(local.scaling_defaults[var.environment], "scale_out_cooldown", 60))
  }
}
```

### Scheduled Scaling pour ECS

```hcl
# Scaling planifié pour les heures de bureau
resource "aws_appautoscaling_scheduled_action" "business_hours_scale_up" {
  for_each = var.environment != "prod" ? {} : var.services

  name               = "accessweaver-${var.environment}-${each.key}-business-hours-up"
  service_namespace  = aws_appautoscaling_target.ecs_targets[each.key].service_namespace
  resource_id        = aws_appautoscaling_target.ecs_targets[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_targets[each.key].scalable_dimension
  schedule           = "cron(0 8 ? * MON-FRI *)"
  
  scalable_target_action {
    min_capacity = lookup(each.value, "business_hours_min", 3)
    max_capacity = lookup(each.value, "business_hours_max", 10)
  }
}

# Scaling planifié pour les heures creuses
resource "aws_appautoscaling_scheduled_action" "off_hours_scale_down" {
  for_each = var.environment != "prod" ? {} : var.services

  name               = "accessweaver-${var.environment}-${each.key}-off-hours-down"
  service_namespace  = aws_appautoscaling_target.ecs_targets[each.key].service_namespace
  resource_id        = aws_appautoscaling_target.ecs_targets[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_targets[each.key].scalable_dimension
  schedule           = "cron(0 18 ? * MON-FRI *)"
  
  scalable_target_action {
    min_capacity = lookup(each.value, "off_hours_min", 2)
    max_capacity = lookup(each.value, "off_hours_max", 5)
  }
}
```


### Bonnes Pratiques et Recommandations
🔍 Optimisation des Politiques
 - Définir des valeurs de cooldown adaptées pour éviter les oscillations
 - Combiner plusieurs types de politiques pour différents scénarios
 - Utiliser des métriques personnalisées pour les cas spécifiques
 - Tester les politiques avec des charges simulées
⚡ Performance et Résilience
 - Configurer des health checks appropriés pour éviter le scaling sur des instances défaillantes
 - Implémenter des circuit breakers pour protéger les dépendances
 - Utiliser des stratégies de déploiement compatibles avec l'autoscaling
 - Prévoir une capacité tampon pour les pics soudains
💰 Optimisation des Coûts
 - Utiliser des instances réservées pour la capacité minimale
 - Combiner instances à la demande et Spot pour la capacité variable
Implémenter des politiques de scaling à zéro pour les environnements non-prod
Analyser régulièrement les métriques pour ajuster les seuils