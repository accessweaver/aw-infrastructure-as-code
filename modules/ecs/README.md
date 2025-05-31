# 🚀 Module ECS Fargate - AccessWeaver

Module Terraform pour orchestrer les microservices AccessWeaver sur AWS ECS Fargate avec configuration adaptative, auto-scaling intelligent et observabilité complète.

## 🎯 Objectifs

### ✅ Orchestration Microservices ComplÅète
- **5 services AccessWeaver** déployés automatiquement (API Gateway, PDP, PAP, Tenant, Audit)
- **Configuration adaptative** selon l'environnement (dev/staging/prod)
- **Auto-scaling intelligent** basé sur CPU et mémoire
- **Service discovery** avec AWS Cloud Map

### ✅ Production-Ready dès le MVP
- **Fargate serverless** (pas de gestion d'instances EC2)
- **Multi-AZ déployment** pour haute disponibilité
- **Health checks** intégrés et load balancer ready
- **Secrets management** avec AWS Secrets Manager

### ✅ Observabilité Complète
- **Container Insights** pour monitoring avancé
- **Structured logging** avec CloudWatch
- **Auto-scaling metrics** et alerting
- **X-Ray tracing** pour debugging distribué

### ✅ Developer Experience Optimisée
- **CI/CD ready** avec configuration GitHub Actions
- **Local debugging** avec ECS Exec
- **Service discovery** automatique
- **Configuration Spring Boot** générée automatiquement

## 🏗 Architecture par Environnement

### 🔧 Développement
```
┌─────────────────────────────────────────────────────────┐
│                    Internet                             │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│              Application Load Balancer                  │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                ECS Cluster (Fargate)                    │
│                                                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│  │API Gateway  │ │PDP Service  │ │PAP Service  │       │
│  │  (1 task)   │ │  (1 task)   │ │  (1 task)   │       │
│  │256CPU/512MB │ │512CPU/1GB   │ │256CPU/512MB │       │
│  └─────────────┘ └─────────────┘ └─────────────┘       │
│                                                         │
│  ┌─────────────┐ ┌─────────────┐                       │
│  │Tenant Svc   │ │Audit Service│                       │
│  │  (1 task)   │ │  (1 task)   │                       │
│  │256CPU/512MB │ │256CPU/512MB │                       │
│  └─────────────┘ └─────────────┘                       │
│                                                         │
│  Features:                                              │
│  ✅ Single instance par service                         │
│  ✅ Resources minimales (économique)                    │
│  ❌ Container Insights OFF                              │
│  ❌ Auto-scaling limité (max 2)                         │
│                                                         │
│  Coût: ~$80/mois                                        │
└─────────────────────────────────────────────────────────┘
```

### 🎭 Staging
```
┌─────────────────────────────────────────────────────────┐
│                    Internet                             │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│              Application Load Balancer                  │
│                   (Multi-AZ)                            │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│            ECS Cluster (Fargate + Spot 30%)             │
│                                                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│  │API Gateway  │ │PDP Service  │ │PAP Service  │       │
│  │  (2 tasks)  │ │  (2 tasks)  │ │  (1 task)   │       │
│  │512CPU/1GB   │ │1024CPU/2GB  │ │512CPU/1GB   │       │
│  └─────────────┘ └─────────────┘ └─────────────┘       │
│                                                         │
│  ┌─────────────┐ ┌─────────────┐                       │
│  │Tenant Svc   │ │Audit Service│                       │
│  │  (1 task)   │ │  (1 task)   │                       │
│  │256CPU/512MB │ │256CPU/512MB │                       │
│  └─────────────┘ └─────────────┘                       │
│                                                         │
│  Features:                                              │
│  ✅ Multi-instance HA                                   │
│  ✅ Container Insights ON                               │
│  ✅ Auto-scaling intelligent (max 4)                    │
│  ✅ 30% Fargate Spot (économies)                        │
│                                                         │
│  Coût: ~$150/mois                                       │
└─────────────────────────────────────────────────────────┘
```

### 🚀 Production
```
┌─────────────────────────────────────────────────────────┐
│                    Internet                             │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│           Application Load Balancer (Multi-AZ)          │
│              avec SSL Termination                       │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│              ECS Cluster (Fargate 100%)                 │
│            avec Container Insights Enhanced             │
│                                                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│  │API Gateway  │ │PDP Service  │ │PAP Service  │       │
│  │  (3 tasks)  │ │  (3 tasks)  │ │  (2 tasks)  │       │
│  │1024CPU/2GB  │ │2048CPU/4GB  │ │1024CPU/2GB  │       │
│  └─────────────┘ └─────────────┘ └─────────────┘       │
│                                                         │
│  ┌─────────────┐ ┌─────────────┐                       │
│  │Tenant Svc   │ │Audit Service│                       │
│  │  (2 tasks)  │ │  (2 tasks)  │                       │
│  │512CPU/1GB   │ │512CPU/1GB   │                       │
│  └─────────────┘ └─────────────┘                       │
│                                                         │
│  Features:                                              │
│  ✅ Haute disponibilité native                          │
│  ✅ Auto-scaling agressif (max 10)                      │
│  ✅ Container Insights Enhanced                         │
│  ✅ X-Ray tracing activé                                │
│  ✅ Circuit breaker déploiements                        │
│  ✅ Blue/Green deployments                              │
│                                                         │
│  Coût: ~$350/mois                                       │
└─────────────────────────────────────────────────────────┘
```

## 🚀 Utilisation

### Configuration Basique (Dev)

```hcl
module "ecs" {
  source = "../../modules/ecs"
  
  # Configuration obligatoire
  project_name               = "accessweaver"
  environment               = "dev"
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  
  # Intégration réseau
  alb_security_group_ids    = [module.alb.security_group_id]
  rds_security_group_id     = module.rds.security_group_id
  redis_security_group_id   = module.redis.security_group_id
  
  # Configuration Docker
  container_registry        = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/accessweaver"
  image_tag                = "latest"
  
  # Target groups ALB
  target_group_arns = {
    "aw-api-gateway" = module.alb.target_group_arns["api-gateway"]
  }
}
```

### Configuration Avancée (Production)

```hcl
module "ecs" {
  source = "../../modules/ecs"
  
  # Configuration de base
  project_name               = "accessweaver"
  environment               = "prod"
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  
  # Réseau et sécurité
  alb_security_group_ids    = [module.alb.security_group_id]
  rds_security_group_id     = module.rds.security_group_id
  redis_security_group_id   = module.redis.security_group_id
  
  # Configuration des images
  container_registry        = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/accessweaver"
  image_tag                = "1.0.0"  # Version stable en prod
  
  # Customisation des services
  service_overrides = {
    "aw-pdp-service" = {
      cpu           = 2048    # Plus de CPU pour PDP (évaluation OPA)
      memory        = 4096    # Plus de mémoire pour cache OPA
      desired_count = 3       # HA critique pour décisions d'autorisation
    }
    "aw-api-gateway" = {
      desired_count = 3       # Point d'entrée critique
    }
  }
  
  # Auto-scaling optimisé
  auto_scaling_enabled      = true
  scaling_cpu_target        = 60    # Plus agressif en prod
  scaling_memory_target     = 75
  min_capacity_override     = 2     # HA minimum
  max_capacity_override     = 15    # Pic de charge
  
  # Variables d'environnement communes
  common_environment_variables = {
    SPRING_PROFILES_ACTIVE               = "prod"
    JAVA_OPTS                           = "-Xmx1536m -XX:+UseG1GC -XX:+UseStringDeduplication"
    LOGGING_LEVEL_ROOT                  = "INFO"
    MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE = "health,info,metrics"
    MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS = "when-authorized"
  }
  
  # Monitoring et observabilité
  container_insights_enabled = true
  log_retention_days         = 30
  enable_xray_tracing        = true
  
  # Intégration ALB
  target_group_arns = {
    "aw-api-gateway" = module.alb.target_group_arns["api-gateway"]
  }
  
  health_check_grace_period  = 180  # Applications Spring Boot
  
  # Optimisations production
  enable_fargate_spot        = false  # Stabilité maximale
  deployment_circuit_breaker = true   # Protection déploiements
  enable_execute_command     = false  # Sécurité
  
  # Tags pour cost management
  additional_tags = {
    CostCenter      = "Engineering"
    Owner           = "Platform Team"
    BusinessUnit    = "Product"
    Compliance      = "GDPR"
    MonitoringLevel = "Enhanced"
    BackupPolicy    = "None"  # Stateless
  }
}
```

## 📊 Services AccessWeaver Déployés

| Service | Description | Port | Public | Criticité |
|---------|-------------|------|--------|-----------|
| **aw-api-gateway** | Point d'entrée + Auth JWT | 8080 | ✅ | Critique |
| **aw-pdp-service** | Policy Decision Point | 8081 | ❌ | Critique |
| **aw-pap-service** | Policy Administration | 8082 | ❌ | Important |
| **aw-tenant-service** | Multi-tenancy management | 8083 | ❌ | Important |
| **aw-audit-service** | Logging & compliance | 8084 | ❌ | Modéré |

### Allocation des Ressources par Environnement

| Service / Environment | Dev CPU/Memory | Staging CPU/Memory | Prod CPU/Memory |
|----------------------|----------------|-------------------|-----------------|
| **API Gateway** | 256/512MB | 512/1GB | 1024/2GB |
| **PDP Service** | 512/1GB | 1024/2GB | 2048/4GB |
| **PAP Service** | 256/512MB | 512/1GB | 1024/2GB |
| **Tenant Service** | 256/512MB | 256/512MB | 512/1GB |
| **Audit Service** | 256/512MB | 256/512MB | 512/1GB |

## 🔌 Intégration Spring Boot

### Configuration automatique

Le module génère automatiquement la configuration pour Spring Cloud :

```bash
# Service discovery URLs
terraform output internal_dns_names
```

### Application.yml généré

```yaml
# Configuration automatique pour Spring Cloud
spring:
  application:
    name: aw-api-gateway  # Nom du service
  cloud:
    discovery:
      enabled: true
      
eureka:
  client:
    service-url:
      defaultZone: http://aw-api-gateway.accessweaver-prod.local:8080/eureka/
  instance:
    prefer-ip-address: true
    instance-id: ${spring.application.name}:${random.value}

# Configuration service-to-service
accessweaver:
  services:
    pdp-service: http://aw-pdp-service.accessweaver-prod.local:8081
    pap-service: http://aw-pap-service.accessweaver-prod.local:8082
    tenant-service: http://aw-tenant-service.accessweaver-prod.local:8083
    audit-service: http://aw-audit-service.accessweaver-prod.local:8084

# Configuration database (secrets via AWS Secrets Manager)
spring:
  datasource:
    url: ${DATABASE_URL}
    username: ${DATABASE_USERNAME}
    password: ${DATABASE_PASSWORD}  # Depuis Secrets Manager
    
  redis:
    host: ${REDIS_HOST}
    port: ${REDIS_PORT}
    password: ${REDIS_AUTH_TOKEN}  # Depuis Secrets Manager

# Configuration monitoring
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: when-authorized
  metrics:
    export:
      cloudwatch:
        enabled: true
        namespace: AccessWeaver/${ENVIRONMENT}
```

### Service Client Java

```java
@Component
public class AccessWeaverServiceClient {
    
    private final RestTemplate restTemplate;
    private final LoadBalancerClient loadBalancer;
    
    @Value("${accessweaver.services.pdp-service}")
    private String pdpServiceUrl;
    
    // Utilisation du service discovery pour communication inter-services
    public boolean checkPermission(String userId, String resource, String action) {
        // Le DNS interne route automatiquement vers une instance disponible
        String url = pdpServiceUrl + "/api/v1/check";
        
        CheckPermissionRequest request = CheckPermissionRequest.builder()
            .userId(userId)
            .resource(resource)
            .action(action)
            .build();
            
        CheckPermissionResponse response = restTemplate.postForObject(
            url, request, CheckPermissionResponse.class);
            
        return response != null && response.isAllowed();
    }
}
```

## 🛡 Sécurité et Secrets Management

### Secrets AWS Secrets Manager

Le module accède automatiquement aux secrets suivants :

```json
// Secret: accessweaver/prod/database
{
  "password": "secure_db_password_here"
}

// Secret: accessweaver/prod/redis  
{
  "auth_token": "secure_redis_token_here"
}

// Secret: accessweaver/prod/jwt
{
  "secret": "jwt_signing_secret_here",
  "expiration": "3600"
}
```

### Configuration IAM

```java
// Exemple de configuration Spring Boot pour accéder aux secrets
@Configuration
@EnableConfigurationProperties
public class SecretsConfig {
    
    @Bean
    @ConfigurationProperties("spring.datasource")
    public DataSource dataSource() {
        // Spring Boot récupère automatiquement DATABASE_PASSWORD 
        // depuis Secrets Manager via la configuration ECS
        return DataSourceBuilder.create().build();
    }
}
```

### Security Groups

Le module configure automatiquement :

```hcl
# Security group ECS services
ingress {
  # ALB → Services publics (API Gateway)
  from_port       = 8080
  to_port         = 8090
  protocol        = "tcp"
  security_groups = [var.alb_security_group_ids]
}

egress {
  # Services → RDS PostgreSQL
  from_port       = 5432
  to_port         = 5432
  protocol        = "tcp"
  security_groups = [var.rds_security_group_id]
}

egress {
  # Services → Redis ElastiCache
  from_port       = 6379
  to_port         = 6379
  protocol        = "tcp"  
  security_groups = [var.redis_security_group_id]
}
```

## 📈 Auto-Scaling et Monitoring

### Policies d'Auto-Scaling

```hcl
# Configuration automatique par le module
resource "aws_appautoscaling_policy" "cpu_scaling" {
  target_tracking_scaling_policy_configuration {
    target_value = 70  # 70% CPU en prod, 80% en dev
    
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    
    scale_out_cooldown = 300  # 5 minutes
    scale_in_cooldown  = 300  # 5 minutes
  }
}
```

### Métriques CloudWatch

Le module expose automatiquement :

| Métrique | Description | Seuil Recommandé |
|----------|-------------|------------------|
| **CPUUtilization** | CPU moyen par service | < 70% |
| **MemoryUtilization** | Mémoire moyenne par service | < 80% |
| **TaskCount** | Nombre de tâches actives | >= min_capacity |
| **ServiceHealth** | Santé du service ALB | = 100% |

### Alertes Automatiques

```bash
# Exemple d'alerte CloudWatch (créée automatiquement)
aws cloudwatch put-metric-alarm \
  --alarm-name "AccessWeaver-Prod-PDP-HighCPU" \
  --alarm-description "PDP Service CPU utilization high" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

## 💰 Optimisation des Coûts

### Fargate vs EC2 Cost Analysis

| Configuration | Fargate | EC2 (t3.medium) | Économies |
|---------------|---------|------------------|-----------|
| **Dev (5 services)** | $80/mois | $45/mois | -44% |
| **Staging (7 instances)** | $150/mois | $90/mois | -40% |
| **Prod (12 instances)** | $350/mois | $180/mois | -49% |

**Pourquoi Fargate malgré le coût ?**
- ✅ Zero infrastructure management
- ✅ Scaling instantané
- ✅ Pas de over-provisioning
- ✅ Facturation à la seconde
- ✅ Sécurité native (pas de patching OS)

### Stratégies d'Économies

```hcl
# 1. Fargate Spot en dev/staging
enable_fargate_spot = var.environment != "prod"  # -70% coût

# 2. Right-sizing automatique
service_overrides = {
  "aw-audit-service" = {
    cpu    = 256    # Service moins critique
    memory = 512
  }
}

# 3. Optimisation des logs
log_retention_days = var.environment == "prod" ? 30 : 7

# 4. Container Insights conditionnel
container_insights_enabled = var.environment != "dev"
```

### Monitoring des Coûts

```bash
# Script de monitoring des coûts ECS
#!/bin/bash
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --filter file://ecs-cost-filter.json
```

## 🔧 Variables du Module

### Variables Obligatoires

| Variable | Type | Description |
|----------|------|-------------|
| `project_name` | string | Nom du projet (ex: "accessweaver") |
| `environment` | string | Environnement (dev/staging/prod) |
| `vpc_id` | string | ID du VPC de déploiement |
| `private_subnet_ids` | list(string) | IDs des subnets privés (≥2) |
| `rds_security_group_id` | string | Security group RDS PostgreSQL |
| `redis_security_group_id` | string | Security group Redis ElastiCache |
| `container_registry` | string | URL du registry Docker (ECR) |

### Variables Importantes

| Variable | Type | Défaut | Description |
|----------|------|--------|-------------|
| `image_tag` | string | "latest" | Tag des images Docker |
| `service_overrides` | map(object) | {} | Configuration personnalisée par service |
| `auto_scaling_enabled` | bool | true | Activation auto-scaling |
| `scaling_cpu_target` | number | 70 | Seuil CPU pour scaling (%) |
| `container_insights_enabled` | bool | null | Container Insights (auto selon env) |
| `enable_fargate_spot` | bool | null | Fargate Spot (auto selon env) |

## 📤 Outputs du Module

### Outputs Essentiels

| Output | Description |
|--------|-------------|
| `cluster_name` | Nom du cluster ECS |
| `service_arns` | ARNs de tous les services |
| `security_group_id` | Security group des services |
| `internal_dns_names` | Noms DNS pour service discovery |
| `alb_integration_config` | Configuration pour module ALB |

### Outputs pour CI/CD

| Output | Description |
|--------|-------------|
| `cicd_deployment_config` | Configuration GitHub Actions |
| `debugging_information` | Commandes AWS CLI utiles |
| `health_check_urls` | URLs de health check internes |

## 🛠 CI/CD Integration

### GitHub Actions Configuration

```yaml
# .github/workflows/deploy.yml
name: Deploy AccessWeaver
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: eu-west-1
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Build and push images
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: accessweaver
          IMAGE_TAG: ${{ github.sha }}
        run: |
          # Build all AccessWeaver services
          for service in api-gateway pdp-service pap-service tenant-service audit-service; do
            docker build -t $ECR_REGISTRY/$ECR_REPOSITORY/aw-$service:$IMAGE_TAG ./services/aw-$service
            docker push $ECR_REGISTRY/$ECR_REPOSITORY/aw-$service:$IMAGE_TAG
          done
      
      - name: Deploy to ECS
        env:
          CLUSTER_NAME: accessweaver-prod-cluster
          IMAGE_TAG: ${{ github.sha }}
        run: |
          # Update all services with new image tag
          for service in api-gateway pdp-service pap-service tenant-service audit-service; do
            aws ecs update-service \
              --cluster $CLUSTER_NAME \
              --service accessweaver-prod-aw-$service \
              --force-new-deployment
              
            # Wait for deployment to complete
            aws ecs wait services-stable \
              --cluster $CLUSTER_NAME \
              --services accessweaver-prod-aw-$service
          done
```

### Deployment Scripts

```bash
#!/bin/bash
# deploy.sh - Script de déploiement local

set -e

ENVIRONMENT=${1:-dev}
IMAGE_TAG=${2:-latest}
CLUSTER_NAME="accessweaver-${ENVIRONMENT}-cluster"

echo "🚀 Deploying AccessWeaver to ${ENVIRONMENT}"

# Services à déployer dans l'ordre
SERVICES=("aw-tenant-service" "aw-pap-service" "aw-pdp-service" "aw-audit-service" "aw-api-gateway")

for service in "${SERVICES[@]}"; do
    echo "📦 Deploying ${service}..."
    
    # Update service avec nouvelle image
    aws ecs update-service \
        --cluster "${CLUSTER_NAME}" \
        --service "accessweaver-${ENVIRONMENT}-${service}" \
        --force-new-deployment
    
    # Attendre que le déploiement soit stable
    echo "⏳ Waiting for ${service} to be stable..."
    aws ecs wait services-stable \
        --cluster "${CLUSTER_NAME}" \
        --services "accessweaver-${ENVIRONMENT}-${service}"
    
    echo "✅ ${service} deployed successfully"
done

echo "🎉 All services deployed successfully!"

# Health check final
echo "🔍 Running health checks..."
for service in "${SERVICES[@]}"; do
    health_url=$(terraform output -json health_check_urls | jq -r ".\"${service}\"")
    if curl -f "${health_url}" > /dev/null 2>&1; then
        echo "✅ ${service} health check passed"
    else
        echo "❌ ${service} health check failed"
        exit 1
    fi
done
```

## 🛠 Troubleshooting

### Problèmes Courants

#### 1. Service ne démarre pas

```bash
# 1. Vérifier les logs du service
aws logs tail /ecs/accessweaver-prod/aw-api-gateway --follow

# 2. Vérifier les événements ECS
aws ecs describe-services \
  --cluster accessweaver-prod-cluster \
  --services accessweaver-prod-aw-api-gateway \
  --query 'services[0].events'

# 3. Vérifier la task definition
aws ecs describe-task-definition \
  --task-definition accessweaver-prod-aw-api-gateway
```

#### 2. Problèmes de connectivité

```bash
# 1. Tester la résolution DNS interne
nslookup aw-pdp-service.accessweaver-prod.local

# 2. Vérifier les security groups
aws ec2 describe-security-groups \
  --group-ids sg-xxxxxxxxx

# 3. Tester l'accès aux services externes
# Depuis une tâche ECS :
aws ecs execute-command \
  --cluster accessweaver-prod-cluster \
  --task task-id \
  --container aw-api-gateway \
  --interactive \
  --command "curl -v https://api.external-service.com"
```

#### 3. Performance dégradée

```bash
# 1. Analyser les métriques CPU/Memory
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=accessweaver-prod-aw-pdp-service \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Average,Maximum

# 2. Vérifier les scaling events
aws application-autoscaling describe-scaling-activities \
  --service-namespace ecs \
  --resource-id service/accessweaver-prod-cluster/accessweaver-prod-aw-pdp-service
```

### Scripts de Maintenance

```bash
#!/bin/bash
# maintenance.sh - Scripts d'administration

case "$1" in
  "scale")
    # Scale un service manuellement
    SERVICE_NAME="accessweaver-prod-aw-${2}"
    DESIRED_COUNT=${3}
    aws ecs update-service \
      --cluster accessweaver-prod-cluster \
      --service "$SERVICE_NAME" \
      --desired-count "$DESIRED_COUNT"
    ;;
    
  "rollback")
    # Rollback vers version précédente
    SERVICE_NAME="accessweaver-prod-aw-${2}"
    PREVIOUS_TASK_DEF=$(aws ecs describe-services \
      --cluster accessweaver-prod-cluster \
      --services "$SERVICE_NAME" \
      --query 'services[0].deployments[1].taskDefinition' \
      --output text)
    
    aws ecs update-service \
      --cluster accessweaver-prod-cluster \
      --service "$SERVICE_NAME" \
      --task-definition "$PREVIOUS_TASK_DEF"
    ;;
    
  "logs")
    # Streamer les logs en temps réel
    SERVICE_NAME="aw-${2}"
    aws logs tail "/ecs/accessweaver-prod/${SERVICE_NAME}" --follow
    ;;
    
  *)
    echo "Usage: $0 {scale|rollback|logs} [service] [count]"
    exit 1
    ;;
esac
```

## 📚 Ressources

### Documentation Technique
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Fargate vs EC2 Guide](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/launch_types.html)
- [Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html)

### Tools Recommandés
- [AWS Copilot](https://aws.github.io/copilot-cli/) - CLI pour ECS
- [ECS CLI](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_CLI.html) - Commandes ECS simplifiées
- [Docker Compose ECS](https://docs.docker.com/cloud/ecs-integration/) - Integration Docker Compose

### Monitoring & Observabilité
- [ECS CloudWatch Dashboard](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Dashboards.html)
- [X-Ray Tracing Guide](https://docs.aws.amazon.com/xray/latest/devguide/xray-services-ecs.html)
- [Prometheus ECS Discovery](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#ec2_sd_config)

---

**⚠️ Note importante :** Ce module crée des ressources AWS facturées. Les coûts Fargate peuvent être significatifs selon l'utilisation. Configurez des budgets appropriés et surveillez les métriques de coût.