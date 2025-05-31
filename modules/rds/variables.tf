# =============================================================================
# AccessWeaver RDS Module - Variables
# =============================================================================

# =============================================================================
# Required Variables - Must be provided
# =============================================================================

variable "project_name" {
  description = "accessweaver"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Le nom du projet doit contenir uniquement des lettres minuscules, chiffres et tirets."
  }
}

variable "environment" {
  description = "Environnement de déploiement"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être : dev, staging ou prod."
  }
}

variable "vpc_id" {
  description = "ID du VPC où déployer la base de données"
  type        = string

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "L'ID du VPC doit commencer par 'vpc-'."
  }
}

variable "private_subnet_ids" {
  description = "Liste des IDs des subnets privés pour le DB subnet group (minimum 2 pour Multi-AZ)"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "Au moins 2 subnets privés sont requis pour la haute disponibilité."
  }
}

variable "allowed_security_groups" {
  description = "Liste des security groups autorisés à accéder à la base de données (typiquement ECS services)"
  type        = list(string)
  default     = []
}

# =============================================================================
# Database Configuration
# =============================================================================

variable "database_name" {
  description = "Nom de la base de données par défaut"
  type        = string
  default     = "accessweaver"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.database_name))
    error_message = "Le nom de la base de données doit commencer par une lettre et contenir uniquement des lettres, chiffres et underscores."
  }
}

variable "master_username" {
  description = "Nom d'utilisateur administrateur pour la base de données"
  type        = string
  default     = "postgres"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.master_username))
    error_message = "Le nom d'utilisateur doit commencer par une lettre et contenir uniquement des lettres, chiffres et underscores."
  }
}

variable "master_password" {
  description = "Mot de passe administrateur (si null, un mot de passe sera généré automatiquement)"
  type        = string
  default     = null
  sensitive   = true
}

# =============================================================================
# Security & Encryption
# =============================================================================

variable "kms_key_id" {
  description = "ID de la clé KMS pour le chiffrement (si null, utilise la clé par défaut AWS)"
  type        = string
  default     = null
}

# =============================================================================
# Monitoring & Alerting
# =============================================================================

variable "sns_topic_arn" {
  description = "ARN du topic SNS pour les alertes CloudWatch (optionnel)"
  type        = string
  default     = null
}

# =============================================================================
# Advanced Configuration (Optional)
# =============================================================================

variable "custom_parameter_group_parameters" {
  description = "Paramètres supplémentaires pour le parameter group PostgreSQL"
  type = list(object({
    name  = string
    value = string
  }))
  default = []

  validation {
    condition = alltrue([
      for param in var.custom_parameter_group_parameters :
      can(regex("^[a-zA-Z_][a-zA-Z0-9_.]*$", param.name))
    ])
    error_message = "Les noms des paramètres doivent être valides pour PostgreSQL."
  }
}

variable "enable_performance_insights" {
  description = "Activer Performance Insights (forcé à true en production)"
  type        = bool
  default     = null # Will be determined by environment
}

variable "backup_retention_period_override" {
  description = "Période de rétention des backups en jours (override la valeur par défaut de l'environnement)"
  type        = number
  default     = null

  validation {
    condition     = var.backup_retention_period_override == null || (var.backup_retention_period_override >= 1 && var.backup_retention_period_override <= 35)
    error_message = "La période de rétention doit être entre 1 et 35 jours."
  }
}

variable "maintenance_window_override" {
  description = "Fenêtre de maintenance (format: ddd:hh24:mi-ddd:hh24:mi, ex: sun:04:00-sun:05:00)"
  type        = string
  default     = null

  validation {
    condition     = var.maintenance_window_override == null || can(regex("^(mon|tue|wed|thu|fri|sat|sun):[0-2][0-9]:[0-5][0-9]-(mon|tue|wed|thu|fri|sat|sun):[0-2][0-9]:[0-5][0-9]$", var.maintenance_window_override))
    error_message = "La fenêtre de maintenance doit être au format : ddd:hh24:mi-ddd:hh24:mi (ex: sun:04:00-sun:05:00)."
  }
}

variable "backup_window_override" {
  description = "Fenêtre de backup (format: hh24:mi-hh24:mi, ex: 03:00-04:00)"
  type        = string
  default     = null

  validation {
    condition     = var.backup_window_override == null || can(regex("^[0-2][0-9]:[0-5][0-9]-[0-2][0-9]:[0-5][0-9]$", var.backup_window_override))
    error_message = "La fenêtre de backup doit être au format : hh24:mi-hh24:mi (ex: 03:00-04:00)."
  }
}

# =============================================================================
# Feature Flags
# =============================================================================

variable "enable_read_replica" {
  description = "Activer la création d'un read replica (automatique en staging/prod)"
  type        = bool
  default     = null # Will be determined by environment
}

variable "enable_deletion_protection" {
  description = "Activer la protection contre la suppression (forcé à true en production)"
  type        = bool
  default     = null # Will be determined by environment
}

variable "enable_enhanced_monitoring" {
  description = "Activer Enhanced Monitoring (automatique en production)"
  type        = bool
  default     = null # Will be determined by environment
}

# =============================================================================
# Cost Optimization
# =============================================================================

variable "instance_class_override" {
  description = "Type d'instance RDS (override la valeur par défaut de l'environnement)"
  type        = string
  default     = null

  validation {
    condition = var.instance_class_override == null || can(regex("^db\\.[a-z0-9]+\\.[a-z0-9]+$", var.instance_class_override))
    error_message = "Le type d'instance doit être au format db.type.size (ex: db.t3.micro)."
  }
}

variable "allocated_storage_override" {
  description = "Stockage alloué en GB (override la valeur par défaut de l'environnement)"
  type        = number
  default     = null

  validation {
    condition     = var.allocated_storage_override == null || (var.allocated_storage_override >= 20 && var.allocated_storage_override <= 65536)
    error_message = "Le stockage alloué doit être entre 20 GB et 65536 GB."
  }
}

# =============================================================================
# Tags additionnels
# =============================================================================

variable "additional_tags" {
  description = "Tags supplémentaires à appliquer aux ressources RDS"
  type        = map(string)
  default     = {}
}