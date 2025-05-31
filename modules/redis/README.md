# ⚡ Module Redis ElastiCache - AccessWeaver

Module Terraform optimisé pour déployer Redis ElastiCache sur AWS avec configuration adaptive selon l'environnement et optimisations spécifiques pour AccessWeaver.

## 🎯 Objectifs

### ✅ Cache Ultra-Rapide pour Autorisations
- **Latence <1ms** pour les décisions d'autorisation RBAC
- **Support multi-tenancy** avec namespacing automatique
- **Cache L2 distribué** pour les moteurs RBAC/ABAC/ReBAC
- **Pub/Sub** pour invalidation cross-services

### ✅ Configuration Adaptive par Environnement
- **Dev** : Single node économique (cache.t3.micro) ~$13/mois
- **Staging** : Replication group avec HA (cache.t3.small) ~$50/mois
- **Prod** : Cluster mode avec sharding (cache.r6g.large) ~$200/mois

### ✅ Sécurité Enterprise
- **Chiffrement at-rest et in-transit** par défaut
- **Authentification par token** obligatoire
- **Déploiement subnets privés** uniquement
- **Security groups** restrictifs

### ✅ Monitoring Proactif
- **CloudWatch alarms** pour CPU, mémoire, hit ratio
- **Slow query logging** pour optimisation
- **Health checks** intégrés
- **Cost tracking** avec tags automatiques

## 🏗 Architecture par Environnement

### 🔧 Développement
```
┌─────────────────────────────────────────┐
│             ECS Services                │
└─────────────────┬───────────────────────┘
                  │ Port 6379 + AUTH
┌─────────────────▼───────────────────────┐
│          Single Redis Node              │
│        cache.t3.micro (0.5GB)          │
│         Single AZ (eu-west-1a)          │
│                                         │
│  Features:                              │
│  ✅ AUTH token                          │
│  ✅ Encryption at-rest/transit          │
│  ✅ 1 jour backup                       │
│  ❌ Multi-AZ                            │
│  ❌ Read replicas                       │
│                                         │
│  Coût: ~$13/mois                        │
└─────────────────────────────────────────┘
```

### 🎭 Staging
```
┌─────────────────────────────────────────┐
│             ECS Services                │
└─────────────────┬───────────────────────┘
                  │ Port 6379 + AUTH
┌─────────────────▼───────────────────────┐
│         Redis Replication Group         │
│                                         │
│  ┌─────────────┐    ┌─────────────┐     │
│  │   Master    │    │   Replica   │     │
│  │cache.t3.small│    │cache.t3.small│     │
│  │ eu-west-1a  │    │ eu-west-1b  │     │
│  │  (Write)    │────┤  (Read)     │     │
│  └─────────────┘    └─────────────┘     │
│                                         │
│  Features:                              │
│  ✅ Multi-AZ                            │
│  ✅ Automatic failover                  │
│  ✅ Read/Write split                    │
│  ✅ 5 jours backup                      │
│                                         │
│  Coût: ~$50/mois                        │
└─────────────────────────────────────────┘
```

### 🚀 Production
```
┌─────────────────────────────────────────┐
│             ECS Services                │
└─────────────────┬───────────────────────┘
                  │ Port 6379 + AUTH
┌─────────────────▼───────────────────────┐
│          Redis Cluster Mode             │
│                                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│  │   Shard 1   │ │   Shard 2   │ │   Shard 3   │
│  │             │ │             │ │             │
│  │ ┌─────────┐ │ │ ┌─────────┐ │ │ ┌─────────┐ │
│  │ │ Master  │ │ │ │ Master  │ │ │ │ Master  │ │
│  │ │r6g.large│ │ │ │r6g.large│ │ │ │r6g.large│ │
│  │ └─────────┘ │ │ └─────────┘ │ │ └─────────┘ │
│  │ ┌─────────┐ │ │ ┌─────────┐ │ │ ┌─────────┐ │
│  │ │Replica 1│ │ │ │Replica 1│ │ │ │Replica 1│ │
│  │ └─────────┘ │ │ └─────────┘ │ │ └─────────┘ │
│  │ ┌─────────┐ │ │ ┌─────────┐ │ │ ┌─────────┐ │
│  │ │Replica 2│ │ │ │Replica 2│ │ │ │Replica 2│ │
│  │ └─────────┘ │ │ └─────────┘ │ │ └─────────┘ │
│  └─────────────┘ └─────────────┘ └─────────────┘
│                                         │
│  Features:                              │
│  ✅ Sharding automatique                │
│  ✅ 100k+ ops/sec                       │
│  ✅ Haute disponibilité                 │
│  ✅ Performance Insights                │
│  ✅ Enhanced Monitoring                 │
│                                         │
│  Coût: ~$200/mois                       │
└─────────────────────────────────────────┘
```

## 🚀 Utilisation

### Configuration de base (Dev)

```hcl
module "redis" {
  source = "../../modules/redis"
  
  # Configuration obligatoire
  project_name             = "accessweaver"
  environment             = "dev"
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  allowed_security_groups = [module.ecs.security_group_id]
}
```

### Configuration avancée (Production)

```hcl
module "redis" {
  source = "../../modules/redis"
  
  # Configuration de base
  project_name             = "accessweaver"
  environment             = "prod"
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  allowed_security_groups = [
    module.ecs.security_group_id,
    module.monitoring.security_group_id
  ]
  
  # Optimisations pour AccessWeaver
  custom_parameters = [
    {
      name  = "maxmemory-policy"
      value = "allkeys-lru"  # Éviction intelligente pour cache permissions
    },
    {
      name  = "timeout"
      value = "300"          # Nettoyage connexions inactives
    },
    {
      name  = "notify-keyspace-events"
      value = "Ex"           # Notifications d'expiration pour metrics
    }
  ]
  
  # Monitoring avancé
  sns_topic_arn            = aws_sns_topic.alerts.arn
  enable_slow_log          = false  # Performance en prod
  
  # Fenêtres de maintenance coordonnées avec RDS
  maintenance_window       = "sun:05:00-sun:06:00"
  snapshot_window          = "03:00-05:00"
  snapshot_retention_limit = 7
  
  # Tags pour cost management
  additional_tags = {
    CostCenter   = "Engineering"
    Owner        = "Platform Team"
    BusinessUnit = "Product"
    Compliance   = "GDPR"
  }
}
```

## 📊 Comparaison des Configurations

| Paramètre | Dev | Staging | Production |
|-----------|-----|---------|------------|
| **Instance Type** | cache.t3.micro | cache.t3.small | cache.r6g.large |
| **RAM** | 0.5 GB | 1.37 GB | 12.32 GB |
| **Nombre de Nodes** | 1 | 2 (master+replica) | 9 (3 shards × 3) |
| **Performance** | 1k ops/sec | 10k ops/sec | 100k+ ops/sec |
| **Multi-AZ** | ❌ | ✅ | ✅ |
| **Cluster Mode** | ❌ | ❌ | ✅ |
| **Backup Retention** | 1 jour | 5 jours | 7 jours |
| **Enhanced Monitoring** | ❌ | ❌ | ✅ |
| **Coût estimé/mois** | ~$13 | ~$50 | ~$200 |

## 🔌 Intégration Spring Boot

### Configuration automatique

Le module génère automatiquement la configuration Spring Boot complète :

```bash
# Récupérer la configuration générée
terraform output application_yml_redis_config
```

### Configuration application.yml

```yaml
# Configuration générée automatiquement par le module
spring:
  redis:
    # Master (écriture)
    host: accessweaver-prod-redis.abc123.cache.amazonaws.com
    port: 6379
    password: ${REDIS_AUTH_TOKEN}
    database: 0
    timeout: 30s
    ssl: true
    
    lettuce:
      pool:
        max-active: 20
        max-idle: 10
        min-idle: 5
        max-wait: 10s
      shutdown-timeout: 5s
      cluster:
        refresh:
          adaptive: true
          period: 30s
    
    # Replica (lecture) - si disponible
    replica:
      host: accessweaver-prod-redis-replica.abc123.cache.amazonaws.com
      port: 6379
      password: ${REDIS_AUTH_TOKEN}
      database: 0

  cache:
    type: redis
    redis:
      time-to-live: 300000  # 5 minutes
      cache-null-values: false
      use-key-prefix: true
      key-prefix: "aw:prod:"

# Configuration AccessWeaver spécifique
accessweaver:
  cache:
    redis:
      enabled: true
      key-patterns:
        permissions: "permissions:tenant:{tenantId}:user:{userId}"
        roles: "roles:tenant:{tenantId}:user:{userId}"
        policies: "policies:tenant:{tenantId}:resource:{resourceId}"
        sessions: "sessions:tenant:{tenantId}:token:{tokenId}"
      
      ttl:
        permissions: 300    # 5 minutes
        roles: 600         # 10 minutes
        policies: 1800     # 30 minutes
        sessions: 3600     # 1 heure
```

### Configuration Java Multi-DataSource

```java
@Configuration
@EnableCaching
public class RedisConfig {
    
    @Primary
    @Bean(name = "redisTemplate")
    public RedisTemplate<String, Object> redisTemplate(
            @Qualifier("redisConnectionFactory") RedisConnectionFactory connectionFactory) {
        RedisTemplate<String, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(connectionFactory);
        
        // Serialization optimisée pour AccessWeaver
        template.setKeySerializer(new StringRedisSerializer());
        template.setValueSerializer(new GenericJackson2JsonRedisSerializer());
        template.setHashKeySerializer(new StringRedisSerializer());
        template.setHashValueSerializer(new GenericJackson2JsonRedisSerializer());
        
        return template;
    }
    
    @Bean(name = "redisConnectionFactory")
    @Primary
    public LettuceConnectionFactory redisConnectionFactory() {
        return new LettuceConnectionFactory(
            new RedisStandaloneConfiguration("${redis.host}", ${redis.port})
        );
    }
    
    // Configuration replica pour lecture
    @Bean(name = "redisReplicaTemplate")
    @ConditionalOnProperty("spring.redis.replica.host")
    public RedisTemplate<String, Object> redisReplicaTemplate(
            @Qualifier("redisReplicaConnectionFactory") RedisConnectionFactory connectionFactory) {
        RedisTemplate<String, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(connectionFactory);
        // Configuration read-only
        return template;
    }
}
```

## 🛡 Patterns AccessWeaver Optimisés

### 1. Cache de Permissions Multi-Tenant

```java
@Service
public class PermissionCacheService {
    
    private final RedisTemplate<String, Object> redisTemplate;
    
    // Pattern de clé multi-tenant
    private String buildKey(String tenantId, String userId, String resource) {
        return String.format("permissions:tenant:%s:user:%s:resource:%s", 
                           tenantId, userId, resource);
    }
    
    public boolean hasPermission(String tenantId, String userId, String resource, String action) {
        String key = buildKey(tenantId, userId, resource);
        
        // Check cache L2
        Set<String> permissions = (Set<String>) redisTemplate.opsForValue().get(key);
        
        if (permissions == null) {
            // Cache miss - récupérer depuis DB et cacher
            permissions = loadPermissionsFromDB(tenantId, userId, resource);
            redisTemplate.opsForValue().set(key, permissions, Duration.ofMinutes(5));
        }
        
        return permissions.contains(action);
    }
    
    // Invalidation ciblée lors d'un changement de policy
    public void invalidateUserPermissions(String tenantId, String userId) {
        String pattern = String.format("permissions:tenant:%s:user:%s:*", tenantId, userId);
        
        // Scan et delete (attention en prod - utiliser pipeline)
        Set<String> keys = redisTemplate.keys(pattern);
        if (!keys.isEmpty()) {
            redisTemplate.delete(keys);
        }
        
        // Pub/Sub pour notifier les autres instances
        redisTemplate.convertAndSend("aw:cache-invalidation", 
            Map.of("type", "user-permissions", "tenantId", tenantId, "userId", userId));
    }
}
```

### 2. Cache de Sessions JWT

```java
@Service
public class JWTCacheService {
    
    private final RedisTemplate<String, Object> redisTemplate;
    
    public void cacheToken(String tenantId, String tokenId, JWTClaims claims) {
        String key = String.format("sessions:tenant:%s:token:%s", tenantId, tokenId);
        
        // Cache avec TTL basé sur l'expiration du token
        Duration ttl = Duration.between(Instant.now(), claims.getExpiration());
        redisTemplate.opsForValue().set(key, claims, ttl);
    }
    
    public Optional<JWTClaims> getTokenClaims(String tenantId, String tokenId) {
        String key = String.format("sessions:tenant:%s:token:%s", tenantId, tokenId);
        JWTClaims claims = (JWTClaims) redisTemplate.opsForValue().get(key);
        return Optional.ofNullable(claims);
    }
    
    public void blacklistToken(String tenantId, String tokenId) {
        String key = String.format("sessions:tenant:%s:token:%s", tenantId, tokenId);
        redisTemplate.delete(key);
        
        // Ajouter à la blacklist pour sécurité
        String blacklistKey = String.format("blacklist:tenant:%s:token:%s", tenantId, tokenId);
        redisTemplate.opsForValue().set(blacklistKey, true, Duration.ofHours(24));
    }
}
```

### 3. Rate Limiting par Tenant

```java
@Component
public class TenantRateLimiter {
    
    private final RedisTemplate<String, Object> redisTemplate;
    
    public boolean isAllowed(String tenantId, String operation, int limit, Duration window) {
        String key = String.format("ratelimit:tenant:%s:op:%s", tenantId, operation);
        
        // Sliding window avec Redis sorted sets
        long now = System.currentTimeMillis();
        long windowStart = now - window.toMillis();
        
        // Pipeline pour atomicité
        redisTemplate.execute(new SessionCallback<List<Object>>() {
            @Override
            public List<Object> execute(RedisOperations operations) throws DataAccessException {
                operations.multi();
                
                // Nettoyer les entrées expirées
                operations.opsForZSet().removeRangeByScore(key, 0, windowStart);
                
                // Compter les requêtes dans la fenêtre
                Long count = operations.opsForZSet().count(key, windowStart, now);
                
                if (count < limit) {
                    // Ajouter la requête actuelle
                    operations.opsForZSet().add(key, UUID.randomUUID().toString(), now);
                    operations.expire(key, window);
                }
                
                return operations.exec();
            }
        });
        
        Long currentCount = redisTemplate.opsForZSet().count(key, windowStart, now);
        return currentCount <= limit;
    }
}
```

## 📈 Monitoring & Alertes

### CloudWatch Alarms Incluses

1. **CPU Utilization > 75%**
    - Indicateur de charge élevée
    - Peut nécessiter un scaling

2. **Memory Usage > 80%**
    - Risque d'éviction de cache
    - Optimiser les TTL ou scaler

3. **Cache Hit Ratio < 80%**
    - Performance dégradée
    - Revoir la stratégie de cache

4. **Connection Count Élevé**
    - Possible fuite de connexions
    - Vérifier les pools d'applications

### Métriques Custom AccessWeaver

```java
@Component
public class RedisMetrics {
    
    private final MeterRegistry meterRegistry;
    private final RedisTemplate<String, Object> redisTemplate;
    
    @EventListener
    @Async
    public void onPermissionCacheHit(PermissionCacheEvent event) {
        Counter.builder("accessweaver.cache.permissions")
            .tag("tenant", event.getTenantId())
            .tag("result", event.isHit() ? "hit" : "miss")
            .register(meterRegistry)
            .increment();
    }
    
    @Scheduled(fixedDelay = 60000) // Chaque minute
    public void collectRedisStats() {
        try {
            Properties info = redisTemplate.getRequiredConnectionFactory()
                .getConnection().info("memory");
                
            String usedMemory = info.getProperty("used_memory");
            String maxMemory = info.getProperty("maxmemory");
            
            if (usedMemory != null && maxMemory != null) {
                double usage = Double.parseDouble(usedMemory) / Double.parseDouble(maxMemory);
                
                Gauge.builder("accessweaver.redis.memory.usage.ratio")
                    .register(meterRegistry, () -> usage);
            }
        } catch (Exception e) {
            log.warn("Failed to collect Redis metrics", e);
        }
    }
}
```

## 💰 Optimisation des Coûts

### Reserved Instances

```bash
# Calculer les économies potentielles
aws elasticache describe-reserved-cache-nodes-offerings \
  --cache-node-type cache.r6g.large \
  --duration "1 year" \
  --offering-type "All Upfront"

# Acheter une Reserved Instance (exemple)
aws elasticache purchase-reserved-cache-nodes-offering \
  --reserved-cache-nodes-offering-id 8ba30be1-b9ec-447d-9993-dadb0123456 \
  --cache-node-count 3
```

### Stratégies d'économies

| Stratégie | Économies | Effort | Recommandation |
|-----------|-----------|--------|----------------|
| **Reserved Instances 1 an** | 30-40% | Faible | ✅ Prod uniquement |
| **Reserved Instances 3 ans** | 50-60% | Faible | ✅ Prod stable |
| **Right-sizing instances** | 20-30% | Moyen | ✅ Monitoring requis |
| **Optimisation TTL** | 10-20% | Élevé | ✅ Cache hit ratio |
| **Cleanup snapshots** | 5-10% | Faible | ✅ Automatisation |

### Monitoring des coûts

```hcl
# Ajout d'alerting coût
resource "aws_budgets_budget" "redis_cost" {
  name         = "accessweaver-redis-budget"
  budget_type  = "COST"
  limit_amount = "300"  # $300/mois
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  cost_filters {
    tag = {
      "Service" = ["accessweaver-redis"]
    }
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80  # 80% du budget
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = ["admin@accessweaver.com"]
  }
}
```

## 🔧 Variables du Module

### Variables Obligatoires

| Variable | Type | Description |
|----------|------|-------------|
| `project_name` | string | Nom du projet (ex: "accessweaver") |
| `environment` | string | Environnement (dev/staging/prod) |
| `vpc_id` | string | ID du VPC de déploiement |
| `private_subnet_ids` | list(string) | IDs des subnets privés (≥2) |
| `allowed_security_groups` | list(string) | Security groups autorisés |

### Variables Optionnelles Importantes

| Variable | Type | Défaut | Description |
|----------|------|--------|-------------|
| `auth_token` | string | null (généré) | Token d'authentification Redis |
| `node_type_override` | string | null | Override type d'instance |
| `custom_parameters` | list(object) | [] | Paramètres Redis personnalisés |
| `sns_topic_arn` | string | null | Topic SNS pour alertes |
| `enable_slow_log` | bool | false | Activation slow query log |
| `maintenance_window` | string | null | Fenêtre de maintenance |
| `additional_tags` | map(string) | {} | Tags supplémentaires |

## 📤 Outputs du Module

### Outputs Essentiels

| Output | Description |
|--------|-------------|
| `primary_endpoint` | Endpoint principal pour écritures |
| `reader_endpoint` | Endpoint pour lectures (si replica) |
| `auth_token_enabled` | Status authentification |
| `spring_redis_config` | Config Spring Boot prête |
| `docker_environment_variables` | Variables Docker |

### Outputs pour Monitoring

| Output | Description |
|--------|-------------|
| `cloudwatch_alarms_arns` | ARNs des alarmes créées |
| `estimated_monthly_cost` | Estimation coûts AWS |
| `debugging_information` | Commandes de debug |
| `health_check_endpoints` | Endpoints pour health checks |

## 🛠 Troubleshooting

### Problèmes Courants

#### 1. Connexion Refusée

```bash
# Vérifier les security groups
aws ec2 describe-security-groups --group-ids sg-xxx

# Tester depuis une instance ECS
redis-cli -h your-endpoint -p 6379 -a your-token ping
```

#### 2. Performance Dégradée

```bash
# Vérifier les métriques
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name CPUUtilization \
  --dimensions Name=CacheClusterId,Value=your-cluster \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Average

# Analyser les slow queries
redis-cli -h your-endpoint -p 6379 -a your-token slowlog get 10
```

#### 3. Cache Hit Ratio Faible

```bash
# Statistiques détaillées
redis-cli -h your-endpoint -p 6379 -a your-token info stats

# Analyser les patterns de clés
redis-cli -h your-endpoint -p 6379 -a your-token --scan --pattern "permissions:*" | head -20
```

### Scripts de Maintenance

```bash
#!/bin/bash
# backup-redis.sh - Snapshot manuel

CLUSTER_ID="accessweaver-prod-redis-001"
SNAPSHOT_NAME="manual-backup-$(date +%Y%m%d-%H%M)"

aws elasticache create-snapshot \
  --cache-cluster-id $CLUSTER_ID \
  --snapshot-name $SNAPSHOT_NAME

echo "Snapshot créé: $SNAPSHOT_NAME"
```

## 📚 Ressources

### Documentation Technique
- [Redis 7.0 Commands](https://redis.io/commands/)
- [AWS ElastiCache Best Practices](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/BestPractices.html)
- [Spring Data Redis Reference](https://docs.spring.io/spring-data/redis/docs/current/reference/html/)

### Tools Recommandés
- [RedisInsight](https://redis.com/redis-enterprise/redis-insight/) - GUI pour Redis
- [redis-cli](https://redis.io/topics/rediscli) - Client ligne de commande
- [Another Redis Desktop Manager](https://github.com/qishibo/AnotherRedisDesktopManager) - Client desktop

### Monitoring & Observabilité
- [Redis Monitoring Guide](https://redis.io/topics/admin#redis-cli)
- [CloudWatch Redis Metrics](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/CacheMetrics.Redis.html)
- [Grafana Redis Dashboard](https://grafana.com/grafana/dashboards/763)

---

**⚠️ Note importante :** Ce module crée des ressources AWS facturées. Consultez les estimations de coût avant déploiement et configurez des budgets appropriés.