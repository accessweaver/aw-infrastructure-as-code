# =============================================================================
# AccessWeaver Staging Environment - Variables
# =============================================================================

# =============================================================================
# General Configuration
# =============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "accessweaver"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-1"
}

# =============================================================================
# Networking Configuration
# =============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.1.0.0/16"  # Different CIDR from dev
}

variable "allowed_ip_ranges" {
  description = "List of allowed CIDR blocks for ALB access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Should be restricted in actual usage
}

# =============================================================================
# Database Configuration
# =============================================================================

variable "database_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "accessweaver"
}

variable "database_username" {
  description = "Master username for the database"
  type        = string
  default     = "postgres"
}

variable "database_password" {
  description = "Master password for the database"
  type        = string
  sensitive   = true
}

variable "rds_instance_class" {
  description = "Instance class for RDS"
  type        = string
  default     = "db.t3.small"  # Upgraded from dev
}

variable "rds_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 50  # Increased from dev
}

# =============================================================================
# Redis Configuration
# =============================================================================

variable "redis_auth_token" {
  description = "Auth token for Redis"
  type        = string
  sensitive   = true
}

variable "redis_node_type" {
  description = "Node type for Redis"
  type        = string
  default     = "cache.t3.small"  # Upgraded from dev
}

# =============================================================================
# Container Configuration
# =============================================================================

variable "ecr_repository_url" {
  description = "URL of the ECR repository"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

# =============================================================================
# Domain Configuration
# =============================================================================

variable "custom_domain" {
  description = "Custom domain for the application"
  type        = string
  default     = "staging.accessweaver.com"
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
}

# =============================================================================
# Monitoring Configuration
# =============================================================================

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for alerts"
  type        = string
  default     = null
}

# =============================================================================
# Deployment Configuration
# =============================================================================

variable "version" {
  description = "Version tag for deployment"
  type        = string
  default     = "latest"
}

# =============================================================================
# Tags
# =============================================================================

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "AccessWeaver"
    Environment = "staging"
    ManagedBy   = "Terraform"
    CostCenter  = "Engineering"
  }
}
