# =============================================================================
# AccessWeaver ECS Module - Variables
# =============================================================================
# Variables pour la configuration du module ECS Fargate
#
# ORGANISATION:
# 1. Variables obligatoires (Required)
# 2. Configuration réseau et sécurité
# 3. Configuration des services et containers
# 4. Configuration des images Docker
# 5. Configuration auto-scaling
# 6. Secrets et variables d'environnement
# 7. Monitoring et logging
# 8. Tags et métadonnées
#
# ATTENTION AUX TYPES:
# - Toujours spécifier le type exact (string, number, bool, list, map, object)
# - Validation stricte des formats (regex, contains, etc.)
# - Valeurs par défaut sensées selon l'environnement
# - Documentation claire de chaque variable
# =============================================================================

# =============================================================================
# 1. VARIABLES OBLIGATOIRES - Doivent être fournies par l'appelant
# =============================================================================

variable "project_name" {
  description = <<-EOT
    Nom du projet AccessWeaver (utilisé pour nommer les ressources).

    Exemple: "accessweaver"

    Ce nom sera utilisé comme préfixe pour:
    - ECS Cluster: accessweaver-prod-cluster
    - Services: accessweaver-prod-aw-api-gateway
    - Task definitions: accessweaver-prod-aw-pdp-service
    - Security groups: accessweaver-prod-ecs-services-sg-xxx
    - CloudWatch logs: /ecs/accessweaver-prod/aw-api-gateway
  EOT
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
    - dev: Ressources minimales, 1 instance par service, Container Insights OFF
    - staging: Ressources moyennes, 1-2 instances, Container Insights ON
    - prod: Ressources robustes, 2-10 instances, toutes optimisations ON

    Cette variable influence automatiquement:
    - CPU/Memory allocation par service
    - Nombre d'instances min/max
    - Configuration auto-scaling
    - Stratégies de déploiement
    - Logging et monitoring
  EOT
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être exactement: dev, staging ou prod."
  }
}

variable "vpc_id" {
  description = <<-EOT
    ID du VPC où déployer le cluster ECS.

    Le VPC doit avoir:
    - Au moins 2 subnets privés dans des AZ différentes
    - Route tables configurées pour accès internet via NAT Gateway
    - DNS hostnames et resolution activés
    - Security groups configurés pour RDS et Redis

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
    Liste des IDs des subnets privés pour déployer les services ECS.

    Exigences:
    - Minimum 2 subnets pour la haute disponibilité
    - Subnets dans des AZ différentes
    - Subnets privés uniquement (pas d'IP publique)
    - Route vers NAT Gateway pour accès internet (Docker pulls, etc.)
    - Accès aux endpoints VPC pour AWS services (optionnel mais recommandé)

    Exemple: ["subnet-0123456789abcdef0", "subnet-fedcba9876543210f"]

    Note: Les services ECS Fargate seront déployés dans ces subnets
    avec des IP privées uniquement.
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

# =============================================================================
# 2. CONFIGURATION RÉSEAU ET SÉCURITÉ
# =============================================================================

variable "alb_security_group_ids" {
  description = <<-EOT
    Liste des security groups de l'Application Load Balancer.

    Ces security groups seront autorisés à accéder aux services ECS publics
    (typiquement aw-api-gateway) sur les ports 8080-8090.

    Exemple: ["sg-0123456789abcdef0"]

    Sécurité: Seuls ces security groups pourront atteindre les services
    exposés publiquement via l'ALB.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for sg_id in var.alb_security_group_ids :
      can(regex("^sg-[0-9a-f]{8,17}$", sg_id))
    ])
    error_message = "Tous les IDs de security group doivent être au format AWS standard: sg-xxxxxxxxx."
  }
}

variable "rds_security_group_id" {
  description = <<-EOT
    ID du security group de la base de données RDS PostgreSQL.

    Les services ECS auront accès à ce security group sur le port 5432
    pour les connexions à la base de données.

    Exemple: "sg-0123456789abcdef0"

    Intégration: Ce security group doit autoriser les connexions depuis
    le security group ECS créé par ce module.
  EOT
  type        = string

  validation {
    condition     = can(regex("^sg-[0-9a-f]{8,17}$", var.rds_security_group_id))
    error_message = "L'ID du security group RDS doit être au format AWS standard: sg-xxxxxxxxx."
  }
}

variable "redis_security_group_id" {
  description = <<-EOT
    ID du security group du cluster Redis ElastiCache.

    Les services ECS auront accès à ce security group sur le port 6379
    pour les connexions au cache Redis.

    Exemple: "sg-0123456789abcdef0"

    Intégration: Ce security group doit autoriser les connexions depuis
    le security group ECS créé par ce module.
  EOT
  type        = string

  validation {
    condition     = can(regex("^sg-[0-9a-f]{8,17}$", var.redis_security_group_id))
    error_message = "L'ID du security group Redis doit être au format AWS standard: sg-xxxxxxxxx."
  }
}

# =============================================================================
# 3. CONFIGURATION DES SERVICES ET CONTAINERS
# =============================================================================

variable "container_registry" {
  description = <<-EOT
    URL du registry Docker contenant les images AccessWeaver.

    Formats supportés:
    - ECR: 123456789012.dkr.ecr.eu-west-1.amazonaws.com
    - Docker Hub: docker.io/accessweaver
    - Registry privé: registry.company.com/accessweaver

    Les images attendues dans le registry:
    - aw-api-gateway:latest
    - aw-pdp-service:latest
    - aw-pap-service:latest
    - aw-tenant-service:latest
    - aw-audit-service:latest

    Exemple: "123456789012.dkr.ecr.eu-west-1.amazonaws.com/accessweaver"
  EOT
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+(/[a-zA-Z0-9._-]+)*$", var.container_registry))
    error_message = "L'URL du registry doit être un nom de domaine ou chemin valide."
  }
}

variable "image_tag" {
  description = <<-EOT
    Tag des images Docker à déployer.

    Stratégies de tagging recommandées:
    - dev: "latest" ou "develop" (builds continus)
    - staging: version semver (ex: "1.2.3-rc.1")
    - prod: version stable (ex: "1.2.3")

    Exemple: "1.0.0" ou "latest"

    Note: Éviter "latest" en production pour la traçabilité.
    Utiliser des tags immutables avec digest SHA si possible.
  EOT
  type        = string
  default     = "latest"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+$", var.image_tag))
    error_message = "Le tag Docker doit contenir uniquement des lettres, chiffres, points, tirets et underscores."
  }
}

variable "service_overrides" {
  description = <<-EOT
    Configuration personnalisée par service AccessWeaver.

    Permet d'override les valeurs par défaut pour des services spécifiques.

    Structure:
    {
      "aw-pdp-service" = {
        cpu           = 2048
        memory        = 4096
        desired_count = 3
        public        = false
      }
    }

    Services disponibles:
    - aw-api-gateway: Point d'entrée + auth JWT
    - aw-pdp-service: Policy Decision Point (intensive)
    - aw-pap-service: Policy Administration Point
    - aw-tenant-service: Gestion multi-tenancy
    - aw-audit-service: Logging et compliance

    Note: Les valeurs non spécifiées utilisent les defaults par environnement.
  EOT
  type = map(object({
    cpu           = optional(number)
    memory        = optional(number)
    desired_count = optional(number)
    public        = optional(bool)
  }))
  default = {}

  validation {
    condition = alltrue([
      for service_name, config in var.service_overrides :
      contains([
        "aw-api-gateway",
        "aw-pdp-service",
        "aw-pap-service",
        "aw-tenant-service",
        "aw-audit-service"
      ], service_name)
    ])
    error_message = "Les noms de service doivent être: aw-api-gateway, aw-pdp-service, aw-pap-service, aw-tenant-service, aw-audit-service."
  }

  validation {
    condition = alltrue([
      for service_name, config in var.service_overrides :
      config.cpu == null || (config.cpu >= 256 && config.cpu <= 4096)
      ])
    error_message = "CPU doit être entre 256 et 4096 (ou null pour utiliser les defaults)."
  }

  validation {
    condition = alltrue([
      for service_name, config in var.service_overrides :
      config.memory == null || (config.memory >= 512 && config.memory <= 8192)
      ])
    error_message = "Memory doit être entre 512 MB et 8192 MB (ou null pour utiliser les defaults)."
  }
}

# =============================================================================
# 4. CONFIGURATION AUTO-SCALING
# =============================================================================

variable "auto_scaling_enabled" {
  description = <<-EOT
    Active l'auto-scaling automatique des services ECS.

    Quand activé:
    - Scaling basé sur CPU et mémoire
    - Métriques CloudWatch monitoring
    - Scale-out rapide, scale-in conservateur
    - Seuils adaptés à l'environnement

    Désactiver pour:
    - Environnements de dev/test stables
    - Coûts prévisibles
    - Debugging plus facile

    Recommandation: true en staging/prod, false en dev.
  EOT
  type        = bool
  default     = true
}

variable "scaling_cpu_target" {
  description = <<-EOT
    Seuil CPU cible pour l'auto-scaling (pourcentage).

    Seuils recommandés:
    - dev: 80-90% (économique)
    - staging: 70-80% (test réaliste)
    - prod: 60-70% (réactivité)

    Fonctionnement:
    - Si CPU > seuil pendant 5min → scale out
    - Si CPU < seuil pendant 5min → scale in (plus lent)

    Note: Valeur trop basse = coût élevé
          Valeur trop haute = latence utilisateur
  EOT
  type        = number
  default     = 70

  validation {
    condition     = var.scaling_cpu_target >= 30 && var.scaling_cpu_target <= 90
    error_message = "Le seuil CPU doit être entre 30% et 90%."
  }
}

variable "scaling_memory_target" {
  description = <<-EOT
    Seuil mémoire cible pour l'auto-scaling (pourcentage).

    Généralement plus élevé que CPU car:
    - Moins volatile que CPU
    - OOM kills sont critiques
    - Applications Java ont des patterns prévisibles

    Recommandation: 80% (donne une marge de sécurité)

    Note: Services Java avec cache peuvent avoir des pics mémoire,
    surveiller les métriques avant d'ajuster.
  EOT
  type        = number
  default     = 80

  validation {
    condition     = var.scaling_memory_target >= 50 && var.scaling_memory_target <= 95
    error_message = "Le seuil mémoire doit être entre 50% et 95%."
  }
}

variable "min_capacity_override" {
  description = <<-EOT
    Nombre minimum d'instances par service (override les defaults par environnement).

    Defaults par environnement:
    - dev: 1 (économique)
    - staging: 1 (suffisant pour tests)
    - prod: 2 (haute disponibilité)

    Considérations:
    - Min = 1: Single point of failure possible
    - Min = 2: HA basique (recommandé prod)
    - Min = 3+: HA forte (services critiques uniquement)

    Coût: Multiplicateur direct sur les ressources.
  EOT
  type        = number
  default     = null

  validation {
    condition     = var.min_capacity_override == null || (var.min_capacity_override >= 1 && var.min_capacity_override <= 10)
    error_message = "La capacité minimum doit être entre 1 et 10 instances."
  }
}

variable "max_capacity_override" {
  description = <<-EOT
    Nombre maximum d'instances par service (override les defaults par environnement).

    Defaults par environnement:
    - dev: 2 (limite les coûts)
    - staging: 4 (test du scaling)
    - prod: 10 (scaling agressif)

    Considérations:
    - Limite les coûts en cas de scaling excessif
    - Doit être suffisant pour les pics de charge
    - Coordonner avec les limites ALB/RDS

    Note: Augmenter si les métriques montrent une saturation.
  EOT
  type        = number
  default     = null

  validation {
    condition     = var.max_capacity_override == null || (var.max_capacity_override >= 1 && var.max_capacity_override <= 50)
    error_message = "La capacité maximum doit être entre 1 et 50 instances."
  }
}

# =============================================================================
# 5. SECRETS ET VARIABLES D'ENVIRONNEMENT
# =============================================================================

variable "common_environment_variables" {
  description = <<-EOT
    Variables d'environnement communes à tous les services AccessWeaver.

    Variables typiques:
    {
      "SPRING_PROFILES_ACTIVE" = "prod"
      "JAVA_OPTS" = "-Xmx1g -XX:+UseG1GC"
      "LOG_LEVEL" = "INFO"
      "MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE" = "health,info,metrics"
    }

    Ces variables seront ajoutées à tous les containers en plus
    des variables spécifiques à chaque service.

    Note: Ne pas inclure de secrets ici (utiliser AWS Secrets Manager).
  EOT
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for key, value in var.common_environment_variables :
      can(regex("^[A-Z][A-Z0-9_]*$", key))
    ])
    error_message = "Les noms de variables d'environnement doivent être en UPPERCASE avec underscores."
  }
}

variable "secrets_manager_region" {
  description = <<-EOT
    Région AWS où sont stockés les secrets dans AWS Secrets Manager.

    Par défaut, utilise la région courante du provider Terraform.

    Secrets attendus:
    - {project_name}/{environment}/database:password
    - {project_name}/{environment}/redis:auth_token
    - {project_name}/{environment}/jwt:secret

    Exemple: "eu-west-1"

    Note: Les secrets doivent être créés avant le déploiement ECS.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.secrets_manager_region == null || can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.secrets_manager_region))
    error_message = "La région doit être au format AWS standard: eu-west-1, us-east-1, etc."
  }
}

# =============================================================================
# 6. INTÉGRATION ALB ET LOAD BALANCING
# =============================================================================

variable "target_group_arns" {
  description = <<-EOT
    ARNs des target groups ALB pour les services publics.

    Map service_name → target_group_arn pour les services exposés:
    {
      "aw-api-gateway" = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:targetgroup/aw-api-gateway/1234567890123456"
    }

    Seuls les services marqués "public = true" nécessitent un target group.

    Note: Les target groups doivent être créés par le module ALB
    avant le déploiement des services ECS.
  EOT
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for service_name, arn in var.target_group_arns :
      can(regex("^arn:aws:elasticloadbalancing:[a-z0-9-]+:[0-9]{12}:targetgroup/[a-zA-Z0-9-]+/[a-f0-9]+$", arn))
    ])
    error_message = "Les ARNs de target group doivent être au format AWS standard."
  }
}

variable "health_check_grace_period" {
  description = <<-EOT
    Délai en secondes avant que ALB commence les health checks.

    Permet aux services de démarrer complètement avant d'être marqués unhealthy.

    Valeurs recommandées:
    - Applications Spring Boot: 60-120s (démarrage JVM)
    - Applications natives: 30-60s
    - Applications avec warm-up: 120-300s

    Impact:
    - Trop court: Services marqués unhealthy pendant démarrage
    - Trop long: Détection lente des vrais problèmes

    Note: Cette valeur s'applique uniquement aux services publics avec ALB.
  EOT
  type        = number
  default     = 120

  validation {
    condition     = var.health_check_grace_period >= 30 && var.health_check_grace_period <= 600
    error_message = "Le délai de grâce doit être entre 30 et 600 secondes."
  }
}

# =============================================================================
# 7. MONITORING ET LOGGING
# =============================================================================

variable "container_insights_enabled" {
  description = <<-EOT
    Active Container Insights pour le monitoring avancé ECS.

    Container Insights fournit:
    - Métriques détaillées par service/tâche
    - Logs agrégés et searchables
    - Dashboards CloudWatch automatiques
    - Performance Monitoring

    Coût: ~$0.50 par GB de métriques ingérées

    Recommandation:
    - false: dev (économique)
    - true: staging/prod (observabilité)

    Note: Peut être activé/désactivé sans redéploiement.
  EOT
  type        = bool
  default     = null  # Sera déterminé par l'environnement
}

variable "log_retention_days" {
  description = <<-EOT
    Durée de rétention des logs CloudWatch en jours.

    Options valides: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653

    Recommandations par environnement:
    - dev: 7 jours (debug court terme)
    - staging: 14 jours (investigation)
    - prod: 30 jours (compliance et audit)

    Coût: ~$0.50/GB/mois pour le stockage

    Note: Logs d'audit peuvent nécessiter des durées plus longues.
  EOT
  type        = number
  default     = null  # Sera déterminé par l'environnement

  validation {
    condition = var.log_retention_days == null || contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "La rétention des logs doit être une valeur supportée par CloudWatch."
  }
}

variable "enable_xray_tracing" {
  description = <<-EOT
    Active le tracing distribué AWS X-Ray.

    X-Ray permet de:
    - Tracer les requêtes cross-services
    - Identifier les goulots d'étranglement
    - Analyser les performances end-to-end
    - Debug les erreurs distribuées

    Impact:
    - Overhead performance minimal (<1%)
    - Coût: $5/million de traces
    - Configuration additionnelle dans le code Java

    Recommandation: true pour staging/prod, false pour dev.
  EOT
  type        = bool
  default     = false
}

# =============================================================================
# 8. TAGS ET MÉTADONNÉES
# =============================================================================

variable "additional_tags" {
  description = <<-EOT
    Tags supplémentaires à appliquer à toutes les ressources ECS.

    Tags automatiques déjà appliqués:
    - Name: {project_name}-{environment}-{resource}
    - Project: {project_name}
    - Environment: {environment}
    - Component: compute
    - ManagedBy: terraform
    - Service: accessweaver-ecs

    Tags supplémentaires utiles:
    {
      CostCenter    = "Engineering"
      Owner         = "Platform Team"
      BusinessUnit  = "Product"
      Compliance    = "GDPR"
      BackupPolicy  = "None"  # ECS tasks sont stateless
      MonitoringLevel = "Enhanced"
    }

    Best practices:
    - Utiliser une convention cohérente
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
# 9. CONFIGURATION AVANCÉE (OPTIONNELLE)
# =============================================================================

variable "enable_fargate_spot" {
  description = <<-EOT
    Active l'utilisation de Fargate Spot pour réduire les coûts.

    Fargate Spot:
    - Économies jusqu'à 70% vs Fargate standard
    - Interruptions possibles avec préavis 2 minutes
    - Approprié pour services stateless et auto-healing

    Stratégie recommandée:
    - dev: 50% Spot (économique)
    - staging: 30% Spot (équilibre coût/stabilité)
    - prod: 0% Spot (stabilité maximale)

    Note: AccessWeaver étant stateless, Spot est généralement approprié.
  EOT
  type        = bool
  default     = null  # Sera déterminé par l'environnement
}

variable "deployment_circuit_breaker" {
  description = <<-EOT
    Active le circuit breaker pour les déploiements ECS.

    Circuit breaker:
    - Détecte les déploiements qui échouent
    - Rollback automatique vers version précédente
    - Évite les services down prolongés

    Utile pour:
    - Déploiements automatisés (CI/CD)
    - Services critiques
    - Équipes moins expérimentées avec ECS

    Recommandation: true pour prod, false pour dev/staging.
  EOT
  type        = bool
  default     = false
}

variable "enable_execute_command" {
  description = <<-EOT
    Active la possibilité d'exécuter des commandes dans les containers.

    ECS Exec permet:
    - Debugging interactif des containers
    - Accès shell pour investigation
    - Exécution de commandes ad-hoc

    Sécurité:
    - Nécessite des permissions IAM spécifiques
    - Logs d'audit automatiques
    - Sessions temporaires uniquement

    Recommandation: true pour dev/staging, false pour prod (sécurité).
  EOT
  type        = bool
  default     = false
}