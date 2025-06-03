# =============================================================================
# AccessWeaver Development Environment - Variables
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
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-1"
}

variable "version" {
  description = "Version tag for deployment"
  type        = string
  default     = "latest"
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

# =============================================================================
# Networking Configuration
# =============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "allowed_ips" {
  description = "List of allowed CIDR blocks for ALB access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Ouvert pour dev, à restreindre en production
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "dev.accessweaver.com"
}

# =============================================================================
# Database Configuration
# =============================================================================
# Configuration PostgreSQL optimisée pour Java 21

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
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20
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
  default     = "cache.t3.micro"
}

# =============================================================================
# Container Configuration
# =============================================================================

variable "ecr_repository_url" {
  description = "URL of the ECR repository"
  type        = string
}

# Variable image_tag déjà définie dans la section General Configuration

# =============================================================================
# Java 21 Configuration
# =============================================================================

variable "java_opts" {
  description = "Options JVM pour Java 21"
  type        = string
  default     = "-Xms512m -Xmx1024m -XX:+UseG1GC -XX:+UseStringDeduplication -Djava.security.egd=file:/dev/./urandom"
}

variable "backend_repo_url" {
  description = "URL du repository backend"
  type        = string
  default     = "https://github.com/accessweaver/aw-backend.git"
}

variable "frontend_repo_url" {
  description = "URL du repository frontend"
  type        = string
  default     = "https://github.com/accessweaver/aw-frontend.git"
}

# =============================================================================
# Domain Configuration (Optional)
# =============================================================================

variable "custom_domain" {
  description = "Custom domain for the application"
  type        = string
  default     = null
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = null
}

# =============================================================================
# Monitoring Configuration
# =============================================================================

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
}

# =============================================================================
# Tags
# =============================================================================

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "AccessWeaver"
    Environment = "dev"
    ManagedBy   = "Terraform"
    CostCenter  = "Engineering"
  }
}