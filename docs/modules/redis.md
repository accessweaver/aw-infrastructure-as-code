# 🚀 Module Redis ElastiCache - AccessWeaver

Module Terraform pour le cache distribué haute performance d'AccessWeaver sur AWS ElastiCache Redis avec configuration adaptative, sécurité enterprise et intégration native aux microservices.

## 🎯 Objectifs

### ✅ Cache Distribué Haute Performance
- **Cache décisions d'autorisation** (<1ms de latence)
- **Support multi-tenancy** avec namespacing automatique
- **Configuration adaptative** selon l'environnement (dev/staging/prod)
- **Sécurité enterprise** avec chiffrement et authentification

### ✅ Production-Ready dès le MVP
- **Single node économique** en dev
- **Replication groups** en staging pour tester la HA
- **Cluster mode avec sharding** en prod pour performance
- **Multi-AZ déployment** pour haute disponibilité

### ✅ Sécurité Enterprise
- **Chiffrement en transit (TLS)** activé par défaut
- **Chiffrement au repos** pour toutes les données
- **Authentification par token** sécurisé
- **Déploiement en subnets privés** uniquement
- **Security groups restrictifs** pour accès limité

### ✅ Intégration AccessWeaver
- **Configuration Spring Boot** générée automatiquement
- **Cache L2** pour les décisions RBAC/ABAC/ReBAC
- **Session storage** pour les tokens JWT
- **Rate limiting** par tenant
- **Pub/Sub** pour invalidation de cache cross-services

## 🏗 Architecture par Environnement

### 🔧 Développement
```
┌─────────────────────────────────────────────────────────┐
│                   AWS ElastiCache                       │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Redis Single Node (cache.t3.micro)             │   │
│  │  - 1 instance (non HA)                          │   │
│  │  - Authentification activée                     │   │
│  │  - Chiffrement activé                           │   │
│  │  - 1 jour de rétention snapshot                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 🔧 Staging (Pré-production)
```
┌─────────────────────────────────────────────────────────┐
│                   AWS ElastiCache                       │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Redis Replication Group (cache.t3.small)       │   │
│  │  - 1 nœud primaire + 1 réplica                  │   │
│  │  - Multi-AZ activé                              │   │
│  │  - Automatic Failover activé                    │   │
│  │  - Authentification + Chiffrement               │   │
│  │  - 5 jours de rétention snapshot                │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 🔧 Production
```
┌─────────────────────────────────────────────────────────┐
│                   AWS ElastiCache                       │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Redis Cluster Mode (cache.r6g.large)           │   │
│  │  - 3 shards (node groups)                       │   │
│  │  - 2 réplicas par shard                         │   │
│  │  - Total: 9 nœuds (3 primaires + 6 réplicas)    │   │
│  │  - Multi-AZ + Auto Failover                     │   │
│  │  - Authentification + Chiffrement               │   │
│  │  - 7 jours de rétention snapshot                │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## 🔐 Configurations de Sécurité

### 📊 Matrice de Sécurité

| Feature | Dev | Staging | Prod |
|---------|-----|---------|------|
| **Chiffrement en transit (TLS)** | ✅ | ✅ | ✅ |
| **Chiffrement au repos** | ✅ | ✅ | ✅ |
| **Authentification par token** | ✅ | ✅ | ✅ |
| **Déploiement en subnets privés** | ✅ | ✅ | ✅ |
| **Security groups restrictifs** | ✅ | ✅ | ✅ |
| **Multi-AZ** | ❌ | ✅ | ✅ |
| **Automatic Failover** | ❌ | ✅ | ✅ |

### 🔒 Best Practices Implémentées

- **Token Auth généré automatiquement** (64 caractères, forte complexité)
- **Restriction d'accès réseau** via security groups (services ECS uniquement)
- **Paramètres ElastiCache sécurisés** (désactivation des commandes dangereuses)
- **Maintenance automatique** dans des fenêtres planifiées (heures creuses)
- **Rotation des données sensibles** supportée via paramètres variables

## 📝 Configuration et Utilisation

### 📋 Variables Requises

| Variable | Description | Type | Validation |
|----------|-------------|------|------------|
| `project_name` | Nom du projet (accessweaver) | `string` | Lettres minuscules, chiffres, tirets |
| `environment` | Environnement (`dev`, `staging`, `prod`) | `string` | Valeurs strictes |
| `vpc_id` | ID du VPC où déployer Redis | `string` | Format AWS vpc-* |
| `private_subnet_ids` | Liste des IDs des subnets privés | `list(string)` | Min 2 subnets |
| `allowed_security_groups` | SGs autorisés à accéder à Redis | `list(string)` | Format AWS sg-* |

### 📋 Variables Optionnelles (Avec Defaults)

| Variable | Description | Type | Default |
|----------|-------------|------|----------|
| `auth_token` | Token d'authentification Redis | `string` | Généré automatiquement |
| `redis_port` | Port d'écoute Redis | `number` | `6379` |
| `enable_monitoring` | Activer CloudWatch enhanced | `bool` | `true` en prod, `false` en dev |
| `maintenance_window` | Fenêtre de maintenance | `string` | Adaptée à l'environnement |
| `snapshot_window` | Fenêtre de snapshot | `string` | Adaptée à l'environnement |

### 📤 Outputs Principaux

| Output | Description | Exemple |
|--------|-------------|----------|
| `cluster_id` | ID du cluster Redis | `accessweaver-prod-redis` |
| `primary_endpoint` | Endpoint d'écriture (et lecture) | `accessweaver-prod-redis.abc123.cache.amazonaws.com:6379` |
| `reader_endpoint` | Endpoint de lecture (staging/prod) | `accessweaver-prod-redis-ro.abc123.cache.amazonaws.com:6379` |
| `auth_token` | Token d'authentification | `<valeur sensible>` |
| `application_yml_redis_config` | Configuration Spring Boot prête à l'emploi | `<bloc YAML>` |

## 🧩 Exemples d'Utilisation

### 📦 Module de Base (dev)

```hcl
module "redis" {
  source = "./modules/redis"

  project_name           = "accessweaver"
  environment            = "dev"
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  allowed_security_groups = [module.ecs.security_group_id]
}
```

### 📦 Staging avec Variables Personnalisées

```hcl
module "redis" {
  source = "./modules/redis"

  project_name            = "accessweaver"
  environment             = "staging"
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  allowed_security_groups = [module.ecs.security_group_id]
  
  # Overrides optionnels
  redis_port              = 6380
  maintenance_window      = "mon:03:00-mon:05:00"
  enable_monitoring       = true
}
```

### 📦 Production Complète

```hcl
module "redis" {
  source = "./modules/redis"

  project_name            = "accessweaver"
  environment             = "prod"
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  allowed_security_groups = [module.ecs.security_group_id]
  
  # Paramètres avancés
  enable_monitoring       = true
  apply_immediately       = false
  enable_backup_target    = true
  create_cloudwatch_alarms = true
  notification_topic_arn  = aws_sns_topic.alerts.arn
}
```

## 🔄 Intégration avec AccessWeaver

### 🔧 Configuration Spring Boot Automatique

Le module génère une configuration Spring Boot complète pour Redis:

```yaml
spring:
  redis:
    host: accessweaver-prod-redis.abc123.cache.amazonaws.com
    port: 6379
    ssl: true
    username: default  # Requis pour Redis 6+
    password: ${REDIS_AUTH_TOKEN}
    timeout: 2000
    connect-timeout: 2000
    client-type: lettuce
    lettuce:
      pool:
        max-active: 8
        max-idle: 8
        min-idle: 2
        max-wait: 1000
```

### 🔑 Utilisation des Secrets

Variable d'environnement dans le service ECS:

```hcl
environment = [
  {
    name  = "REDIS_AUTH_TOKEN"
    value = module.redis.auth_token
  }
]
```

### 🔄 Invalidation de Cache Cross-Services

Pattern d'utilisation pour l'invalidation cross-services:

```java
@Service
public class RedisCacheInvalidator {
    @Autowired
    private StringRedisTemplate redisTemplate;
    
    public void invalidatePermissionCache(String tenantId, String principalId) {
        String channel = "accessweaver:invalidate:" + tenantId;
        String message = "{\"type\":\"permission\",\"principalId\":\"" + principalId + "\"}";
        redisTemplate.convertAndSend(channel, message);
    }
}
```

## 📊 Monitoring et Alertes

### 📈 Métriques Disponibles

| Métrique | Description | Seuil d'Alerte |
|----------|-------------|----------------|
| `CPUUtilization` | Utilisation CPU | >80% pendant 5min |
| `DatabaseMemoryUsagePercentage` | Utilisation mémoire | >75% pendant 5min |
| `CurrConnections` | Connexions actives | >90% de la limite |
| `SwapUsage` | Utilisation du swap | >0 pendant 10min |
| `ReplicationLag` | Latence de réplication | >500ms pendant 5min |
| `CacheMisses` | Ratio de cache miss | >30% pendant 15min |

### 🚨 Alertes CloudWatch

Exemple de définition d'alertes:

```hcl
resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Redis CPU utilization is too high"
  alarm_actions       = [var.notification_topic_arn]
  dimensions = {
    CacheClusterId = module.redis.cluster_id
  }
}
```

## 📚 Notes d'Implémentation

### 🔄 Mise à Jour Redis

- Les mises à jour respectent les fenêtres de maintenance définies
- Option `apply_immediately` pour les mises à jour critiques
- Snapshots automatiques avant modifications majeures

### 🔍 Troubleshooting

- Accès aux logs via CloudWatch Logs
- Commandes Redis CLI via AWS Console
- Support des profils Redis pour analyse de performances

### 🔄 Migration de Données

- Support de snapshots pour migration entre environnements
- Restauration à partir de snapshots pour recréation

## 📏 Limitations

- Maximum 500 connexions simultanées par nœud (limite AWS)
- Maximum 1000 bases par cluster (limite Redis)
- 64MB taille max de clé (Redis 7.0)
- Opérations bloquantes désactivées (CONFIG, SAVE)