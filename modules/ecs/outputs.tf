# =============================================================================
# AccessWeaver ECS Module - Outputs
# =============================================================================
# Outputs complets pour l'intégration ECS dans AccessWeaver
#
# ORGANISATION:
# 1. Informations cluster et services
# 2. Configuration réseau et sécurité
# 3. Service discovery et DNS
# 4. Auto-scaling et monitoring
# 5. Configuration pour ALB
# 6. Debugging et troubleshooting
# 7. Coûts et optimisation
# 8. Configuration CI/CD ready-to-use
#
# USAGE:
# Ces outputs sont conçus pour être utilisés par:
# - Module ALB (target groups et health checks)
# - Scripts de déploiement CI/CD
# - Monitoring et alerting
# - Documentation automatique
# =============================================================================

# =============================================================================
# 1. INFORMATIONS CLUSTER ET SERVICES
# =============================================================================

output "cluster_id" {
  description = <<-EOT
    ID du cluster ECS créé.

    Utilisé pour:
    - Références dans d'autres ressources Terraform
    - Commandes AWS CLI pour déploiement
    - Scripts de monitoring et maintenance
    - Configuration CI/CD

    Exemple: "arn:aws:ecs:eu-west-1:123456789012:cluster/accessweaver-prod-cluster"
  EOT
  value = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = <<-EOT
    Nom du cluster ECS créé.

    Format: {project_name}-{environment}-cluster
    Exemple: "accessweaver-prod-cluster"

    Utilisé dans:
    - Configuration CI/CD pipelines
    - Scripts de déploiement
    - Commandes AWS CLI
    - Documentation
  EOT
  value = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = <<-EOT
    ARN complet du cluster ECS.

    Utilisé pour:
    - Policies IAM
    - EventBridge rules
    - Cross-account access
    - Monitoring CloudWatch
  EOT
  value = aws_ecs_cluster.main.arn
}

output "service_arns" {
  description = <<-EOT
    ARNs de tous les services ECS déployés.

    Map service_name → service_arn

    Services AccessWeaver:
    - aw-api-gateway: Point d'entrée public
    - aw-pdp-service: Policy Decision Point
    - aw-pap-service: Policy Administration Point
    - aw-tenant-service: Gestion multi-tenancy
    - aw-audit-service: Logging et compliance

    Utilisé pour:
    - Auto-scaling configuration
    - CloudWatch alarms
    - Deployment scripts
  EOT
  value = {
    for service_name, service in aws_ecs_service.services :
    service_name => service.id
  }
}

output "service_names" {
  description = <<-EOT
    Noms de tous les services ECS déployés.

    Format: {project_name}-{environment}-{service_name}

    Utilisé dans:
    - Scripts de maintenance
    - Configuration monitoring
    - Load balancer target groups
  EOT
  value = {
    for service_name, service in aws_ecs_service.services :
    service_name => service.name
  }
}

output "task_definition_arns" {
  description = <<-EOT
    ARNs des task definitions pour chaque service.

    Utilisé pour:
    - Déploiements programmatiques
    - Rollback vers versions précédentes
    - Analyse des configurations
  EOT
  value = {
    for service_name, task_def in aws_ecs_task_definition.services :
    service_name => task_def.arn
  }
}

# =============================================================================
# 2. CONFIGURATION RÉSEAU ET SÉCURITÉ
# =============================================================================

output "security_group_id" {
  description = <<-EOT
    ID du security group principal des services ECS.

    Ce security group permet:
    - Accès depuis ALB (ports 8080-8090)
    - Communication inter-services
    - Accès à RDS PostgreSQL (port 5432)
    - Accès à Redis ElastiCache (port 6379)
    - Accès sortant HTTPS/HTTP

    Utilisé par:
    - Autres modules pour autoriser l'accès
    - Debugging de connectivité
    - Configuration de monitoring
  EOT
  value = aws_security_group.ecs_services.id
}

output "security_group_arn" {
  description = <<-EOT
    ARN du security group principal des services ECS.

    Utilisé pour:
    - Policies IAM cross-account
    - Configuration VPC Endpoints
    - Audit de sécurité
  EOT
  value = aws_security_group.ecs_services.arn
}

output "execution_role_arn" {
  description = <<-EOT
    ARN du rôle IAM d'exécution des tâches ECS.

    Ce rôle permet:
    - Pull des images Docker depuis ECR
    - Écriture des logs CloudWatch
    - Accès aux secrets AWS Secrets Manager
    - Accès aux paramètres SSM

    Utilisé pour:
    - Configuration des task definitions
    - Troubleshooting des permissions
    - Audit de sécurité
  EOT
  value = aws_iam_role.ecs_task_execution_role.arn
}

output "task_role_arn" {
  description = <<-EOT
    ARN du rôle IAM d'exécution des applications dans les containers.

    Ce rôle permet aux applications AccessWeaver:
    - Écriture des métriques CloudWatch personnalisées
    - Écriture des logs applicatifs
    - Accès aux services AWS requis par l'application

    Note: Permissions minimales selon le principe du moindre privilège.
  EOT
  value = aws_iam_role.ecs_task_role.arn
}

# =============================================================================
# 3. SERVICE DISCOVERY ET DNS
# =============================================================================

output "service_discovery_namespace_id" {
  description = <<-EOT
    ID du namespace AWS Cloud Map pour service discovery.

    Namespace: {project_name}-{environment}.local
    Exemple: "accessweaver-prod.local"

    Les services sont accessibles via:
    - aw-api-gateway.accessweaver-prod.local
    - aw-pdp-service.accessweaver-prod.local
    - etc.

    Utilisé pour:
    - Communication inter-services
    - Configuration Spring Cloud
    - Load balancing interne
  EOT
  value = aws_service_discovery_private_dns_namespace.main.id
}

output "service_discovery_namespace_name" {
  description = <<-EOT
    Nom du namespace pour service discovery.

    Utilisé dans la configuration Spring Boot:
    eureka:
      client:
        service-url:
          defaultZone: http://aw-api-gateway.{namespace}/eureka/
  EOT
  value = aws_service_discovery_private_dns_namespace.main.name
}

output "service_discovery_services" {
  description = <<-EOT
    Map des services de découverte créés.

    service_name → discovery_service_info

    Chaque service est automatiquement enregistré dans le DNS privé
    et découvrable par les autres services du cluster.
  EOT
  value = {
    for service_name, discovery_service in aws_service_discovery_service.services :
    service_name => {
      id   = discovery_service.id
      arn  = discovery_service.arn
      name = discovery_service.name
      dns  = "${discovery_service.name}.${aws_service_discovery_private_dns_namespace.main.name}"
    }
  }
}

output "internal_dns_names" {
  description = <<-EOT
    Noms DNS internes pour chaque service AccessWeaver.

    Utilisés pour la communication inter-services:
    - Configuration Spring Cloud
    - Health checks internes
    - Load balancing round-robin automatique

    Format: {service_name}.{namespace}
  EOT
  value = {
    for service_name, discovery_service in aws_service_discovery_service.services :
    service_name => "${discovery_service.name}.${aws_service_discovery_private_dns_namespace.main.name}"
  }
}

# =============================================================================
# 4. AUTO-SCALING ET MONITORING
# =============================================================================

output "auto_scaling_targets" {
  description = <<-EOT
    Configuration des cibles d'auto-scaling pour chaque service.

    Inclut:
    - Resource ID pour AWS CLI
    - Capacité min/max configurée
    - Dimension de scaling

    Utilisé pour:
    - Monitoring des scaling events
    - Ajustement des seuils
    - Debugging des politiques de scaling
  EOT
  value = {
    for service_name, target in aws_appautoscaling_target.ecs_targets :
    service_name => {
      resource_id        = target.resource_id
      min_capacity       = target.min_capacity
      max_capacity       = target.max_capacity
      scalable_dimension = target.scalable_dimension
    }
  }
}

output "scaling_policies" {
  description = <<-EOT
    ARNs des politiques d'auto-scaling créées.

    Politiques par service:
    - CPU-based scaling
    - Memory-based scaling

    Utilisé pour:
    - CloudWatch alarms
    - Monitoring des scaling events
    - Ajustement des seuils
  EOT
  value = {
    for service_name, policy in aws_appautoscaling_policy.ecs_cpu_policy :
    service_name => {
      cpu_policy_arn    = policy.arn
      memory_policy_arn = aws_appautoscaling_policy.ecs_memory_policy[service_name].arn
    }
  }
}

output "cloudwatch_log_groups" {
  description = <<-EOT
    Noms des groupes de logs CloudWatch pour chaque service.

    Format: /ecs/{project_name}-{environment}/{service_name}

    Utilisé pour:
    - Configuration d'alerting sur logs
    - Analyse des logs centralisée
    - Export vers services externes (ELK, Splunk)
    - Debugging et troubleshooting
  EOT
  value = {
    for service_name, log_group in aws_cloudwatch_log_group.service_logs :
    service_name => {
      name              = log_group.name
      arn               = log_group.arn
      retention_in_days = log_group.retention_in_days
    }
  }
}

# =============================================================================
# 5. CONFIGURATION POUR ALB
# =============================================================================

output "alb_integration_config" {
  description = <<-EOT
    Configuration prête pour l'intégration avec ALB.

    Inclut pour chaque service public:
    - Port du container
    - Health check path
    - Security group à autoriser
    - Configuration de déregistration

    Utilisé par le module ALB pour créer les target groups.
  EOT
  value = {
    for service_name, service_config in local.accessweaver_services :
    service_name => {
      container_port              = service_config.container_port
      health_check_path           = service_config.health_check_path
      health_check_grace_period   = var.health_check_grace_period
      deregistration_delay        = local.current_config.deregistration_delay
      public                      = service_config.public
      security_group_id           = aws_security_group.ecs_services.id

      # Informations pour target group
      target_type                 = "ip"
      protocol                    = "HTTP"
      vpc_id                      = var.vpc_id

      # Health check configuration détaillée
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 5
        interval            = 30
        path                = service_config.health_check_path
        matcher             = "200"
        protocol            = "HTTP"
        port                = "traffic-port"
      }
    } if service_config.public
  }
}

output "public_service_ports" {
  description = <<-EOT
    Ports des services exposés publiquement via ALB.

    Map service_name → container_port

    Utilisé pour:
    - Configuration ALB listeners
    - Security group rules
    - Health checks
  EOT
  value = {
    for service_name, service_config in local.accessweaver_services :
    service_name => service_config.container_port
    if service_config.public
  }
}

# =============================================================================
# 6. DEBUGGING ET TROUBLESHOOTING
# =============================================================================

output "debugging_information" {
  description = <<-EOT
    Informations pour le debugging et troubleshooting ECS.

    Commandes AWS CLI utiles:
    - Describe services
    - View logs
    - List tasks
    - Debug connectivity
  EOT
  value = {
    cluster_name = aws_ecs_cluster.main.name

    aws_cli_commands = {
      describe_services = "aws ecs describe-services --cluster ${aws_ecs_cluster.main.name} --services ${join(" ", [for s in aws_ecs_service.services : s.name])}"

      list_tasks = "aws ecs list-tasks --cluster ${aws_ecs_cluster.main.name}"

      describe_tasks = "aws ecs describe-tasks --cluster ${aws_ecs_cluster.main.name} --tasks $(aws ecs list-tasks --cluster ${aws_ecs_cluster.main.name} --query 'taskArns[]' --output text)"

      view_logs = {
        for service_name, log_group in aws_cloudwatch_log_group.service_logs :
        service_name => "aws logs tail ${log_group.name} --follow"
      }

      exec_into_container = {
        for service_name, service in aws_ecs_service.services :
        service_name => "aws ecs execute-command --cluster ${aws_ecs_cluster.main.name} --task TASK_ID --container ${service_name} --interactive --command '/bin/bash'"
      }
    }

    common_issues = {
      service_not_starting = {
        description = "Service ne démarre pas"
        checks = [
          "Vérifier les logs CloudWatch",
          "Vérifier les health checks",
          "Vérifier l'accès aux secrets",
          "Vérifier la connectivité réseau"
        ]
      }

      high_cpu_memory = {
        description = "CPU/Mémoire élevé"
        checks = [
          "Analyser les métriques CloudWatch",
          "Vérifier les patterns de scaling",
          "Profiler l'application Java",
          "Ajuster les ressources CPU/Memory"
        ]
      }

      connectivity_issues = {
        description = "Problèmes de connectivité"
        checks = [
          "Vérifier les security groups",
          "Tester la résolution DNS",
          "Vérifier les routes VPC",
          "Tester l'accès aux services externes"
        ]
      }
    }

    monitoring_urls = {
      cloudwatch_insights = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#insightsV2:discover"
      container_insights  = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#containerinsights"
      ecs_console        = "https://console.aws.amazon.com/ecs/home?region=${data.aws_region.current.name}#/clusters/${aws_ecs_cluster.main.name}"
    }
  }
}

output "health_check_urls" {
  description = <<-EOT
    URLs pour les health checks de chaque service.

    Format: http://{internal_dns}:{port}{health_path}

    Utilisé pour:
    - Tests de connectivité interne
    - Monitoring synthétique
    - Debugging des problèmes de santé

    Note: Accessible uniquement depuis le VPC.
  EOT
  value = {
    for service_name, service_config in local.accessweaver_services :
    service_name => "http://${service_name}.${aws_service_discovery_private_dns_namespace.main.name}:${service_config.container_port}${service_config.health_check_path}"
  }
}

# =============================================================================
# 7. COÛTS ET OPTIMISATION
# =============================================================================

output "estimated_monthly_cost" {
  description = <<-EOT
    Estimation du coût mensuel AWS pour l'ensemble ECS.

    Calcul basé sur:
    - Allocation CPU/Memory par service
    - Nombre d'instances par service
    - Utilisation Fargate vs Fargate Spot
    - Région eu-west-1 (prix Paris)

    Coûts additionnels:
    - CloudWatch Logs: ~$0.50/GB/mois
    - Container Insights: ~$0.50/GB métriques
    - Data transfer: ~$0.09/GB sortant

    Optimisations possibles:
    - Fargate Spot (-70% en dev/staging)
    - Right-sizing des ressources
    - Optimisation des logs
  EOT
  value = {
    environment = var.environment

    service_costs = {
      for service_name, service_config in local.accessweaver_services :
      service_name => {
        cpu_units           = service_config.cpu
        memory_mb          = service_config.memory
        desired_instances  = service_config.desired_count
        estimated_monthly_usd = service_config.desired_count * (
        (service_config.cpu / 1024) * 24 * 30 * 0.04048 +  # CPU cost
        (service_config.memory / 1024) * 24 * 30 * 0.004445 # Memory cost
        )
      }
    }

    total_estimated_monthly_cost = {
      fargate_compute = sum([
        for service_name, service_config in local.accessweaver_services :
        service_config.desired_count * (
      (service_config.cpu / 1024) * 24 * 30 * 0.04048 +
      (service_config.memory / 1024) * 24 * 30 * 0.004445
      )
        ])

      cloudwatch_logs = "10-50"  # Variable selon le volume
      container_insights = local.current_config.container_insights ? "20-100" : "0"

      total_range = var.environment == "prod" ? "$200-400/month" : (var.environment == "staging" ? "$100-200/month" : "$50-100/month")
    }

    optimization_tips = {
      fargate_spot = "Utiliser Fargate Spot en dev/staging pour -70% coût"
      right_sizing = "Monitorer CPU/Memory et ajuster les allocations"
      log_retention = "Réduire la rétention des logs en dev"
      container_insights = "Désactiver Container Insights en dev"
      scaling_policies = "Optimiser les seuils d'auto-scaling"
    }
  }
}

output "resource_allocation_summary" {
  description = <<-EOT
    Résumé de l'allocation des ressources par service.

    Utilisé pour:
    - Capacity planning
    - Cost optimization
    - Performance tuning
    - Scaling decisions
  EOT
  value = {
    total_cpu_units = sum([
      for service_name, service_config in local.accessweaver_services :
      service_config.cpu * service_config.desired_count
      ])

    total_memory_mb = sum([
      for service_name, service_config in local.accessweaver_services :
      service_config.memory * service_config.desired_count
      ])

    total_instances = sum([
      for service_name, service_config in local.accessweaver_services :
      service_config.desired_count
    ])

    services_breakdown = {
      for service_name, service_config in local.accessweaver_services :
      service_name => {
        cpu_per_instance    = service_config.cpu
        memory_per_instance = service_config.memory
        instances          = service_config.desired_count
        total_cpu          = service_config.cpu * service_config.desired_count
        total_memory       = service_config.memory * service_config.desired_count
        public_facing      = service_config.public
      }
    }
  }
}

# =============================================================================
# 8. CONFIGURATION CI/CD READY-TO-USE
# =============================================================================

output "cicd_deployment_config" {
  description = <<-EOT
    Configuration prête pour les pipelines CI/CD.

    Inclut:
    - Informations pour GitHub Actions
    - Scripts de déploiement
    - Variables d'environnement
    - Commandes AWS CLI
  EOT
  value = {
    cluster_name = aws_ecs_cluster.main.name
    region      = data.aws_region.current.name

    github_actions_vars = {
      AWS_REGION     = data.aws_region.current.name
      ECS_CLUSTER    = aws_ecs_cluster.main.name
      ECR_REGISTRY   = var.container_registry
      ENVIRONMENT    = var.environment
    }

    deployment_commands = {
      for service_name, service in aws_ecs_service.services :
      service_name => {
        update_service = "aws ecs update-service --cluster ${aws_ecs_cluster.main.name} --service ${service.name} --task-definition ${service_name}:REVISION"

        wait_for_deployment = "aws ecs wait services-stable --cluster ${aws_ecs_cluster.main.name} --services ${service.name}"

        rollback_command = "aws ecs update-service --cluster ${aws_ecs_cluster.main.name} --service ${service.name} --task-definition ${service_name}:PREVIOUS_REVISION"
      }
    }

    docker_build_commands = {
      for service_name, service_config in local.accessweaver_services :
      service_name => {
        build = "docker build -t ${var.container_registry}/${service_name}:${var.image_tag} ./services/${service_name}"
        push  = "docker push ${var.container_registry}/${service_name}:${var.image_tag}"
        tag_latest = "docker tag ${var.container_registry}/${service_name}:${var.image_tag} ${var.container_registry}/${service_name}:latest"
      }
    }
  }
}

output "terraform_state_references" {
  description = <<-EOT
    Références pour utiliser les outputs dans d'autres modules.

    Exemples d'utilisation:
    - Module ALB: var.ecs_security_group_id = module.ecs.security_group_id
    - Module monitoring: var.service_arns = module.ecs.service_arns
    - Scripts externes: terraform output -json | jq '.cicd_deployment_config.value'
  EOT
  value = {
    # Principales références cross-module
    security_group_id = aws_security_group.ecs_services.id
    cluster_name     = aws_ecs_cluster.main.name
    service_arns     = {
      for service_name, service in aws_ecs_service.services :
      service_name => service.id
    }

    # Pour documentation automatique
    module_version   = "1.0.0"
    terraform_version = ">= 1.0"
    provider_version = "~> 5.0"
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
  value       = data.aws_region.current.name
}

output "availability_zones" {
  description = "Zones de disponibilité utilisées"
  value       = data.aws_availability_zones.available.names
}

output "deployment_timestamp" {
  description = "Timestamp du déploiement"
  value       = timestamp()
}