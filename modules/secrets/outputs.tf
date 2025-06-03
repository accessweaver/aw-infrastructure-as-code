# =============================================================================
# AccessWeaver Secrets Module - Outputs
# =============================================================================

# =============================================================================
# Secret ARNs
# =============================================================================

output "database_secret_arn" {
  description = "ARN of the database secret"
  value       = aws_secretsmanager_secret.database.arn
}

output "redis_secret_arn" {
  description = "ARN of the Redis secret"
  value       = aws_secretsmanager_secret.redis.arn
}

output "jwt_secret_arn" {
  description = "ARN of the JWT secret"
  value       = aws_secretsmanager_secret.jwt.arn
}

output "api_keys_secret_arn" {
  description = "ARN of the API keys secret"
  value       = aws_secretsmanager_secret.api_keys.arn
}

output "tenant_encryption_secret_arn" {
  description = "ARN of the tenant encryption secret"
  value       = aws_secretsmanager_secret.tenant_encryption.arn
}

output "oauth_secret_arn" {
  description = "ARN of the OAuth secret (if configured)"
  value       = length(aws_secretsmanager_secret.oauth) > 0 ? aws_secretsmanager_secret.oauth[0].arn : null
}

# =============================================================================
# Secret Names
# =============================================================================

output "database_secret_name" {
  description = "Name of the database secret"
  value       = aws_secretsmanager_secret.database.name
}

output "redis_secret_name" {
  description = "Name of the Redis secret"
  value       = aws_secretsmanager_secret.redis.name
}

output "jwt_secret_name" {
  description = "Name of the JWT secret"
  value       = aws_secretsmanager_secret.jwt.name
}

output "api_keys_secret_name" {
  description = "Name of the API keys secret"
  value       = aws_secretsmanager_secret.api_keys.name
}

output "tenant_encryption_secret_name" {
  description = "Name of the tenant encryption secret"
  value       = aws_secretsmanager_secret.tenant_encryption.name
}

# =============================================================================
# IAM Policy ARN
# =============================================================================

output "secrets_read_policy_arn" {
  description = "ARN of the IAM policy for reading secrets"
  value       = aws_iam_policy.secrets_read.arn
}

output "rotation_lambda_role_arn" {
  description = "ARN of the Lambda execution role for secret rotation (if enabled)"
  value       = var.enable_rotation ? aws_iam_role.rotation_lambda[0].arn : null
}

# =============================================================================
# Configuration for Applications
# =============================================================================

output "spring_boot_config" {
  description = "Spring Boot configuration for AWS Secrets Manager"
  value = {
    aws_secretsmanager_enabled = true
    aws_secretsmanager_region  = data.aws_region.current.name

    database_secret_id = aws_secretsmanager_secret.database.name
    redis_secret_id    = aws_secretsmanager_secret.redis.name
    jwt_secret_id      = aws_secretsmanager_secret.jwt.name

    spring_config_import = "aws-secretsmanager:${aws_secretsmanager_secret.database.name},${aws_secretsmanager_secret.redis.name},${aws_secretsmanager_secret.jwt.name}"
  }
}

output "environment_variables" {
  description = "Environment variables for ECS tasks"
  value = {
    AWS_SECRETSMANAGER_REGION = data.aws_region.current.name
    DATABASE_SECRET_NAME      = aws_secretsmanager_secret.database.name
    REDIS_SECRET_NAME         = aws_secretsmanager_secret.redis.name
    JWT_SECRET_NAME           = aws_secretsmanager_secret.jwt.name
    API_KEYS_SECRET_NAME      = aws_secretsmanager_secret.api_keys.name
  }
}

# =============================================================================
# Secret Rotation Status
# =============================================================================

output "rotation_enabled" {
  description = "Whether secret rotation is enabled"
  value       = var.enable_rotation
}

output "rotation_configuration" {
  description = "Rotation configuration for secrets"
  value = {
    database_rotation_enabled = var.enable_rotation && var.environment == "prod"
    jwt_rotation_enabled      = var.enable_rotation && var.environment == "prod"
    rotation_days = {
      database = 30
      jwt      = 90
    }
  }
}