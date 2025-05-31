# =============================================================================
# AccessWeaver Redis Module - Outputs
# =============================================================================
# Outputs complets pour l'intégration Redis dans AccessWeaver
#
# ORGANISATION:
# 1. Informations de connexion principales
# 2. Configuration cluster et nodes
# 3. Sécurité et authentification
# 4. Monitoring et maintenance
# 5. Configuration Spring Boot ready-to-use
# 6. Docker et infrastructure
# 7. Coûts et optimisation
# 8. Debugging et troubleshooting
#
# USAGE:
# Ces outputs sont conçus pour être directement utilisables dans:
# - Configuration Spring Boot (application.yml)
# - Variables d'environnement Docker
# - Scripts de monitoring
# - Documentation automatique
# =============================================================================

# =============================================================================
# 1. INFORMATIONS DE CONNEXION PRINCIPALES
# =============================================================================

output "cluster_id" {
  description = <<-EOT
    Identifiant unique du cluster Redis ElastiCache.

    Utilisé pour:
    - Références dans d'autres ressources Terraform
    - Commandes AWS CLI
    - Monitoring CloudWatch
    - Scripts d'administration

    Exemple: "accessweaver-prod-redis"
  EOT
  value = aws_elasticache_replication_group.main.replication_group_id
}

output "primary_endpoint" {
  description = <<-EOT
    Endpoint principal pour les opérations d'écriture Redis.

    Format: hostname:port
    Exemple: "accessweaver-prod-redis.abc123.cache.amazonaws.com:6379"

    Utilisation:
    - Toutes les opérations d'écriture (SET, DEL, etc.)
    - Opérations de lecture si pas de read replicas
    - Configuration master dans les applications

    Note: En cluster mode, cet endpoint route automatiquement
    vers le bon shard selon la clé.
  EOT
  value = "${aws_elasticache_replication_group.main.configuration_endpoint_address != null ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address}:${local.current_config.port}"
}

output "reader_endpoint" {
  description = <<-EOT
    Endpoint pour les opérations de lecture seule (si disponible).

    Disponible uniquement avec read replicas (staging/prod).

    Utilisation recommandée pour AccessWeaver:
    - Lecture des permissions en cache (GET, HGET)
    - Vérifications d'existence (EXISTS)
    - Opérations analytiques (SCAN avec READONLY)

    Avantages:
    - Répartition de charge entre master et replicas
    - Performances améliorées pour les lectures
    - Résilience en cas de problème sur le master

    Note: Possibilité de lag réplication (généralement <1s)
  EOT
  value = aws_elasticache_replication_group.main.reader_endpoint_address != null ? "${aws_elasticache_replication_group.main.reader_endpoint_address}:${local.current_config.port}" : null
}

output "port" {
  description = <<-EOT
    Port d'écoute Redis configuré.

    Standard: 6379
    Personnalisable via la variable redis_port.

    Utilisé dans:
    - Security groups (règles firewall)
    - Configuration des applications
    - Health checks
    - Monitoring
  EOT
  value = local.current_config.port
}

output "auth_token_enabled" {
  description = <<-EOT
    Indique si l'authentification par token est activée.

    Si true:
    - Commande AUTH requise avant toute opération
    - Token à récupérer depuis les outputs ou Secrets Manager
    - Sécurité renforcée (recommandé)

    Si false:
    - Accès libre depuis les security groups autorisés
    - Uniquement pour dev/test (non recommandé)
  EOT
  value = local.current_config.auth_token_enabled
}

# =============================================================================
# 2. CONFIGURATION CLUSTER ET NODES
# =============================================================================

output "cluster_mode_enabled" {
  description = <<-EOT
    Indique si le cluster mode Redis est activé.

    Cluster mode activé (production):
    - Sharding automatique des données
    - Scaling horizontal (multiples shards)
    - Haute performance (parallélisation)
    - Configuration plus complexe

    Cluster mode désactivé (dev/staging):
    - Configuration simple master/replica
    - Administration plus facile
    - Scaling vertical uniquement
  EOT
  value = local.use_cluster_mode
}

output "num_cache_clusters" {
  description = <<-EOT
    Nombre de clusters Redis déployés.

    Mode non-cluster:
    - 1: Single node (dev)
    - 2+: Master + replicas (staging/prod)

    Mode cluster:
    - Calculé automatiquement: num_node_groups × (1 + replicas_per_node_group)

    Impact sur les coûts: Multiplicateur direct
    (2 clusters = 2× le coût de base)
  EOT
  value = local.use_cluster_mode ? null : local.current_config.num_cache_clusters
}

output "num_node_groups" {
  description = <<-EOT
    Nombre de groupes de nodes (shards) en cluster mode.

    Chaque shard:
    - Gère une portion des données (hash slots)
    - A son propre master + replicas
    - Scale indépendamment

    Règle de dimensionnement:
    - 1 shard: jusqu'à 25GB de données
    - 3 shards: jusqu'à 75GB (configuration prod standard)
    - 6+ shards: très gros volumes (>150GB)

    Null si pas en cluster mode.
  EOT
  value = local.use_cluster_mode ? local.current_config.num_node_groups : null
}

output "replicas_per_node_group" {
  description = <<-EOT
    Nombre de replicas par shard en cluster mode.

    Configuration standard:
    - 1 replica: tolérance à 1 panne par shard
    - 2 replicas: tolérance à 2 pannes par shard (prod)
    - 3+ replicas: cas extrêmes haute disponibilité

    Impact:
    - Plus de replicas = plus de résilience
    - Plus de replicas = plus de coût
    - Plus de replicas = plus de lecture parallèle

    Null si pas en cluster mode.
  EOT
  value = local.use_cluster_mode ? local.current_config.replicas_per_node_group : null
}

output "node_type" {
  description = <<-EOT
    Type d'instance Redis utilisé.

    Performances par type (approximatives):
    - cache.t3.micro: 1k ops/sec, 0.5GB RAM
    - cache.t3.small: 5k ops/sec, 1.3GB RAM
    - cache.r6g.large: 100k ops/sec, 12GB RAM
    - cache.r6g.xlarge: 200k ops/sec, 25GB RAM

    Recommandations AccessWeaver:
    - Dev: t3.micro (économique)
    - Staging: t3.small (test réaliste)
    - Prod: r6g.large+ (performance)
  EOT
  value = local.current_config.node_type
}

# =============================================================================
# 3. SÉCURITÉ ET AUTHENTIFICATION
# =============================================================================

output "security_group_id" {
  description = <<-EOT
    ID du security group Redis créé par le module.

    Règles configurées:
    - Inbound: Port Redis depuis security groups autorisés uniquement
    - Outbound: Aucun (ElastiCache géré par AWS)

    Utilisation:
    - Référence dans d'autres security groups
    - Debugging de connectivité
    - Documentation de sécurité

    Exemple: "sg-0123456789abcdef0"
  EOT
  value = aws_security_group.redis.id
}

output "subnet_group_name" {
  description = <<-EOT
    Nom du subnet group ElastiCache créé.

    Contient:
    - Tous les subnets privés fournis en input
    - Configuration Multi-AZ automatique
    - Isolation réseau complète

    Utilisation:
    - Référence pour d'autres clusters Redis
    - Documentation de l'architecture réseau
    - Debugging de placement
  EOT
  value = aws_elasticache_subnet_group.main.name
}

output "parameter_group_name" {
  description = <<-EOT
    Nom du parameter group Redis créé.

    Optimisations incluses pour AccessWeaver:
    - maxmemory-policy: allkeys-lru (éviction intelligente)
    - hash-max-ziplist-entries: 512 (permissions par tenant)
    - notify-keyspace-events: Ex (notifications d'expiration)
    - timeout: adapté à l'environnement

    Paramètres personnalisés via custom_parameters également inclus.
  EOT
  value = aws_elasticache_parameter_group.main.name
}

output "encryption_at_rest_enabled" {
  description = <<-EOT
    Statut du chiffrement des données au repos.

    true: Toutes les données sur disque chiffrées (AES-256)
    false: Données en clair (non recommandé)

    Impact conformité:
    - RGPD: Chiffrement requis pour données personnelles
    - SOC2: Contrôle de sécurité standard
    - ISO27001: Exigence de protection des données
  EOT
  value = local.current_config.at_rest_encryption
}

output "encryption_in_transit_enabled" {
  description = <<-EOT
    Statut du chiffrement des données en transit.

    true: Connexions TLS 1.2+ obligatoires
    false: Connexions en clair (non recommandé)

    Configuration client nécessaire si activé:
    - Support TLS dans le driver Redis
    - URLs rediss:// au lieu de redis://
    - Certificats AWS dans le trust store
  EOT
  value = local.current_config.transit_encryption
}

output "kms_key_id" {
  description = <<-EOT
    ID de la clé KMS utilisée pour le chiffrement.

    null: Clé par défaut AWS (alias/aws/elasticache)
    string: Clé KMS personnalisée

    Clé personnalisée apporte:
    - Rotation automatique des clés
    - Contrôle d'accès granulaire
    - Audit trail complet
    - Conformité enterprise
  EOT
  value = var.kms_key_id
}

# =============================================================================
# 4. MONITORING ET MAINTENANCE
# =============================================================================

output "cloudwatch_alarms_arns" {
  description = <<-EOT
    ARNs des alarmes CloudWatch créées pour le monitoring.

    Alarmes configurées:
    - cpu_utilization: CPU > 75%
    - memory_utilization: Mémoire > 80%
    - cache_hit_ratio: Hit ratio < 80%
    - current_connections: Connexions élevées

    Utilisation:
    - Intégration avec SNS/alerting
    - Dashboard de monitoring
    - Automation de scaling
  EOT
  value = {
    cpu_utilization    = aws_cloudwatch_metric_alarm.cpu_utilization.arn
    memory_utilization = aws_cloudwatch_metric_alarm.memory_utilization.arn
    cache_hit_ratio    = aws_cloudwatch_metric_alarm.cache_hit_ratio.arn
    current_connections = aws_cloudwatch_metric_alarm.current_connections.arn
  }
}

output "maintenance_window" {
  description = <<-EOT
    Fenêtre de maintenance hebdomadaire configurée.

    Format: "ddd:hh24:mi-ddd:hh24:mi" (UTC)
    Exemple: "sun:05:00-sun:06:00"

    Opérations possibles pendant la maintenance:
    - Updates sécurité Redis
    - Patches ElastiCache
    - Modifications de configuration
    - Scaling (avec interruption possible)

    Planification recommandée pendant les heures creuses.
  EOT
  value = local.current_config.maintenance_window
}

output "snapshot_window" {
  description = <<-EOT
    Fenêtre de backup quotidien configurée.

    Format: "hh24:mi-hh24:mi" (UTC)
    Exemple: "03:00-05:00"

    Pendant cette fenêtre:
    - Snapshot automatique des données
    - Impact performance possible
    - Durée selon la taille des données

    Snapshots utilisés pour:
    - Disaster recovery
    - Migration vers autre cluster
    - Analyse offline des données
  EOT
  value = local.current_config.snapshot_window
}

output "snapshot_retention_period" {
  description = <<-EOT
    Durée de rétention des snapshots automatiques en jours.

    Snapshots automatiques:
    - Créés quotidiennement dans la fenêtre configurée
    - Chiffrés si encryption at-rest activé
    - Supprimés automatiquement après la période

    Coût: ~$0.095/GB/mois pour le stockage

    Snapshots manuels non affectés par cette limite.
  EOT
  value = local.current_config.snapshot_retention
}

# =============================================================================
# 5. CONFIGURATION SPRING BOOT READY-TO-USE
# =============================================================================

output "spring_redis_config" {
  description = <<-EOT
    Configuration Spring Boot Redis prête à utiliser.

    Inclut:
    - Configuration master/replica si applicable
    - Paramètres de connexion optimisés
    - Pool de connexions adapté à l'environnement
    - Configuration TLS si activé

    À copier dans application.yml puis adapter les credentials.
  EOT
  value = {
    master = {
      host     = split(":", local.use_cluster_mode ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address)[0]
      port     = local.current_config.port
      ssl      = local.current_config.transit_encryption
      password = local.current_config.auth_token_enabled ? "REPLACE_WITH_AUTH_TOKEN" : null
      database = 0
      timeout  = "30000"

      # Pool de connexions optimisé pour AccessWeaver
      lettuce = {
        pool = {
          max-active = local.is_production ? "20" : local.is_staging ? "10" : "5"
          max-idle   = local.is_production ? "10" : local.is_staging ? "5" : "2"
          min-idle   = local.is_production ? "5" : local.is_staging ? "2" : "1"
          max-wait   = "10000"
        }
        shutdown-timeout = "5000"

        # Configuration cluster si activé
        cluster = local.use_cluster_mode ? {
          refresh = {
            adaptive = true
            period   = "30000"
          }
          topology = {
            refresh = {
              adaptive    = true
              period      = "30000"
              refresh-triggers = ["MOVED_REDIRECT", "ASK_REDIRECT"]
            }
          }
        } : null
      }
    }

    # Configuration replica si disponible
    replica = aws_elasticache_replication_group.main.reader_endpoint_address != null ? {
      host     = split(":", aws_elasticache_replication_group.main.reader_endpoint_address)[0]
      port     = local.current_config.port
      ssl      = local.current_config.transit_encryption
      password = local.current_config.auth_token_enabled ? "REPLACE_WITH_AUTH_TOKEN" : null
      database = 0
      timeout  = "30000"

      lettuce = {
        pool = {
          max-active = local.is_production ? "15" : local.is_staging ? "8" : "3"
          max-idle   = local.is_production ? "8" : local.is_staging ? "4" : "2"
          min-idle   = local.is_production ? "3" : local.is_staging ? "1" : "1"
          max-wait   = "10000"
        }
        shutdown-timeout = "5000"
      }
    } : null
  }
}

output "application_yml_redis_config" {
  description = <<-EOT
    Configuration application.yml complète pour Spring Boot.

    Prête à copier-coller dans votre application.yml.
    Remplacez REPLACE_WITH_AUTH_TOKEN par le vrai token.

    Inclut:
    - Configuration master/replica
    - Pool de connexions optimisé
    - Cache configuration pour AccessWeaver
    - Serialization JSON pour les objets
  EOT
  sensitive   = true
  value = local.current_config.auth_token_enabled ? "# ⚠️ AUTH TOKEN REQUIS - Récupérer via AWS Secrets Manager\n\n" : "" + <<-EOT
spring:
  redis:
    # Configuration master (écriture)
    host: ${split(":", local.use_cluster_mode ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address)[0]}
    port: ${local.current_config.port}
    ${local.current_config.auth_token_enabled ? "password: \"${var.auth_token != null ? var.auth_token : random_password.auth_token[0].result}\" # Secret géré par Terraform" : "# Pas d'authentification configurée"}
    database: 0
    timeout: 30s
    ssl: ${local.current_config.transit_encryption}

    lettuce:
      pool:
        max-active: ${local.is_production ? "20" : local.is_staging ? "10" : "5"}
        max-idle: ${local.is_production ? "10" : local.is_staging ? "5" : "2"}
        min-idle: ${local.is_production ? "5" : local.is_staging ? "2" : "1"}
        max-wait: 10s
      shutdown-timeout: 5s
      ${local.use_cluster_mode ? "cluster:\n        refresh:\n          adaptive: true\n          period: 30s" : ""}

    ${aws_elasticache_replication_group.main.reader_endpoint_address != null ? "# Configuration replica (lecture)\n    replica:\n      host: ${split(":", aws_elasticache_replication_group.main.reader_endpoint_address)[0]}\n      port: ${local.current_config.port}\n      ${local.current_config.auth_token_enabled ? "password: \"${var.auth_token != null ? var.auth_token : random_password.auth_token[0].result}\"" : ""}\n      database: 0\n      timeout: 30s\n      ssl: ${local.current_config.transit_encryption}" : "# Pas de replica configuré pour ${var.environment}"}

  cache:
    type: redis
    redis:
      time-to-live: 300000 # 5 minutes pour les permissions
      cache-null-values: false
      use-key-prefix: true
      key-prefix: "aw:${var.environment}:"

# Configuration cache AccessWeaver
accessweaver:
  cache:
    redis:
      enabled: true
      # Namespacing par tenant automatique
      key-patterns:
        permissions: "permissions:tenant:{tenantId}:user:{userId}"
        roles: "roles:tenant:{tenantId}:user:{userId}"
        policies: "policies:tenant:{tenantId}:resource:{resourceId}"
        sessions: "sessions:tenant:{tenantId}:token:{tokenId}"

      # TTL par type de cache (en secondes)
      ttl:
        permissions: 300    # 5 minutes
        roles: 600         # 10 minutes
        policies: 1800     # 30 minutes
        sessions: 3600     # 1 heure

      # Configuration pour les bulk operations
      pipeline:
        enabled: true
        batch-size: 100

      # Pub/Sub pour invalidation cross-services
      pubsub:
        enabled: true
        channels:
          policy-updates: "aw:policy-updates"
          cache-invalidation: "aw:cache-invalidation"
EOT
}

output "jedis_connection_string" {
  description = <<-EOT
    URL de connexion Redis compatible Jedis/Lettuce.

    Format: redis[s]://[:password@]host:port[/database]

    Utilisation:
    - Clients Redis Java (Jedis, Lettuce)
    - Tools d'administration (RedisInsight)
    - Scripts de test et monitoring

    Note: Remplacez AUTH_TOKEN par le vrai token si authentification activée.
  EOT
  value = local.current_config.auth_token_enabled ? (
    local.current_config.transit_encryption ?
    "rediss://:AUTH_TOKEN@${split(":", local.use_cluster_mode ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address)[0]}:${local.current_config.port}/0" :
    "redis://:AUTH_TOKEN@${split(":", local.use_cluster_mode ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address)[0]}:${local.current_config.port}/0"
  ) : (
    local.current_config.transit_encryption ?
    "rediss://${split(":", local.use_cluster_mode ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address)[0]}:${local.current_config.port}/0" :
    "redis://${split(":", local.use_cluster_mode ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address)[0]}:${local.current_config.port}/0"
  )
}

# =============================================================================
# 6. DOCKER ET INFRASTRUCTURE
# =============================================================================

output "docker_environment_variables" {
  description = <<-EOT
    Variables d'environnement pour Docker Compose et containers.

    Utilisables directement dans:
    - docker-compose.yml
    - Kubernetes ConfigMaps
    - ECS Task Definitions
    - Fargate services

    Sécurité: Ne pas mettre le AUTH_TOKEN dans les variables d'environnement.
    Utiliser AWS Secrets Manager ou Kubernetes Secrets.
  EOT
  value = {
    REDIS_HOST                = split(":", local.use_cluster_mode ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address)[0]
    REDIS_PORT                = tostring(local.current_config.port)
    REDIS_SSL_ENABLED         = tostring(local.current_config.transit_encryption)
    REDIS_AUTH_ENABLED        = tostring(local.current_config.auth_token_enabled)
    REDIS_DATABASE            = "0"
    REDIS_TIMEOUT_MS          = "30000"
    REDIS_CLUSTER_MODE        = tostring(local.use_cluster_mode)

    # Replica endpoint si disponible
    REDIS_REPLICA_HOST        = aws_elasticache_replication_group.main.reader_endpoint_address != null ? split(":", aws_elasticache_replication_group.main.reader_endpoint_address)[0] : ""
    REDIS_REPLICA_PORT        = aws_elasticache_replication_group.main.reader_endpoint_address != null ? tostring(local.current_config.port) : ""

    # Pool de connexions
    REDIS_POOL_MAX_ACTIVE     = local.is_production ? "20" : local.is_staging ? "10" : "5"
    REDIS_POOL_MAX_IDLE       = local.is_production ? "10" : local.is_staging ? "5" : "2"
    REDIS_POOL_MIN_IDLE       = local.is_production ? "5" : local.is_staging ? "2" : "1"

    # Configuration AccessWeaver
    ACCESSWEAVER_CACHE_PREFIX = "aw:${var.environment}:"
    ACCESSWEAVER_CACHE_TTL    = "300"
  }
}

output "kubernetes_config_map_yaml" {
  description = <<-EOT
    ConfigMap Kubernetes prêt à déployer.

    Contient toute la configuration Redis non-sensible.
    Pour les secrets (AUTH_TOKEN), créer un Secret séparé.

    Usage:
    kubectl apply -f redis-config.yaml
  EOT
  value = <<-EOT
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${var.project_name}-${var.environment}-redis-config
  namespace: ${var.project_name}-${var.environment}
  labels:
    app: ${var.project_name}
    component: redis-config
    environment: ${var.environment}
data:
  REDIS_HOST: "${split(":", local.use_cluster_mode ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address)[0]}"
  REDIS_PORT: "${local.current_config.port}"
  REDIS_SSL_ENABLED: "${local.current_config.transit_encryption}"
  REDIS_AUTH_ENABLED: "${local.current_config.auth_token_enabled}"
  REDIS_DATABASE: "0"
  REDIS_TIMEOUT_MS: "30000"
  REDIS_CLUSTER_MODE: "${local.use_cluster_mode}"
  ${aws_elasticache_replication_group.main.reader_endpoint_address != null ? "REDIS_REPLICA_HOST: \"${split(":", aws_elasticache_replication_group.main.reader_endpoint_address)[0]}\"\n  REDIS_REPLICA_PORT: \"${local.current_config.port}\"" : "# Pas de replica configuré"}
  REDIS_POOL_MAX_ACTIVE: "${local.is_production ? "20" : local.is_staging ? "10" : "5"}"
  REDIS_POOL_MAX_IDLE: "${local.is_production ? "10" : local.is_staging ? "5" : "2"}"
  REDIS_POOL_MIN_IDLE: "${local.is_production ? "5" : local.is_staging ? "2" : "1"}"
  ACCESSWEAVER_CACHE_PREFIX: "aw:${var.environment}:"
  ACCESSWEAVER_CACHE_TTL: "300"
---
${local.current_config.auth_token_enabled ? "# Secret pour AUTH_TOKEN (à créer séparément)\napiVersion: v1\nkind: Secret\nmetadata:\n  name: ${var.project_name}-${var.environment}-redis-secret\n  namespace: ${var.project_name}-${var.environment}\ntype: Opaque\ndata:\n  REDIS_AUTH_TOKEN: # Base64 du token AUTH\nstringData:\n  REDIS_AUTH_TOKEN: # Token en clair (kubectl le convertira)" : "# Pas d'authentification Redis configurée"}
EOT
}

# =============================================================================
# 7. COÛTS ET OPTIMISATION
# =============================================================================

output "estimated_monthly_cost" {
  description = <<-EOT
    Estimation du coût mensuel AWS pour le cluster Redis.

    Calcul basé sur:
    - Type d'instance et nombre de nodes
    - Région eu-west-1 (prix Paris)
    - Pas de Reserved Instances
    - Transfert de données inclus

    Coûts additionnels possibles:
    - Snapshots: ~$0.095/GB/mois
    - Transfert cross-AZ: ~$0.01/GB
    - CloudWatch Logs: ~$0.50/GB/mois

    Optimisations possibles:
    - Reserved Instances (-30% à -60%)
    - Scaling horizontal vs vertical
    - Optimisation des snapshots
  EOT
  value = {
    instance_type = local.current_config.node_type
    num_instances = local.use_cluster_mode ? (local.current_config.num_node_groups * (1 + local.current_config.replicas_per_node_group)) : local.current_config.num_cache_clusters
    environment = var.environment
    estimated_range = local.is_production ? "$150-300/month" : local.is_staging ? "$50-100/month" : "$15-30/month"
    cost_factors = {
      compute = "Coût principal (type d'instance × nombre de nodes)"
      storage = "Snapshots et données (~$0.095/GB/mois)"
      network = "Transfert cross-AZ (~$0.01/GB)"
      monitoring = "CloudWatch Logs si activé (~$0.50/GB)"
    }
    optimization_tips = {
      reserved_instances = "30-60% d'économies sur 1-3 ans"
      right_sizing = "Monitorer CPU/mémoire pour optimiser le type d'instance"
      snapshot_lifecycle = "Nettoyer les anciens snapshots manuels"
      cross_az_traffic = "Optimiser le placement des applications"
    }
  }
}

output "cost_allocation_tags" {
  description = <<-EOT
    Tags utiles pour l'allocation et suivi des coûts.

    À utiliser dans AWS Cost Explorer:
    - Grouper par Project (accessweaver)
    - Filtrer par Environment (dev/staging/prod)
    - Tracker par Component (cache)

    Ces tags sont automatiquement appliqués à toutes les ressources.
  EOT
  value = {
    Project     = var.project_name
    Environment = var.environment
    Component   = "cache"
    Service     = "accessweaver-redis"
    Purpose     = "authorization-cache"
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# 8. DEBUGGING ET TROUBLESHOOTING
# =============================================================================

output "debugging_information" {
  description = <<-EOT
    Informations pour le debugging et le troubleshooting.

    Commandes utiles:
    - Test connexion: redis-cli -h HOST -p PORT -a TOKEN ping
    - Info cluster: redis-cli -h HOST -p PORT -a TOKEN cluster info
    - Stats mémoire: redis-cli -h HOST -p PORT -a TOKEN info memory
    - Slow log: redis-cli -h HOST -p PORT -a TOKEN slowlog get 10
  EOT
  value = {
    endpoints = {
      primary = local.use_cluster_mode ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address
      reader  = aws_elasticache_replication_group.main.reader_endpoint_address
    }

    redis_cli_commands = {
      test_connection = "redis-cli -h ${split(":", local.use_cluster_mode ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address)[0]} -p ${local.current_config.port}${local.current_config.auth_token_enabled ? " -a AUTH_TOKEN" : ""} ping"

      cluster_info = local.use_cluster_mode ? "redis-cli -h ${split(":", aws_elasticache_replication_group.main.configuration_endpoint_address)[0]} -p ${local.current_config.port}${local.current_config.auth_token_enabled ? " -a AUTH_TOKEN" : ""} cluster info" : "N/A (pas en cluster mode)"

      memory_info = "redis-cli -h ${split(":", local.use_cluster_mode ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address)[0]} -p ${local.current_config.port}${local.current_config.auth_token_enabled ? " -a AUTH_TOKEN" : ""} info memory"

      slow_log = "redis-cli -h ${split(":", local.use_cluster_mode ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address)[0]} -p ${local.current_config.port}${local.current_config.auth_token_enabled ? " -a AUTH_TOKEN" : ""} slowlog get 10"
    }

    aws_cli_commands = {
      describe_cluster = "aws elasticache describe-replication-groups --replication-group-id ${aws_elasticache_replication_group.main.replication_group_id}"

      create_snapshot = "aws elasticache create-snapshot --cache-cluster-id ${aws_elasticache_replication_group.main.replication_group_id}-001 --snapshot-name manual-backup-$(date +%Y%m%d-%H%M)"

      list_snapshots = "aws elasticache describe-snapshots --replication-group-id ${aws_elasticache_replication_group.main.replication_group_id}"
    }

    cloudwatch_metrics = {
      cpu_utilization = "CPUUtilization"
      memory_usage = "DatabaseMemoryUsagePercentage"
      cache_hits = "CacheHits"
      cache_misses = "CacheMisses"
      current_connections = "CurrConnections"
      new_connections = "NewConnections"
    }

    common_issues = {
      connection_refused = "Vérifier security groups et subnets"
      auth_failed = "Vérifier AUTH token et configuration TLS"
      high_memory = "Analyser les patterns de cache et TTL"
      low_hit_ratio = "Optimiser la stratégie de cache"
      high_latency = "Vérifier network et instance sizing"
    }
  }
}

output "health_check_endpoints" {
  description = <<-EOT
    Endpoints pour les health checks d'application.

    À implémenter dans votre service pour vérifier:
    - Connectivité Redis
    - Authentification
    - Performance (latence)
    - Hit ratio du cache

    Exemple Spring Boot:
    @Component
    public class RedisHealthIndicator implements HealthIndicator {
      // Ping Redis et retourner status
    }
  EOT
  value = {
    primary_health_check = {
      command = "PING"
      expected_response = "PONG"
      timeout_ms = 5000
      endpoint = "${split(":", local.use_cluster_mode ? aws_elasticache_replication_group.main.configuration_endpoint_address : aws_elasticache_replication_group.main.primary_endpoint_address)[0]}:${local.current_config.port}"
    }

    replica_health_check = aws_elasticache_replication_group.main.reader_endpoint_address != null ? {
      command = "PING"
      expected_response = "PONG"
      timeout_ms = 5000
      endpoint = "${split(":", aws_elasticache_replication_group.main.reader_endpoint_address)[0]}:${local.current_config.port}"
    } : null

    performance_check = {
      command = "SET test_key test_value"
      followup = "GET test_key"
      cleanup = "DEL test_key"
      max_latency_ms = 10
    }
  }
}

# =============================================================================
# 9. INFORMATIONS ENVIRONNEMENT ET MÉTADONNÉES
# =============================================================================

output "environment" {
  description = "Environnement de déploiement configuré"
  value       = var.environment
}

output "region" {
  description = "Région AWS où le cluster est déployé"
  value       = data.aws_availability_zones.available.id
}

output "engine_version" {
  description = "Version du moteur Redis déployée"
  value       = local.current_config.engine_version
}

output "multi_az_enabled" {
  description = "Status Multi-AZ du cluster"
  value       = local.current_config.multi_az
}

output "automatic_failover_enabled" {
  description = "Status du failover automatique"
  value       = local.current_config.automatic_failover
}