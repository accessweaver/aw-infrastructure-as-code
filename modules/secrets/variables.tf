# =============================================================================
# AccessWeaver Secrets Module - Variables
# =============================================================================

# =============================================================================
# Required Variables
# =============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# =============================================================================
# Database Configuration
# =============================================================================

variable "database_endpoint" {
  description = "RDS database endpoint"
  type        = string
}

variable "database_port" {
  description = "RDS database port"
  type        = number
  default     = 5432
}

variable "database_name" {
  description = "Database name"
  type        = string
}

variable "database_username" {
  description = "Database master username"
  type        = string
}

variable "database_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

# =============================================================================
# Redis Configuration
# =============================================================================

variable "redis_endpoint" {
  description = "Redis endpoint"
  type        = string
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "redis_auth_token" {
  description = "Redis auth token"
  type        = string
  sensitive   = true
}

variable "redis_ssl_enabled" {
  description = "Whether Redis SSL is enabled"
  type        = bool
  default     = true
}

# =============================================================================
# JWT Configuration
# =============================================================================

variable "jwt_secret" {
  description = "JWT signing secret (generated if null)"
  type        = string
  default     = null
  sensitive   = true
}

variable "jwt_expiration_seconds" {
  description = "JWT token expiration in seconds"
  type        = number
  default     = 3600  # 1 hour

  validation {
    condition     = var.jwt_expiration_seconds >= 300 && var.jwt_expiration_seconds <= 86400
    error_message = "JWT expiration must be between 5 minutes and 24 hours."
  }
}

# =============================================================================
# API Keys and External Services
# =============================================================================

variable "api_keys" {
  description = "Map of external API keys"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "oauth_providers" {
  description = "OAuth provider configurations"
  type = map(object({
    client_id     = string
    client_secret = string
    issuer        = string
    scopes        = list(string)
  }))
  default   = {}
  sensitive = true
}

# =============================================================================
# Secret Management Configuration
# =============================================================================

variable "recovery_window_days" {
  description = "Number of days before a secret can be deleted"
  type        = number
  default     = 7

  validation {
    condition     = var.recovery_window_days >= 7 && var.recovery_window_days <= 30
    error_message = "Recovery window must be between 7 and 30 days."
  }
}

variable "enable_rotation" {
  description = "Enable automatic secret rotation"
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "KMS key ID for secret encryption (uses default if null)"
  type        = string
  default     = null
}

# =============================================================================
# Tags
# =============================================================================

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}