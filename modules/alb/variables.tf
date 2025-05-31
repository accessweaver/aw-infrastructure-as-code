# =============================================================================
# AccessWeaver ALB Module - Variables
# =============================================================================
# Variables pour la configuration du module Application Load Balancer
#
# ORGANISATION:
# 1. Variables obligatoires (Required)
# 2. Configuration réseau et sécurité
# 3. Configuration SSL/TLS et domaines
# 4. Configuration WAF et protection
# 5. Configuration health checks et target groups
# 6. Monitoring et logging
# 7. Tags et métadonnées
#
# ATTENTION AUX TYPES:
# - Types strictement définis (string, number, bool, list, map)
# - Validations robustes avec regex et contains
# - Valeurs par défaut adaptées à l'environnement
# - Documentation claire avec exemples
# =============================================================================

# =============================================================================
# 1. VARIABLES OBLIGATOIRES - Doivent être fournies par l'appelant
# =============================================================================

variable "project_name" {
  description = <<-EOT
    Nom du projet AccessWeaver (utilisé pour nommer les ressources).

    Exemple: "accessweaver"

    Ce nom sera utilisé comme préfixe pour:
    - Load balancer: accessweaver-prod-alb
    - Target groups: accessweaver-prod-api-gateway-tg
    - Security groups: accessweaver-prod-alb-sg-xxx
    - WAF Web ACL: accessweaver-prod-waf
    - S3 bucket logs: accessweaver-prod-alb-access-logs-xxx
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
    - dev: HTTP autorisé, WAF désactivé, logs désactivés, health checks permissifs
    - staging: HTTPS redirect, WAF activé, logs activés, health checks équilibrés
    - prod: HTTPS obligatoire, WAF avec toutes protections, logs complets, health checks stricts

    Cette variable influence automatiquement:
    - Politique SSL/TLS et redirections HTTPS
    - Configuration WAF et règles de protection
    - Fréquence et seuils des health checks
    - Activation des logs d'accès et monitoring
    - Protection contre suppression accidentelle
  EOT
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être exactement: dev, staging ou prod."
  }
}

variable "vpc_id" {
  description = <<-EOT
    ID du VPC où déployer l'Application Load Balancer.

    Le VPC doit avoir:
    - Au moins 2 subnets publics dans des AZ différentes
    - Internet Gateway configuré et attaché
    - Route tables configurées pour accès internet
    - DNS hostnames et resolution activés

    Exemple: "vpc-0123456789abcdef0"

    Note: L'ALB sera déployé dans les subnets publics pour être
    accessible depuis internet.
  EOT
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]{8,17}$", var.vpc_id))
    error_message = "L'ID du VPC doit être au format AWS standard: vpc-xxxxxxxxx."
  }
}

variable "public_subnet_ids" {
  description = <<-EOT
    Liste des IDs des subnets publics pour déployer l'ALB.

    Exigences:
    - Minimum 2 subnets pour la haute disponibilité
    - Subnets dans des AZ différentes
    - Subnets publics avec Internet Gateway
    - Route vers 0.0.0.0/0 via Internet Gateway

    Exemple: ["subnet-0123456789abcdef0", "subnet-fedcba9876543210f"]

    Note: L'ALB sera accessible depuis internet via ces subnets.
    Les instances ECS restent dans les subnets privés.
  EOT
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "Au moins 2 subnets publics sont requis pour la haute disponibilité Multi-AZ."
  }

  validation {
    condition = alltrue([
      for subnet_id in var.public_subnet_ids :
      can(regex("^subnet-[0-9a-f]{8,17}$", subnet_id))
    ])
    error_message = "Tous les IDs de subnet doivent être au format AWS standard: subnet-xxxxxxxxx."
  }
}

variable "ecs_security_group_id" {
  description = <<-EOT
    ID du security group des services ECS.

    L'ALB aura accès à ce security group sur les ports 8080-8090
    pour router le trafic vers les services AccessWeaver.

    Exemple: "sg-0123456789abcdef0"

    Intégration: Ce security group doit autoriser les connexions depuis
    le security group ALB créé par ce module.

    Source: Module ECS → output security_group_id
  EOT
  type        = string

  validation {
    condition     = can(regex("^sg-[0-9a-f]{8,17}$", var.ecs_security_group_id))
    error_message = "L'ID du security group ECS doit être au format AWS standard: sg-xxxxxxxxx."
  }
}

# =============================================================================
# 2. CONFIGURATION RÉSEAU ET SÉCURITÉ
# =============================================================================

variable "allowed_cidr_blocks" {
  description = <<-EOT
    Liste des blocs CIDR autorisés à accéder à l'ALB depuis internet.

    Exemples:
    - Accès global: ["0.0.0.0/0"]
    - Accès restreint: ["203.0.113.0/24", "198.51.100.0/24"]
    - Bureau + VPN: ["203.0.113.0/24", "10.0.0.0/8"]

    Sécurité:
    - dev: Généralement ouvert (0.0.0.0/0) pour faciliter les tests
    - staging: Restreint aux bureaux et partenaires
    - prod: Ouvert ou restreint selon les besoins métier

    Note: WAF fournit une protection supplémentaire au niveau application.
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = alltrue([
      for cidr in var.allowed_cidr_blocks :
      can(cidrhost(cidr, 0))
    ])
    error_message = "Tous les CIDR blocks doivent être au format valide (ex: 10.0.0.0/8, 0.0.0.0/0)."
  }
}

# =============================================================================
# 3. CONFIGURATION SSL/TLS ET DOMAINES
# =============================================================================

variable "custom_domain" {
  description = <<-EOT
    Nom de domaine personnalisé pour AccessWeaver.

    Si fourni, un certificat SSL sera créé automatiquement via ACM
    et un enregistrement Route 53 sera configuré.

    Format par environnement:
    - dev: dev.{custom_domain} (ex: dev.accessweaver.com)
    - staging: staging.{custom_domain} (ex: staging.accessweaver.com)
    - prod: {custom_domain} (ex: accessweaver.com)

    Exemple: "accessweaver.com"

    Prérequis:
    - Domaine géré dans Route 53 (zone_id requis)
    - Validation DNS automatique du certificat ACM

    Si null, l'ALB sera accessible uniquement via son DNS AWS.
  EOT
  type        = string
  default     = null

  validation {
    condition = var.custom_domain == null || can(regex(
      "^([a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]{2,}$",
      var.custom_domain
    ))
    error_message = "Le domaine doit être un nom de domaine valide (ex: accessweaver.com)."
  }
}

variable "route53_zone_id" {
  description = <<-EOT
    ID de la zone Route 53 pour créer l'enregistrement DNS.

    Requis uniquement si custom_domain est fourni.

    Exemple: "Z123456789ABCDEF012345"

    Pour trouver l'ID:
    aws route53 list-hosted-zones --query 'HostedZones[?Name==`accessweaver.com.`].Id' --output text

    Note: L'enregistrement DNS sera créé automatiquement
    avec un alias vers l'ALB.
  EOT
  type        = string
  default     = null

  validation {
    condition = var.route53_zone_id == null || can(regex(
      "^Z[A-Z0-9]{10,32}$",
      var.route53_zone_id
    ))
    error_message = "L'ID de zone Route 53 doit être au format AWS standard: Z1234567890ABCDEF."
  }
}

variable "certificate_alternative_names" {
  description = <<-EOT
    Noms alternatifs (SAN) pour le certificat SSL.

    Utilisé pour inclure des sous-domaines ou domaines additionnels
    dans le même certificat SSL.

    Exemples:
    - Wildcard: ["*.accessweaver.com"]
    - Multi-domaines: ["api.accessweaver.com", "admin.accessweaver.com"]
    - Ancien domaine: ["old-domain.com"]

    Note: Validation DNS requise pour chaque domaine.
    Tous les domaines doivent être dans la même zone Route 53.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for domain in var.certificate_alternative_names :
      can(regex("^(\\*\\.)?([a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]{2,}$", domain))
    ])
    error_message = "Tous les noms alternatifs doivent être des domaines valides (supportent wildcard: *.example.com)."
  }
}

variable "ssl_policy" {
  description = <<-EOT
    Politique SSL/TLS pour le listener HTTPS de l'ALB.

    Politiques disponibles:
    - ELBSecurityPolicy-TLS-1-2-2017-01: TLS 1.2+ (recommandé)
    - ELBSecurityPolicy-TLS-1-3-2021-06: TLS 1.3+ (plus récent)
    - ELBSecurityPolicy-FS-1-2-Res-2020-10: Forward Secrecy

    Recommandations:
    - dev/staging: TLS 1.2 (compatibilité)
    - prod: TLS 1.3 (sécurité maximale)

    Note: TLS 1.3 peut causer des problèmes avec anciens clients.
  EOT
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"

  validation {
    condition = contains([
      "ELBSecurityPolicy-TLS-1-2-2017-01",
      "ELBSecurityPolicy-TLS-1-3-2021-06",
      "ELBSecurityPolicy-FS-1-2-Res-2020-10",
      "ELBSecurityPolicy-FS-1-1-2019-08",
      "ELBSecurityPolicy-2016-08"
    ], var.ssl_policy)
    error_message = "La politique SSL doit être une politique ALB supportée par AWS."
  }
}

# =============================================================================
# 4. CONFIGURATION WAF ET PROTECTION
# =============================================================================

variable "enable_waf" {
  description = <<-EOT
    Active AWS WAF pour protection contre les attaques web.

    Valeur par défaut: automatique selon l'environnement
    - dev: false (économique, pas de menaces)
    - staging: true (test des règles)
    - prod: true (protection maximale)

    WAF inclut:
    - Protection contre attaques OWASP Top 10
    - Rate limiting par IP
    - Réputation IP Amazon
    - Règles custom selon besoins

    Coût: ~$5/mois + $1 par million de requêtes

    Note: Peut être activé/désactivé sans redéploiement ALB.
  EOT
  type        = bool
  default     = null  # Sera déterminé par l'environnement
}

variable "waf_rate_limit" {
  description = <<-EOT
    Limite de requêtes par IP par 5 minutes pour WAF.

    Seuils recommandés:
    - API publique: 2000-5000 (usage normal d'une application)
    - API interne: 10000+ (plus permissif)
    - Protection DDoS: 100-500 (très strict)

    Considérations:
    - Trop bas: Risque de bloquer utilisateurs légitimes
    - Trop haut: Protection DDoS limitée
    - Adapter selon les patterns d'usage AccessWeaver

    Note: S'applique par IP source, pas par utilisateur authentifié.
  EOT
  type        = number
  default     = 2000

  validation {
    condition     = var.waf_rate_limit >= 100 && var.waf_rate_limit <= 20000
    error_message = "La limite de taux WAF doit être entre 100 et 20000 requêtes par 5 minutes."
  }
}

variable "waf_whitelist_ips" {
  description = <<-EOT
    Liste d'adresses IP whitelistées (exemptées du WAF).

    Utilisé pour:
    - IPs de monitoring (Pingdom, StatusCake, etc.)
    - IPs d'administration (bureaux, VPN)
    - IPs de partenaires critiques
    - Load testing depuis IPs spécifiques

    Format: ["203.0.113.1/32", "198.51.100.0/24"]

    Sécurité: Utiliser avec parcimonie.
    Préférer l'authentification forte à la whitelist IP.

    Note: /32 pour IP unique, /24 pour subnet.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for ip in var.waf_whitelist_ips :
      can(cidrhost(ip, 0))
    ])
    error_message = "Toutes les IPs whitelist doivent être au format CIDR valide (ex: 203.0.113.1/32)."
  }
}

variable "enable_ddos_protection" {
  description = <<-EOT
    Active AWS Shield Advanced pour protection DDoS avancée.

    AWS Shield Standard (gratuit) est toujours activé.
    AWS Shield Advanced apporte:
    - Protection DDoS sophistiquée
    - Support 24/7 DRT (DDoS Response Team)
    - Protection des coûts liés aux attaques
    - Visibilité avancée et reporting

    Coût: $3000/mois + coûts des ressources protégées

    Recommandation: false sauf entreprises avec risque DDoS élevé.
  EOT
  type        = bool
  default     = false
}

# =============================================================================
# 5. CONFIGURATION HEALTH CHECKS ET TARGET GROUPS
# =============================================================================

variable "health_check_path" {
  description = <<-EOT
    Path de health check pour les target groups.

    Par défaut utilise l'endpoint Spring Boot Actuator.

    Endpoints Spring Boot disponibles:
    - /actuator/health: État général (recommandé)
    - /actuator/health/readiness: Prêt à recevoir du trafic
    - /actuator/health/liveness: Service en vie
    - /api/v1/health: Custom health check AccessWeaver

    Le endpoint doit:
    - Répondre 200 OK quand le service est healthy
    - Être rapide (< 1 seconde)
    - Vérifier les dépendances critiques (DB, Redis)

    Exemple: "/actuator/health"
  EOT
  type        = string
  default     = "/actuator/health"

  validation {
    condition     = can(regex("^/[a-zA-Z0-9/_.-]*$", var.health_check_path))
    error_message = "Le path de health check doit commencer par '/' et contenir uniquement des caractères valides pour URL."
  }
}

variable "health_check_interval" {
  description = <<-EOT
    Intervalle entre les health checks en secondes.

    Valeurs par défaut adaptatives:
    - dev: 30s (moins de charge sur services)
    - staging: 30s (équilibré)
    - prod: 15s (détection rapide des problèmes)

    Considérations:
    - Plus court: Détection rapide, plus de charge
    - Plus long: Moins de charge, détection lente

    Range AWS: 5-300 secondes
  EOT
  type        = number
  default     = null  # Sera déterminé par l'environnement

  validation {
    condition     = var.health_check_interval == null || (var.health_check_interval >= 5 && var.health_check_interval <= 300)
    error_message = "L'intervalle de health check doit être entre 5 et 300 secondes."
  }
}

variable "health_check_timeout" {
  description = <<-EOT
    Timeout pour les health checks en secondes.

    Doit être inférieur à l'intervalle de health check.

    Valeurs recommandées:
    - Applications rapides: 5s
    - Applications Spring Boot: 10s (démarrage JVM)
    - Applications avec DB queries: 15s

    Note: Timeout trop long retarde la détection de problèmes.
    Timeout trop court peut causer des false positives.
  EOT
  type        = number
  default     = null  # Sera déterminé par l'environnement

  validation {
    condition     = var.health_check_timeout == null || (var.health_check_timeout >= 2 && var.health_check_timeout <= 120)
    error_message = "Le timeout de health check doit être entre 2 et 120 secondes."
  }
}

variable "healthy_threshold" {
  description = <<-EOT
    Nombre de health checks successifs requis pour marquer une cible healthy.

    Valeurs recommandées:
    - dev: 2 (démarrage rapide)
    - staging: 2 (équilibré)
    - prod: 2 (standard)

    Plus élevé = Plus conservateur (évite les faux positifs)
    Plus bas = Plus réactif (mise en service rapide)

    Range AWS: 2-10
  EOT
  type        = number
  default     = 2

  validation {
    condition     = var.healthy_threshold >= 2 && var.healthy_threshold <= 10
    error_message = "Le seuil healthy doit être entre 2 et 10."
  }
}

variable "unhealthy_threshold" {
  description = <<-EOT
    Nombre de health checks échoués requis pour marquer une cible unhealthy.

    Valeurs recommandées:
    - dev: 3 (tolérant aux problèmes temporaires)
    - staging: 3 (équilibré)
    - prod: 2 (détection rapide des problèmes)

    Plus élevé = Plus tolérant (évite les faux négatifs)
    Plus bas = Plus strict (isolation rapide des problèmes)

    Range AWS: 2-10
  EOT
  type        = number
  default     = null  # Sera déterminé par l'environnement

  validation {
    condition     = var.unhealthy_threshold == null || (var.unhealthy_threshold >= 2 && var.unhealthy_threshold <= 10)
    error_message = "Le seuil unhealthy doit être entre 2 et 10."
  }
}

variable "deregistration_delay" {
  description = <<-EOT
    Délai en secondes avant qu'une cible soit complètement désenregistrée.

    Pendant ce délai:
    - Nouvelles connexions non routées vers la cible
    - Connexions existantes peuvent continuer
    - Permet de terminer les requêtes en cours proprement

    Valeurs recommandées:
    - API stateless: 30s (AccessWeaver avec JWT)
    - API avec sessions: 300s
    - Long polling: 600s

    Range AWS: 0-3600 secondes
  EOT
  type        = number
  default     = 30

  validation {
    condition     = var.deregistration_delay >= 0 && var.deregistration_delay <= 3600
    error_message = "Le délai de déregistration doit être entre 0 et 3600 secondes."
  }
}

# =============================================================================
# 6. MONITORING ET LOGGING
# =============================================================================

variable "enable_access_logs" {
  description = <<-EOT
    Active les logs d'accès ALB vers S3.

    Valeur par défaut: automatique selon l'environnement
    - dev: false (économique, pas critique)
    - staging: true (debugging et test)
    - prod: true (audit et compliance)

    Les logs incluent:
    - Timestamp, IP client, latence
    - URL, user agent, response code
    - Taille de la requête/réponse
    - SSL cipher, protocole

    Coût: ~$0.023/GB stocké + requêtes PUT S3

    Utilisation: Analyse de trafic, debugging, security audit.
  EOT
  type        = bool
  default     = null  # Sera déterminé par l'environnement
}

variable "access_logs_retention_days" {
  description = <<-EOT
    Durée de rétention des logs d'accès ALB en jours.

    Lifecycle S3 configuré automatiquement:
    - 0-30 jours: Standard storage
    - 30-90 jours: Standard-IA (économique)
    - 90+ jours: Glacier (archive)
    - Suppression après rétention configurée

    Recommandations:
    - dev: 7-30 jours (debugging court terme)
    - staging: 30-90 jours (analyse patterns)
    - prod: 90-365 jours (compliance et audit)

    Considérer les exigences légales/compliance.
  EOT
  type        = number
  default     = 90

  validation {
    condition     = var.access_logs_retention_days >= 1 && var.access_logs_retention_days <= 3653
    error_message = "La rétention des logs doit être entre 1 et 3653 jours (10 ans)."
  }
}

variable "sns_topic_arn" {
  description = <<-EOT
    ARN du topic SNS pour les alertes CloudWatch.

    Si fourni, des alertes seront envoyées pour:
    - Response time élevé (> seuil selon environnement)
    - Taux d'erreur 5xx élevé (> 10 erreurs/5min)
    - Target group unhealthy
    - WAF blocked requests (si activé)

    Exemple: "arn:aws:sns:eu-west-1:123456789012:accessweaver-alerts"

    Configuration recommandée:
    - Email pour alertes critiques
    - Slack/Teams pour informations
    - PagerDuty pour prod
  EOT
  type        = string
  default     = null

  validation {
    condition = var.sns_topic_arn == null || can(regex(
      "^arn:aws:sns:[a-z0-9-]+:[0-9]{12}:[a-zA-Z0-9_-]+$",
      var.sns_topic_arn
    ))
    error_message = "L'ARN du topic SNS doit être au format AWS standard."
  }
}

# =============================================================================
# 7. TAGS ET MÉTADONNÉES
# =============================================================================

variable "additional_tags" {
  description = <<-EOT
    Tags supplémentaires à appliquer à toutes les ressources ALB.

    Tags automatiques déjà appliqués:
    - Name: {project_name}-{environment}-{resource}
    - Project: {project_name}
    - Environment: {environment}
    - Component: load-balancer
    - ManagedBy: terraform
    - Service: accessweaver-alb
    - Purpose: public-api-gateway

    Tags supplémentaires utiles:
    {
      CostCenter    = "Engineering"
      Owner         = "Platform Team"
      BusinessUnit  = "Product"
      Compliance    = "GDPR"
      BackupPolicy  = "NotRequired"  # ALB est stateless
      MonitoringLevel = "Enhanced"
      PublicFacing  = "true"
    }

    Best practices:
    - Inclure les informations de coût/facturation
    - Ajouter les contacts techniques
    - Spécifier les exigences de compliance
    - Marquer les ressources publiques
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
# 8. CONFIGURATION AVANCÉE (OPTIONNELLE)
# =============================================================================

variable "idle_timeout" {
  description = <<-EOT
    Timeout d'inactivité pour les connexions ALB en secondes.

    Après ce délai, l'ALB ferme les connexions inactives.

    Valeurs recommandées:
    - API REST courtes: 60s (défaut AWS)
    - Long polling: 300-600s
    - WebSocket: 3600s (1 heure)
    - File upload: 300-600s

    AccessWeaver étant une API REST classique, 60s est approprié.

    Range AWS: 1-4000 secondes
  EOT
  type        = number
  default     = 60

  validation {
    condition     = var.idle_timeout >= 1 && var.idle_timeout <= 4000
    error_message = "Le timeout d'inactivité doit être entre 1 et 4000 secondes."
  }
}

variable "enable_cross_zone_load_balancing" {
  description = <<-EOT
    Active le load balancing cross-zone.

    Quand activé:
    - Trafic distribué uniformément entre toutes les cibles
    - Même si les AZ ont un nombre différent de cibles
    - Améliore la distribution de charge

    Coût: Transfert de données cross-AZ facturé

    Recommandation:
    - false: dev (économique)
    - true: staging/prod (performance)
  EOT
  type        = bool
  default     = null  # Sera déterminé par l'environnement
}

variable "enable_http2" {
  description = <<-EOT
    Active le support HTTP/2 sur l'ALB.

    HTTP/2 apporte:
    - Multiplexing des requêtes
    - Compression des headers
    - Server push (non utilisé par AccessWeaver)
    - Meilleure performance pour clients modernes

    Compatibilité:
    - Tous les navigateurs modernes
    - Clients REST modernes (curl, httpie, etc.)
    - Fallback HTTP/1.1 automatique

    Recommandation: true (pas d'inconvénient)
  EOT
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = <<-EOT
    Active la protection contre la suppression accidentelle.

    Quand activé:
    - Impossible de supprimer l'ALB via console/API/CLI
    - Doit être désactivé avant suppression
    - Protection contre erreurs humaines

    Valeur par défaut: automatique selon l'environnement
    - dev: false (flexibilité pour expérimentation)
    - staging: false (environments temporaires)
    - prod: true (protection critique)

    Note: N'empêche pas la suppression via Terraform destroy.
  EOT
  type        = bool
  default     = null  # Sera déterminé par l'environnement
}