
## 🏗 Infrastructure Updates

### 🔄 Rolling Updates Strategy

#### 1. Kubernetes Rolling Update

```yaml
# rolling-update-strategy.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: accessweaver-pdp-service
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  template:
    spec:
      containers:
      - name: pdp-service
        image: accessweaver/pdp-service:latest
        ports:
        - containerPort: 8081
        livenessProbe:
          httpGet:
            path: /actuator/health/liveness
            port: 8081
          initialDelaySeconds: 60
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: 8081
          initialDelaySeconds: 30
          periodSeconds: 5
          failureThreshold: 2
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
```

#### 2. Infrastructure as Code Updates

```hcl
# infrastructure-updates.tf
terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    bucket         = "accessweaver-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "accessweaver-terraform-locks"
    encrypt        = true
  }
}

# Update strategy avec blue-green pour ECS
resource "aws_ecs_service" "api_gateway" {
  name            = "accessweaver-api-gateway"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api_gateway.arn
  desired_count   = 3
  
  deployment_configuration {
    deployment_circuit_breaker {
      enable   = true
      rollback = true
    }
    
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }
  
  deployment_controller {
    type = "ECS" # ou "CODE_DEPLOY" pour blue-green
  }
  
  # Health check grace period
  health_check_grace_period_seconds = 300
  
  lifecycle {
    ignore_changes = [task_definition]
  }
}

# Auto-scaling pour gérer les pics pendant updates
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api_gateway.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
```
