# =============================================================================
# AccessWeaver Redis Module - Variables
# =============================================================================
# Variables pour la configuration du module Redis ElastiCache
#
# ORGANISATION:
# 1. Variables obligatoires (Required)
# 2. Configuration Redis de base
# 3. Sécurité et authentification
# 4. Réseau et infrastructure
# 5. Monitoring et logging
# 6. Configuration avancée (optionnelle)
# 7. Optimisation des coûts
# 8. Tags et métadonnées
#
# PHILOSOPHIE:
# - Sensible defaults pour chaque environnement
# - Validation stricte des inputs
# - Support des overrides pour les cas spéciaux
# =============================================================================

# =============================================================================
# 1. VARIABLES OBLIGATOIRES - Doivent être fournies par l'appelant
# =============================================================================

variable "project_name" {
  description = "accessweaver"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.project_name)) && length(var.project_name) <= 20
    error_message = "Le nom du projet doit contenir uniquement des lettres minuscules, chiffres et tirets, commencer et finir par un caractère alphanumérique, et faire maximum 20 caractères."
  }
}

variable "environment" {
  description = <<-EOT
    Environnement de déploiement qui détermine la configuration automatique.

    Configurations par environnement:
    - dev: Single node, cache.t3.micro, pas de HA (économique)
    - staging: Replication group, cache.t3.small, Multi-AZ (test HA)
    - prod: Cluster mode, cache.r6g.large, sharding + replicas (performance)

    Cette variable influence automatiquement:
    - Type d'instance Redis
    - Nombre de nodes/replicas
    - Activation de la haute disponibilité
    - Durée de rétention des snapshots
    - Activation du monitoring enhanced
  EOT
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être exactement: dev, staging ou prod."
  }
}

variable "vpc_id" {
  description = <<-EOT
    ID du VPC où déployer le cluster Redis.

    Le VPC doit avoir:
    - Au moins 2 subnets privés dans des AZ différentes
    - Route tables configurées pour l'accès internet (updates)
    - DNS hostnames et resolution activés

    Exemple: "vpc-0123456789abcdef0"
  EOT
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]{8,17}$", var.vpc_id))
    error_message = "L'ID du VPC doit être au format AWS standard: vpc-xxxxxxxxx."
  }
}

variable "private_subnet_ids" {
  description = <<-EOT
    Liste des IDs des subnets privés pour déployer Redis.

    Exigences:
    - Minimum 2 subnets pour la haute disponibilité
    - Subnets dans des AZ différentes
    - Subnets privés uniquement (pas d'IP publique)
    - Routage vers NAT Gateway pour les updates

    Exemple: ["subnet-0123456789abcdef0", "subnet-fedcba9876543210f"]

    Note: Redis sera accessible uniquement depuis le VPC,
    jamais depuis internet même avec des subnets publics.
  EOT
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "Au moins 2 subnets privés sont requis pour la haute disponibilité Multi-AZ."
  }

  validation {
    condition = alltrue([
      for subnet_id in var.private_subnet_ids :
      can(regex("^subnet-[0-9a-f]{8,17}$", subnet_id))
    ])
    error_message = "Tous les IDs de subnet doivent être au format AWS standard: subnet-xxxxxxxxx."
  }
}

variable "allowed_security_groups" {
  description = <<-EOT
    Liste des security groups autorisés à accéder au cluster Redis.

    Typiquement:
    - Security group des services ECS AccessWeaver
    - Security group des instances de développement (dev uniquement)
    - Security group des outils de monitoring

    Exemple: ["sg-0123456789abcdef0", "sg-fedcba9876543210f"]

    Sécurité: Seuls ces security groups pourront se connecter au port 6379.
    Aucun accès depuis internet n'est possible.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for sg_id in var.allowed_security_groups :
      can(regex("^sg-[0-9a-f]{8,17}$", sg_id))
    ])
    error_message = "Tous les IDs de security group doivent être au format AWS standard: sg-xxxxxxxxx."
  }
}

# =============================================================================
# 2. CONFIGURATION REDIS DE BASE
# =============================================================================

variable "auth_token" {
  description = <<-EOT
    Token d'authentification Redis (AUTH command).

    Si null, un token sécurisé sera généré automatiquement.

    Exigences du token:
    - Longueur: 16-128 caractères
    - Caractères autorisés: A-Z, a-z, 0-9
    - Pas de caractères spéciaux (limitation ElastiCache)

    Sécurité: Ce token sera requis pour toutes les connexions Redis.
    Il doit être stocké de manière sécurisée (AWS Secrets Manager recommandé).

    Exemple: "MySecureRedisAuthToken123456789"
  EOT
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition = var.auth_token == null || (
    length(var.auth_token) >= 16 &&
    length(var.auth_token) <= 128 &&
    can(regex("^[A-Za-z0-9]+$", var.auth_token))
    )
    error_message = "Le token d'authentification doit faire entre 16 et 128 caractères et contenir uniquement des lettres et chiffres."
  }
}

variable "redis_port" {
  description = <<-EOT
    Port d'écoute de Redis.

    Valeur par défaut: 6379 (port standard Redis)

    Note: Changer le port par défaut peut ajouter une couche de sécurité
    par obscurité, mais ce n'est pas une protection suffisante seule.

    La vraie sécurité vient de:
    - Security groups restrictifs
    - Authentification par token
    - Chiffrement TLS
    - Déploiement en subnets privés
  EOT
  type        = number
  default     = 6379

  validation {
    condition     = var.redis_port >= 1024 && var.redis_port <= 65535
    error_message = "Le port Redis doit être entre 1024 et 65535."
  }
}

variable "engine_version" {
  description = <<-EOT
    Version du moteur Redis à utiliser.

    Versions supportées: 6.2, 7.0, 7.1
    Recommandé: "7.0" (équilibre stabilité/performance)

    Redis 7.0 apporte:
    - Amélioration des performances jusqu'à 20%
    - Commandes ACL avancées
    - Fonctions Redis (alternative aux scripts Lua)
    - Meilleure gestion mémoire

    Note: Les upgrades mineures sont automatiques,
    les upgrades majeures nécessitent une intervention.
  EOT
  type        = string
  default     = "7.0"

  validation {
    condition     = contains(["6.2", "7.0", "7.1"], var.engine_version)
    error_message = "La version Redis doit être: 6.2, 7.0 ou 7.1."
  }
}

# =============================================================================
# 3. SÉCURITÉ ET AUTHENTIFICATION
# =============================================================================

variable "at_rest_encryption_enabled" {
  description = <<-EOT
    Active le chiffrement des données au repos.

    Valeur par défaut: true (sécurité par défaut)

    Quand activé:
    - Toutes les données sur disque sont chiffrées (AES-256)
    - Les snapshots sont automatiquement chiffrés
    - Overhead de performance négligeable
    - Aucun impact sur les applications (transparent)

    Conformité: Requis pour RGPD, SOC2, ISO27001

    Note: Ne peut pas être modifié après création du cluster.
  EOT
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = <<-EOT
    Active le chiffrement des données en transit (TLS).

    Valeur par défaut: true (sécurité par défaut)

    Quand activé:
    - Toutes les connexions utilisent TLS 1.2+
    - Certificats gérés automatiquement par AWS
    - AUTH token protégé en transit
    - Overhead ~5-10% sur les performances

    Impact applications:
    - Les clients Redis doivent supporter TLS
    - URLs de connexion différentes (rediss:// au lieu de redis://)

    Note: Ne peut pas être modifié après création du cluster.
  EOT
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = <<-EOT
    ID de la clé KMS pour le chiffrement at-rest.

    Si null, utilise la clé par défaut AWS (alias/aws/elasticache).

    Pour une sécurité renforcée, créez une clé KMS dédiée:
    - Rotation automatique des clés
    - Contrôle d'accès granulaire
    - Audit trail complet
    - Conformité enterprise

    Exemple: "arn:aws:kms:eu-west-1:123456789012:key/12345678-1234-1234-1234-123456789012"
    Ou: "alias/accessweaver-redis-key"

    Coût: ~$1/mois par clé + $0.03 par 10,000 opérations
  EOT
  type        = string
  default     = null
}

# =============================================================================
# 4. MONITORING ET LOGGING
# =============================================================================

variable "sns_topic_arn" {
  description = <<-EOT
    ARN du topic SNS pour les notifications CloudWatch.

    Si fourni, des alertes seront envoyées pour:
    - CPU utilization > 75%
    - Memory utilization > 80%
    - Cache hit ratio < 80%
    - Connection count élevé
    - Failover events

    Exemple: "arn:aws:sns:eu-west-1:123456789012:accessweaver-alerts"

    Configuration recommandée:
    - Email pour les alertes critiques
    - Slack/Teams pour les alertes d'information
    - PagerDuty pour les alertes de production
  EOT
  type        = string
  default     = null
}

variable "enable_slow_log" {
  description = <<-EOT
    Active l'envoi des slow logs vers CloudWatch Logs.

    Utile pour:
    - Identifier les requêtes lentes (>10ms)
    - Optimiser les patterns d'accès au cache
    - Debug des performances en dev/staging

    Logs capturés:
    - Commandes Redis lentes
    - Timestamp et durée d'exécution
    - Arguments de la commande (avec truncature)

    Coût: ~$0.50/GB de logs ingérés

    Recommandation: true en dev/staging, false en prod (performance)
  EOT
  type        = bool
  default     = false
}

variable "cloudwatch_log_retention_days" {
  description = <<-EOT
    Durée de rétention des logs CloudWatch en jours.

    Options: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653

    Recommandations par environnement:
    - dev: 7 jours (debug court terme)
    - staging: 30 jours (investigation)
    - prod: 90 jours (compliance et audit)

    Coût: ~$0.50/GB/mois pour le stockage
  EOT
  type        = number
  default     = 7

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.cloudwatch_log_retention_days)
    error_message = "La rétention CloudWatch doit être une valeur supportée par AWS."
  }
}

# =============================================================================
# 5. CONFIGURATION AVANCÉE (OPTIONNELLE)
# =============================================================================

variable "custom_parameters" {
  description = <<-EOT
    Paramètres Redis personnalisés à ajouter au parameter group.

    Exemple pour AccessWeaver:
    [
      {
        name  = "maxmemory-policy"
        value = "allkeys-lru"
      },
      {
        name  = "timeout"
        value = "300"
      }
    ]

    Paramètres utiles pour AccessWeaver:
    - maxmemory-policy: allkeys-lru (éviction intelligente)
    - timeout: 300 (fermeture connexions inactives)
    - tcp-keepalive: 300 (détection connexions mortes)
    - notify-keyspace-events: Ex (notifications expiration)

    ⚠️  Attention: Certains paramètres nécessitent un redémarrage du cluster.
  EOT
  type = list(object({
    name  = string
    value = string
  }))
  default = []

  validation {
    condition = alltrue([
      for param in var.custom_parameters :
      can(regex("^[a-zA-Z0-9_-]+$", param.name))
    ])
    error_message = "Les noms des paramètres Redis doivent contenir uniquement des lettres, chiffres, tirets et underscores."
  }
}

variable "maintenance_window" {
  description = <<-EOT
    Fenêtre de maintenance hebdomadaire pour les updates Redis.

    Format: "ddd:hh24:mi-ddd:hh24:mi" (UTC)
    Exemple: "sun:05:00-sun:06:00"

    Recommandations:
    - Choisir un créneau de faible activité
    - Éviter les heures de pointe business
    - Prévoir 1-2h pour les maintenances majeures

    Opérations pendant la maintenance:
    - Updates sécurité Redis
    - Patches ElastiCache
    - Modifications de configuration
    - Scaling vertical (si nécessaire)

    Note: Les maintenances peuvent causer une brève interruption.
  EOT
  type        = string
  default     = null

  validation {
    condition = var.maintenance_window == null || can(regex(
      "^(mon|tue|wed|thu|fri|sat|sun):[0-2][0-9]:[0-5][0-9]-(mon|tue|wed|thu|fri|sat|sun):[0-2][0-9]:[0-5][0-9]$",
      var.maintenance_window
    ))
    error_message = "La fenêtre de maintenance doit être au format: ddd:hh24:mi-ddd:hh24:mi (ex: sun:05:00-sun:06:00)."
  }
}

variable "snapshot_window" {
  description = <<-EOT
    Fenêtre quotidienne pour les snapshots automatiques.

    Format: "hh24:mi-hh24:mi" (UTC)
    Exemple: "03:00-05:00"

    Durée recommandée: 2h minimum

    Considérations:
    - Impact performance pendant le snapshot
    - Éviter les heures de pointe
    - Coordonner avec les backups RDS

    Snapshots automatiques:
    - Sauvegarde quotidienne
    - Rétention configurable (1-35 jours)
    - Restauration point-in-time
    - Chiffrement automatique si activé

    Coût: ~$0.095/GB/mois pour le stockage des snapshots
  EOT
  type        = string
  default     = null

  validation {
    condition = var.snapshot_window == null || can(regex(
      "^[0-2][0-9]:[0-5][0-9]-[0-2][0-9]:[0-5][0-9]$",
      var.snapshot_window
    ))
    error_message = "La fenêtre de snapshot doit être au format: hh24:mi-hh24:mi (ex: 03:00-05:00)."
  }
}

variable "snapshot_retention_limit" {
  description = <<-EOT
    Nombre de jours de rétention des snapshots automatiques.

    Plage: 1-35 jours

    Recommandations par environnement:
    - dev: 1 jour (économique)
    - staging: 5 jours (test de restore)
    - prod: 7-30 jours (disaster recovery)

    Considérations:
    - Coût proportionnel à la rétention
    - Temps de restauration selon l'âge du snapshot
    - Conformité et audit (certains secteurs exigent 30+ jours)

    Note: Les snapshots manuels ne sont pas affectés par cette limite.
  EOT
  type        = number
  default     = null

  validation {
    condition     = var.snapshot_retention_limit == null || (var.snapshot_retention_limit >= 1 && var.snapshot_retention_limit <= 35)
    error_message = "La rétention des snapshots doit être entre 1 et 35 jours."
  }
}

# =============================================================================
# 6. OPTIMISATION DES COÛTS
# =============================================================================

variable "node_type_override" {
  description = <<-EOT
    Type d'instance Redis (override la valeur par défaut de l'environnement).

    Configurations par défaut:
    - dev: cache.t3.micro (1 vCPU, 0.5 GB RAM) ~$13/mois
    - staging: cache.t3.small (2 vCPU, 1.37 GB RAM) ~$24/mois
    - prod: cache.r6g.large (2 vCPU, 12.32 GB RAM) ~$100/mois

    Types recommandés pour AccessWeaver:

    Développement:
    - cache.t3.micro: POC, tests unitaires
    - cache.t3.small: dev team, intégration

    Production:
    - cache.r6g.large: jusqu'à 10k utilisateurs
    - cache.r6g.xlarge: jusqu'à 50k utilisateurs
    - cache.r6g.2xlarge: 100k+ utilisateurs

    Memory-optimized (r6g) recommandé pour le cache d'autorisation.

    Exemple: "cache.r6g.large"
  EOT
  type        = string
  default     = null

  validation {
    condition = var.node_type_override == null || can(regex(
      "^cache\\.(t3|t4g|m6g|r6g|r7g)\\.(micro|small|medium|large|xlarge|2xlarge|4xlarge|8xlarge|12xlarge|16xlarge)$",
      var.node_type_override
    ))
    error_message = "Le type d'instance doit être un type ElastiCache valide (ex: cache.r6g.large)."
  }
}

variable "num_cache_clusters_override" {
  description = <<-EOT
    Nombre de clusters Redis (override la configuration par défaut).

    ⚠️  Utilisé uniquement en mode non-cluster (dev/staging).

    Configurations par défaut:
    - dev: 1 (single node, pas de HA)
    - staging: 2 (primary + 1 replica)
    - prod: utilise cluster mode (ignoré)

    Considérations:
    - Plus de replicas = plus de résilience
    - Réplication asynchrone (léger lag possible)
    - Coût multiplicateur (2 replicas = 2x le coût)

    Recommandations:
    - 1: dev uniquement
    - 2-3: staging/prod non-critique
    - Cluster mode: prod haute charge
  EOT
  type        = number
  default     = null

  validation {
    condition     = var.num_cache_clusters_override == null || (var.num_cache_clusters_override >= 1 && var.num_cache_clusters_override <= 6)
    error_message = "Le nombre de clusters doit être entre 1 et 6."
  }
}

variable "enable_cluster_mode_override" {
  description = <<-EOT
    Force l'activation/désactivation du cluster mode Redis.

    Par défaut, le cluster mode est:
    - Désactivé en dev/staging (simplicité)
    - Activé en prod (performance + HA)

    Cluster mode apporte:
    - Partitioning automatique (sharding)
    - Scaling horizontal (16k+ ops/sec)
    - Haute disponibilité native
    - Complexité de configuration accrue

    Use cases pour l'override:
    - true: Tester le cluster mode en staging
    - false: Prod simple sans sharding

    ⚠️  Le cluster mode ne peut pas être modifié après création.
  EOT
  type        = bool
  default     = null
}

# =============================================================================
# 7. TAGS ET MÉTADONNÉES
# =============================================================================

variable "additional_tags" {
  description = <<-EOT
    Tags supplémentaires à appliquer à toutes les ressources Redis.
    Tags automatiques déjà appliqués:
    - Name: [project_name]-[environment]-redis
    - Project: [project_name]
    - Environment: [environment]
    - Component: cache
    - ManagedBy: terraform
    - Service: accessweaver-redis
    - Purpose: authorization-cache

    Tags supplémentaires utiles:
    {
      CostCenter    = "Engineering"
      Owner         = "Platform Team"
      BusinessUnit  = "Product"
      Compliance    = "GDPR"
      BackupPolicy  = "Daily"
      MonitoringLevel = "Enhanced"
    }

    Best practices:
    - Utiliser une convention de nommage cohérente
    - Inclure les informations de coût/facturation
    - Ajouter les contacts techniques
    - Spécifier les exigences de compliance
  EOT
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for key, value in var.additional_tags :
      length(key) <= 128 && length(value) <= 256
      ])
    error_message = "Les clés de tags doivent faire maximum 128 caractères et les valeurs maximum 256 caractères."
  }
}

# =============================================================================
# 8. VARIABLES POUR TESTS ET DÉVELOPPEMENT
# =============================================================================

variable "skip_final_snapshot" {
  description = <<-EOT
    Ignore la création d'un snapshot final lors de la destruction.

    Valeur par défaut: false (sécurité)

    ⚠️  ATTENTION: Si true, toutes les données seront perdues définitivement
    lors de la destruction du cluster, sans possibilité de récupération.

    Utilisation recommandée:
    - false: environnements persistants (staging, prod)
    - true: environnements temporaires (tests, CI/CD)

    Alternative sécurisée:
    Créer un snapshot manuel avant destruction:
    aws elasticache create-snapshot --cache-cluster-id xxx --snapshot-name backup
  EOT
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = <<-EOT
    Applique immédiatement les modifications au lieu d'attendre la fenêtre de maintenance.

    Valeur par défaut: false (sécurité)

    Impact des modifications immédiates:
    - Possible interruption de service (30s-2min)
    - Pas de rollback automatique
    - Utile pour les correctifs critiques

    Recommandations:
    - false: changements de routine
    - true: correctifs sécurité urgents

    Types de modifications nécessitant un redémarrage:
    - Changement de type d'instance
    - Modification de certains paramètres
    - Activation/désactivation du chiffrement
  EOT
  type        = bool
  default     = false
}