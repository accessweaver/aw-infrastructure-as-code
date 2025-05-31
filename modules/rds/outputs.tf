# =============================================================================
# AccessWeaver RDS Module - Outputs
# =============================================================================

# =============================================================================
# Database Connection Information
# =============================================================================

# =============================================================================
# Secrets Manager Integration (pour les applications)
# =============================================================================

output "secrets_manager_integration" {
  description = "Configuration pour AWS Secrets Manager (recommandé pour les applications)"
  value = {
    secret_name_suggestion = "${var.project_name}/${var.environment}/rds/master-credentials"
    secret_structure = {
      engine   = "postgres"
      host     = aws_db_instance.main.endpoint
      port     = aws_db_instance.main.port
      dbname   = aws_db_instance.main.db_name
      username = aws_db_instance.main.username
      # password sera stocké séparément dans Secrets Manager
    }
  }
  sensitive = false
}

# =============================================================================
# Cost Information
# =============================================================================

output "estimated_monthly_cost" {
  description = "Estimation du coût mensuel (à titre indicatif)"
  value = {
    instance_type = aws_db_instance.main.instance_class
    storage_gb = aws_db_instance.main.allocated_storage
    multi_az = aws_db_instance.main.multi_az
    backup_retention_days = aws_db_instance.main.backup_retention_period
    estimated_range = var.environment == "prod" ? "$200-300/month" : var.environment == "staging" ? "$100-150/month" : "$20-50/month"
    note = "Coûts réels dépendent de l'utilisation, région AWS, et prix actuels"
  }
}

# =============================================================================
# Ready-to-use Configuration Examples
# =============================================================================

output "application_yml_config" {
  description = "Configuration prête à copier dans application.yml Spring Boot"
  sensitive   = true
  value = <<-EOT
spring:
  datasource:
    primary:
      url: jdbc:postgresql://${aws_db_instance.main.endpoint}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}
      username: ${aws_db_instance.main.username}
      password: "${var.master_password != null ? var.master_password : random_password.master_password[0].result}" # Récupéré depuis la variable ou password généré
      driver-class-name: org.postgresql.Driver
      hikari:
        maximum-pool-size: 20
        minimum-idle: 5
        connection-timeout: 30000
        idle-timeout: 300000
        max-lifetime: 1800000
    ${length(aws_db_instance.read_replica) > 0 ? "replica:\n      url: jdbc:postgresql://${aws_db_instance.read_replica[0].endpoint}:${aws_db_instance.read_replica[0].port}/${aws_db_instance.main.db_name}\n      username: ${aws_db_instance.main.username}\n      password: \"${var.master_password != null ? var.master_password : random_password.master_password[0].result}\"\n      driver-class-name: org.postgresql.Driver\n      hikari:\n        maximum-pool-size: 10\n        minimum-idle: 2" : "# Read replica not configured for ${var.environment}"}
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        format_sql: true
        default_schema: public
EOT
}

output "docker_compose_env" {
  description = "Variables d'environnement pour Docker Compose"
  value = {
    DATABASE_URL = "jdbc:postgresql://${aws_db_instance.main.endpoint}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
    DATABASE_USERNAME = aws_db_instance.main.username
    DATABASE_HOST = aws_db_instance.main.address
    DATABASE_PORT = tostring(aws_db_instance.main.port)
    DATABASE_NAME = aws_db_instance.main.db_name
    REPLICA_URL = length(aws_db_instance.read_replica) > 0 ? "jdbc:postgresql://${aws_db_instance.read_replica[0].endpoint}:${aws_db_instance.read_replica[0].port}/${aws_db_instance.main.db_name}" : ""
  }
}

output "db_instance_id" {
  description = "Identifiant de l'instance RDS"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "ARN de l'instance RDS"
  value       = aws_db_instance.main.arn
}

output "db_instance_endpoint" {
  description = "Endpoint de connexion à la base de données principale"
  value       = aws_db_instance.main.endpoint
  sensitive   = false
}

output "db_instance_port" {
  description = "Port de connexion à la base de données"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "Nom de la base de données par défaut"
  value       = aws_db_instance.main.db_name
}

output "master_username" {
  description = "Nom d'utilisateur administrateur"
  value       = aws_db_instance.main.username
  sensitive   = false
}

# =============================================================================
# Read Replica Information (si activé)
# =============================================================================

output "read_replica_endpoint" {
  description = "Endpoint du read replica (si activé)"
  value       = length(aws_db_instance.read_replica) > 0 ? aws_db_instance.read_replica[0].endpoint : null
}

output "read_replica_id" {
  description = "ID du read replica (si activé)"
  value       = length(aws_db_instance.read_replica) > 0 ? aws_db_instance.read_replica[0].id : null
}

# =============================================================================
# Connection String Builders
# =============================================================================

output "connection_string" {
  description = "Chaîne de connexion JDBC pour les applications Java/Spring Boot"
  value       = "jdbc:postgresql://${aws_db_instance.main.endpoint}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}?sslmode=require&stringtype=unspecified"
  sensitive   = false
}

output "read_replica_connection_string" {
  description = "Chaîne de connexion JDBC pour le read replica (si activé)"
  value       = length(aws_db_instance.read_replica) > 0 ? "jdbc:postgresql://${aws_db_instance.read_replica[0].endpoint}:${aws_db_instance.read_replica[0].port}/${aws_db_instance.main.db_name}?sslmode=require&stringtype=unspecified" : null
  sensitive   = false
}

output "spring_datasource_config" {
  description = "Configuration Spring Boot DataSource (pour application.yml)"
  value = {
    primary = {
      url      = "jdbc:postgresql://${aws_db_instance.main.endpoint}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
      username = aws_db_instance.main.username
      driver   = "org.postgresql.Driver"
      properties = {
        sslmode = "require"
        stringtype = "unspecified"
      }
    }
    replica = length(aws_db_instance.read_replica) > 0 ? {
      url      = "jdbc:postgresql://${aws_db_instance.read_replica[0].endpoint}:${aws_db_instance.read_replica[0].port}/${aws_db_instance.main.db_name}"
      username = aws_db_instance.main.username
      driver   = "org.postgresql.Driver"
      properties = {
        sslmode = "require"
        stringtype = "unspecified"
      }
    } : null
  }
  sensitive = false
}

# =============================================================================
# Security Information
# =============================================================================

output "security_group_id" {
  description = "ID du security group de la base de données"
  value       = aws_security_group.rds.id
}

output "security_group_arn" {
  description = "ARN du security group de la base de données"
  value       = aws_security_group.rds.arn
}

output "db_subnet_group_name" {
  description = "Nom du DB subnet group"
  value       = aws_db_subnet_group.main.name
}

output "db_subnet_group_arn" {
  description = "ARN du DB subnet group"
  value       = aws_db_subnet_group.main.arn
}

# =============================================================================
# Parameter Group Information
# =============================================================================

output "parameter_group_name" {
  description = "Nom du parameter group PostgreSQL"
  value       = aws_db_parameter_group.main.name
}

output "parameter_group_arn" {
  description = "ARN du parameter group PostgreSQL"
  value       = aws_db_parameter_group.main.arn
}

# =============================================================================
# Monitoring & Backup Information
# =============================================================================

output "backup_retention_period" {
  description = "Période de rétention des backups en jours"
  value       = aws_db_instance.main.backup_retention_period
}

output "backup_window" {
  description = "Fenêtre de backup quotidien"
  value       = aws_db_instance.main.backup_window
}

output "maintenance_window" {
  description = "Fenêtre de maintenance hebdomadaire"
  value       = aws_db_instance.main.maintenance_window
}

output "performance_insights_enabled" {
  description = "Performance Insights activé ou non"
  value       = aws_db_instance.main.performance_insights_enabled
}

output "enhanced_monitoring_interval" {
  description = "Intervalle Enhanced Monitoring en secondes (0 = désactivé)"
  value       = aws_db_instance.main.monitoring_interval
}

# =============================================================================
# CloudWatch Alarms Information
# =============================================================================

output "cloudwatch_alarms" {
  description = "ARNs des alarmes CloudWatch créées"
  value = {
    cpu_utilization  = aws_cloudwatch_metric_alarm.database_cpu.arn
    connection_count = aws_cloudwatch_metric_alarm.database_connections.arn
  }
}

# =============================================================================
# Environment-specific Information
# =============================================================================

output "environment" {
  description = "Environnement de déploiement"
  value       = var.environment
}

output "multi_az_enabled" {
  description = "Multi-AZ activé ou non"
  value       = aws_db_instance.main.multi_az
}

output "instance_class" {
  description = "Type d'instance RDS utilisé"
  value       = aws_db_instance.main.instance_class
}

output "allocated_storage" {
  description = "Stockage alloué en GB"
  value       = aws_db_instance.main.allocated_storage
}

