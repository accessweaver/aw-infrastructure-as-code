# 🚀 Stratégies de Déploiement AccessWeaver

Guide complet des stratégies de déploiement pour AccessWeaver selon l'environnement et les contraintes business.

## 📋 Vue d'ensemble

| Stratégie | Environnement | Downtime | Complexité | Coût | Use Case |
|-----------|---------------|----------|------------|------|----------|
| **Recreate** | Dev | ⚠️ 30s-2min | 🟢 Faible | 🟢 Minimal | Développement rapide |
| **Rolling Update** | Dev/Staging | ✅ Zero | 🟡 Moyen | 🟡 Modéré | Updates fréquents |
| **Blue/Green** | Prod | ✅ Zero | 🔴 Élevé | 🔴 2x coût | Releases critiques |
| **Canary** | Prod | ✅ Zero | 🔴 Très élevé | 🟡 +20% | Features risquées |

---

## 🔄 Canary Deployment (Production)

### Scripts de Validation Canary

#### validate-canary.sh - Script Principal
```bash
#!/bin/bash
set -e

# =============================================================================
# AccessWeaver Canary Validation Script
# =============================================================================
# Valide automatiquement un déploiement canary avec métriques et health checks

# Configuration
ENVIRONMENT=${1:-prod}
SERVICE_NAME=${2:-aw-api-gateway}
CANARY_PERCENTAGE=${3:-10}
VALIDATION_DURATION=${4:-300}  # 5 minutes
CLUSTER_NAME="accessweaver-${ENVIRONMENT}-cluster"

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# =============================================================================
# Configuration des seuils de validation
# =============================================================================
THRESHOLDS=(
    "error_rate:2.0"           # Taux d'erreur < 2%
    "response_time_p99:500"    # P99 < 500ms
    "cpu_utilization:80"       # CPU < 80%
    "memory_utilization:85"    # Memory < 85%
    "target_health:95"         # 95% des targets healthy
)

CRITICAL_ENDPOINTS=(
    "/api/v1/check"
    "/api/v1/policies"
    "/actuator/health"
)

# =============================================================================
# Fonctions de validation
# =============================================================================

validate_health_checks() {
    local service_url="$1"
    local endpoint="$2"
    
    print_info "Testing endpoint: $endpoint"
    
    for i in {1..5}; do
        if response=$(curl -s -w "%{http_code}" -o /tmp/response "$service_url$endpoint"); then
            http_code=$(tail -n1 <<< "$response")
            if [[ "$http_code" == "200" ]]; then
                print_success "✓ $endpoint: HTTP $http_code"
                return 0
            else
                print_warning "⚠ $endpoint: HTTP $http_code (attempt $i/5)"
            fi
        else
            print_warning "⚠ $endpoint: Connection failed (attempt $i/5)"
        fi
        
        sleep 10
    done
    
    print_error "✗ $endpoint: All health checks failed"
    return 1
}

get_cloudwatch_metric() {
    local metric_name="$1"
    local namespace="$2"
    local dimensions="$3"
    local start_time=$(date -d '5 minutes ago' -Iseconds)
    local end_time=$(date -Iseconds)
    
    aws cloudwatch get-metric-statistics \
        --namespace "$namespace" \
        --metric-name "$metric_name" \
        --dimensions "$dimensions" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 300 \
        --statistics Average \
        --query 'Datapoints[0].Average' \
        --output text
}

validate_metrics() {
    local service_name="$1"
    
    print_info "Validating CloudWatch metrics for $service_name"
    
    # ALB metrics
    local alb_arn_suffix=$(aws elbv2 describe-load-balancers \
        --names "accessweaver-${ENVIRONMENT}-alb" \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text | cut -d'/' -f2-)
    
    # Validation du taux d'erreur
    local error_rate=$(get_cloudwatch_metric "HTTPCode_Target_5XX_Count" \
        "AWS/ApplicationELB" \
        "LoadBalancer=$alb_arn_suffix")
    
    if [[ "$error_rate" != "None" ]] && (( $(echo "$error_rate > 2.0" | bc -l) )); then
        print_error "Error rate too high: ${error_rate}%"
        return 1
    fi
    
    # Validation du temps de réponse
    local response_time=$(get_cloudwatch_metric "TargetResponseTime" \
        "AWS/ApplicationELB" \
        "LoadBalancer=$alb_arn_suffix")
    
    if [[ "$response_time" != "None" ]] && (( $(echo "$response_time > 0.5" | bc -l) )); then
        print_error "Response time too high: ${response_time}s"
        return 1
    fi
    
    # ECS metrics
    local cpu_utilization=$(get_cloudwatch_metric "CPUUtilization" \
        "AWS/ECS" \
        "ServiceName=accessweaver-${ENVIRONMENT}-${service_name},ClusterName=$CLUSTER_NAME")
    
    if [[ "$cpu_utilization" != "None" ]] && (( $(echo "$cpu_utilization > 80" | bc -l) )); then
        print_error "CPU utilization too high: ${cpu_utilization}%"
        return 1
    fi
    
    print_success "All metrics within acceptable thresholds"
    return 0
}

validate_business_metrics() {
    local service_url="$1"
    
    print_info "Validating business metrics"
    
    # Test d'autorisation basique
    local auth_test=$(curl -s -w "%{http_code}" \
        -H "Content-Type: application/json" \
        -H "X-Tenant-ID: canary-test" \
        -H "Authorization: Bearer $CANARY_TEST_TOKEN" \
        -d '{"user":"test-user","action":"read","resource":"test-resource"}' \
        "$service_url/api/v1/check")
    
    local http_code=$(tail -n1 <<< "$auth_test")
    if [[ "$http_code" != "200" ]]; then
        print_error "Authorization test failed: HTTP $http_code"
        return 1
    fi
    
    # Validation de la réponse JSON
    local response_body=$(head -n -1 <<< "$auth_test")
    if ! echo "$response_body" | jq -e '.allowed' > /dev/null; then
        print_error "Invalid response format"
        return 1
    fi
    
    print_success "Business logic validation passed"
    return 0
}

# =============================================================================
# Validation automatique complète
# =============================================================================

perform_canary_validation() {
    local service_url="https://accessweaver.com"  # URL production
    local validation_failed=false
    
    print_info "Starting canary validation for $SERVICE_NAME ($CANARY_PERCENTAGE%)"
    print_info "Validation duration: ${VALIDATION_DURATION}s"
    
    # Phase 1: Health checks des endpoints critiques
    print_info "Phase 1: Health checks validation"
    for endpoint in "${CRITICAL_ENDPOINTS[@]}"; do
        if ! validate_health_checks "$service_url" "$endpoint"; then
            validation_failed=true
            break
        fi
    done
    
    if [[ "$validation_failed" == "true" ]]; then
        print_error "Health checks failed - aborting canary"
        return 1
    fi
    
    # Phase 2: Validation continue des métriques
    print_info "Phase 2: Metrics validation (${VALIDATION_DURATION}s)"
    local start_time=$(date +%s)
    local validation_interval=60  # Check every minute
    
    while true; do
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        
        if [[ $elapsed -ge $VALIDATION_DURATION ]]; then
            break
        fi
        
        print_info "Validation progress: ${elapsed}/${VALIDATION_DURATION}s"
        
        # Validation des métriques techniques
        if ! validate_metrics "$SERVICE_NAME"; then
            validation_failed=true
            break
        fi
        
        # Validation des métriques business
        if ! validate_business_metrics "$service_url"; then
            validation_failed=true
            break
        fi
        
        sleep $validation_interval
    done
    
    if [[ "$validation_failed" == "true" ]]; then
        print_error "Metrics validation failed - initiating rollback"
        return 1
    fi
    
    print_success "Canary validation completed successfully!"
    return 0
}

# =============================================================================
# Actions de rollback automatique
# =============================================================================

trigger_automatic_rollback() {
    print_error "Triggering automatic rollback"
    
    # Récupération de la task definition précédente
    local previous_task_def=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "accessweaver-${ENVIRONMENT}-${SERVICE_NAME}" \
        --query 'services[0].deployments[1].taskDefinition' \
        --output text)
    
    if [[ "$previous_task_def" == "None" ]]; then
        print_error "No previous task definition found"
        return 1
    fi
    
    print_info "Rolling back to: $previous_task_def"
    
    # Rollback du service
    aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service "accessweaver-${ENVIRONMENT}-${SERVICE_NAME}" \
        --task-definition "$previous_task_def" \
        --force-new-deployment
    
    # Attendre la stabilisation
    print_info "Waiting for rollback to complete..."
    aws ecs wait services-stable \
        --cluster "$CLUSTER_NAME" \
        --services "accessweaver-${ENVIRONMENT}-${SERVICE_NAME}"
    
    print_success "Rollback completed"
    
    # Notification
    if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚨 AccessWeaver Canary FAILED - Automatic rollback completed for $SERVICE_NAME\"}" \
            "$SLACK_WEBHOOK_URL"
    fi
}

# =============================================================================
# Exécution principale
# =============================================================================

main() {
    # Validation des prérequis
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq not found"
        exit 1
    fi
    
    # Export des variables pour sous-processus
    export AWS_DEFAULT_REGION=eu-west-1
    
    # Démarrage de la validation
    if perform_canary_validation; then
        print_success "🎉 Canary deployment validated successfully!"
        
        # Notification de succès
        if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
            curl -X POST -H 'Content-type: application/json' \
                --data "{\"text\":\"✅ AccessWeaver Canary SUCCESS - $SERVICE_NAME validated with $CANARY_PERCENTAGE% traffic\"}" \
                "$SLACK_WEBHOOK_URL"
        fi
        
        exit 0
    else
        print_error "💥 Canary deployment validation failed!"
        trigger_automatic_rollback
        exit 1
    fi
}

# Affichage de l'aide
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [environment] [service_name] [canary_percentage] [validation_duration]"
    echo ""
    echo "Examples:"
    echo "  $0 prod aw-api-gateway 10 300"
    echo "  $0 staging aw-pdp-service 20 180"
    echo ""
    echo "Environment variables:"
    echo "  CANARY_TEST_TOKEN: JWT token for business logic testing"
    echo "  SLACK_WEBHOOK_URL: Slack webhook for notifications"
    exit 0
fi

main "$@"
```

---

## 📊 Monitoring et Métriques des Déploiements

### Dashboard CloudWatch pour Déploiements

```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", "accessweaver-prod-alb"],
          [".", "HTTPCode_Target_5XX_Count", ".", "."],
          [".", "TargetResponseTime", ".", "."]
        ],
        "period": 300,
        "stat": "Average",
        "region": "eu-west-1",
        "title": "ALB Health During Deployment",
        "yAxis": {
          "left": {
            "min": 0
          }
        }
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ECS", "CPUUtilization", "ServiceName", "accessweaver-prod-aw-api-gateway", "ClusterName", "accessweaver-prod-cluster"],
          [".", "MemoryUtilization", ".", ".", ".", "."]
        ],
        "period": 300,
        "stat": "Average",
        "region": "eu-west-1",
        "title": "ECS Resource Utilization",
        "yAxis": {
          "left": {
            "min": 0,
            "max": 100
          }
        }
      }
    }
  ]
}
```

### Alertes Automatiques pendant Déploiement

```bash
#!/bin/bash
# setup-deployment-alerts.sh

ENVIRONMENT=${1:-prod}
SNS_TOPIC_ARN="arn:aws:sns:eu-west-1:123456789012:accessweaver-alerts"

# Alerte: Taux d'erreur élevé pendant déploiement
aws cloudwatch put-metric-alarm \
    --alarm-name "AccessWeaver-${ENVIRONMENT}-Deployment-ErrorRate" \
    --alarm-description "High error rate during deployment" \
    --metric-name HTTPCode_Target_5XX_Count \
    --namespace AWS/ApplicationELB \
    --statistic Sum \
    --period 60 \
    --threshold 5 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --alarm-actions "$SNS_TOPIC_ARN" \
    --dimensions Name=LoadBalancer,Value=accessweaver-${ENVIRONMENT}-alb

# Alerte: Temps de réponse élevé
aws cloudwatch put-metric-alarm \
    --alarm-name "AccessWeaver-${ENVIRONMENT}-Deployment-HighLatency" \
    --alarm-description "High response time during deployment" \
    --metric-name TargetResponseTime \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --period 60 \
    --threshold 1.0 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 3 \
    --alarm-actions "$SNS_TOPIC_ARN" \
    --dimensions Name=LoadBalancer,Value=accessweaver-${ENVIRONMENT}-alb
```

---

## 🔄 Stratégie Recreate (Développement)

### Configuration ECS Recreate

```hcl
# terraform/environments/dev/ecs-recreate.tf
resource "aws_ecs_service" "recreate_deployment" {
  name            = "${var.project_name}-${var.environment}-${var.service_name}"
  cluster         = var.cluster_id
  task_definition = var.task_definition_arn
  desired_count   = 1

  # Configuration Recreate
  deployment_configuration {
    maximum_percent         = 100  # Pas de scaling up
    minimum_healthy_percent = 0    # Permet d'arrêter toutes les tâches
  }

  # Force replacement rapide
  force_new_deployment = true
}
```

### Script de Déploiement Recreate

```bash
#!/bin/bash
# deploy-recreate.sh - Déploiement rapide pour dev

set -e

SERVICE_NAME=${1:-aw-api-gateway}
IMAGE_TAG=${2:-latest}
ENVIRONMENT="dev"
CLUSTER_NAME="accessweaver-dev-cluster"

echo "🔄 Starting Recreate deployment for $SERVICE_NAME"

# 1. Arrêt de toutes les tâches
echo "⏹️ Stopping all running tasks..."
aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "accessweaver-dev-$SERVICE_NAME" \
    --desired-count 0

# 2. Attendre l'arrêt complet
echo "⏳ Waiting for tasks to stop..."
aws ecs wait services-stable \
    --cluster "$CLUSTER_NAME" \
    --services "accessweaver-dev-$SERVICE_NAME"

# 3. Update task definition avec nouvelle image
echo "📦 Updating task definition..."
TASK_DEF_JSON=$(aws ecs describe-task-definition \
    --task-definition "accessweaver-dev-$SERVICE_NAME" \
    --query 'taskDefinition')

# Mise à jour de l'image dans la task definition
NEW_TASK_DEF=$(echo "$TASK_DEF_JSON" | jq \
    --arg IMAGE "123456789012.dkr.ecr.eu-west-1.amazonaws.com/accessweaver/$SERVICE_NAME:$IMAGE_TAG" \
    '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)')

# 4. Enregistrement de la nouvelle task definition
echo "📝 Registering new task definition..."
NEW_TASK_ARN=$(echo "$NEW_TASK_DEF" | aws ecs register-task-definition --cli-input-json file:///dev/stdin --query 'taskDefinition.taskDefinitionArn' --output text)

# 5. Redémarrage du service avec la nouvelle image
echo "🚀 Starting service with new image..."
aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "accessweaver-dev-$SERVICE_NAME" \
    --task-definition "$NEW_TASK_ARN" \
    --desired-count 1

# 6. Attendre la stabilisation
echo "⏳ Waiting for new deployment to stabilize..."
aws ecs wait services-stable \
    --cluster "$CLUSTER_NAME" \
    --services "accessweaver-dev-$SERVICE_NAME"

# 7. Health check rapide
echo "🏥 Performing basic health check..."
sleep 30

if curl -f "http://accessweaver-dev-alb-123456789.eu-west-1.elb.amazonaws.com/actuator/health" > /dev/null 2>&1; then
    echo "✅ Recreate deployment completed successfully!"
else
    echo "❌ Health check failed - deployment may have issues"
    exit 1
fi

echo "🎉 $SERVICE_NAME deployed with image tag: $IMAGE_TAG"
```

---

## 📋 Comparatif des Stratégies par Environnement

### Matrice de Décision

| Critère | Dev | Staging | Prod |
|---------|-----|---------|------|
| **Stratégie Recommandée** | Recreate | Rolling Update | Blue/Green |
| **Alternative** | Rolling Update | Blue/Green | Canary |
| **Downtime Acceptable** | ✅ 30s-2min | ❌ Zero downtime | ❌ Zero downtime |
| **Budget** | 🟢 $100/mois | 🟡 $300/mois | 🔴 $900/mois |
| **Fréquence Déploiement** | 🔴 10+ par jour | 🟡 2-5 par jour | 🟢 1-2 par semaine |
| **Criticité Business** | 🟢 Non-critique | 🟡 Tests importants | 🔴 Production live |
| **Validation Requise** | Health check | Health + Metrics | Full validation |
| **Rollback** | Manuel rapide | Semi-automatique | Automatique |

### Configuration par Environnement

#### Développement
```yaml
deployment:
  strategy: recreate
  max_downtime: 120s
  health_check_timeout: 30s
  monitoring: basic
  alerting: disabled
  auto_rollback: false
```

#### Staging
```yaml
deployment:
  strategy: rolling_update
  max_surge: 100%
  max_unavailable: 25%
  health_check_timeout: 60s
  monitoring: enhanced
  alerting: development_team
  auto_rollback: on_health_failure
```

#### Production
```yaml
deployment:
  strategy: blue_green
  canary_option: available
  validation_duration: 300s
  health_check_timeout: 30s
  monitoring: full
  alerting: pagerduty + slack
  auto_rollback: on_any_failure
```

---

## 🛠 Troubleshooting et Rollback Automatique

### Scénarios de Rollback Automatique

```bash
#!/bin/bash
# automatic-rollback-triggers.sh

# Déclencheurs de rollback automatique
ROLLBACK_TRIGGERS=(
    "health_check_failure:3"        # 3 échecs consécutifs
    "error_rate_threshold:5.0"      # Taux d'erreur > 5%
    "response_time_p99:2000"        # P99 > 2 secondes
    "cpu_utilization:90"            # CPU > 90%
    "memory_utilization:95"         # Memory > 95%
    "deployment_timeout:600"        # Timeout après 10 minutes
)

check_rollback_conditions() {
    local service_name="$1"
    local deployment_id="$2"
    
    # Vérification des conditions de rollback
    for trigger in "${ROLLBACK_TRIGGERS[@]}"; do
        IFS=':' read -r condition threshold <<< "$trigger"
        
        case "$condition" in
            "health_check_failure")
                if check_consecutive_health_failures "$service_name" "$threshold"; then
                    echo "ROLLBACK_REQUIRED:Health check failures exceeded threshold"
                    return 0
                fi
                ;;
            "error_rate_threshold")
                current_error_rate=$(get_current_error_rate "$service_name")
                if (( $(echo "$current_error_rate > $threshold" | bc -l) )); then
                    echo "ROLLBACK_REQUIRED:Error rate $current_error_rate% > $threshold%"
                    return 0
                fi
                ;;
            "response_time_p99")
                current_p99=$(get_current_p99_response_time "$service_name")
                if (( $(echo "$current_p99 > $threshold" | bc -l) )); then
                    echo "ROLLBACK_REQUIRED:P99 response time ${current_p99}ms > ${threshold}ms"
                    return 0
                fi
                ;;
        esac
    done
    
    echo "CONTINUE:All conditions within thresholds"
    return 1
}
```

### Stratégie de Rollback par Environnement

```yaml
# rollback-strategy.yaml
rollback:
  dev:
    trigger: manual
    method: recreate
    timeout: 60s
    
  staging:
    trigger: automatic
    conditions:
      - health_failure_count: 3
      - error_rate: 5.0
    method: rolling_update
    timeout: 300s
    
  prod:
    trigger: automatic
    conditions:
      - health_failure_count: 2
      - error_rate: 2.0
      - response_time_p99: 1000
    method: instant_traffic_switch
    timeout: 30s
```

---

## ⚙️ Intégration CI/CD avec GitHub Actions

### Workflow Principal

```yaml
# .github/workflows/deploy-strategy.yml
name: AccessWeaver Deployment Strategy

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  AWS_REGION: eu-west-1
  ECR_REGISTRY: 123456789012.dkr.ecr.eu-west-1.amazonaws.com

jobs:
  determine-strategy:
    runs-on: ubuntu-latest
    outputs:
      strategy: ${{ steps.strategy.outputs.strategy }}
      environment: ${{ steps.strategy.outputs.environment }}
    steps:
      - name: Determine deployment strategy
        id: strategy
        run: |
          if [[ "${{ github.ref }}" == "refs/heads/develop" ]]; then
            echo "strategy=recreate" >> $GITHUB_OUTPUT
            echo "environment=dev" >> $GITHUB_OUTPUT
          elif [[ "${{ github.ref }}" == "refs/heads/main" && "${{ github.event_name }}" == "push" ]]; then
            echo "strategy=blue_green" >> $GITHUB_OUTPUT
            echo "environment=prod" >> $GITHUB_OUTPUT
          else
            echo "strategy=rolling_update" >> $GITHUB_OUTPUT
            echo "environment=staging" >> $GITHUB_OUTPUT
          fi

  deploy-recreate:
    if: needs.determine-strategy.outputs.strategy == 'recreate'
    needs: determine-strategy
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy with Recreate
        run: |
          ./scripts/deploy-recreate.sh aw-api-gateway ${{ github.sha }}

  deploy-rolling:
    if: needs.determine-strategy.outputs.strategy == 'rolling_update'
    needs: determine-strategy
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy with Rolling Update
        run: |
          ./scripts/deploy-rolling.sh aw-api-gateway ${{ github.sha }}

  deploy-blue-green:
    if: needs.determine-strategy.outputs.strategy == 'blue_green'
    needs: determine-strategy
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy with Blue/Green
        run: |
          ./scripts/deploy-blue-green.sh aw-api-gateway ${{ github.sha }}
      - name: Validate deployment
        run: |
          ./scripts/validate-canary.sh prod aw-api-gateway 100 180
```

### Pipeline de Validation Continue

```yaml
# .github/workflows/deployment-validation.yml
name: Continuous Deployment Validation

on:
  workflow_run:
    workflows: ["AccessWeaver Deployment Strategy"]
    types: [completed]

jobs:
  post-deployment-validation:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    steps:
      - name: Extended health validation
        run: |
          # Tests approfondis post-déploiement
          ./scripts/extended-health-check.sh
          
      - name: Business logic validation
        run: |
          # Tests des fonctionnalités critiques
          ./scripts/business-validation.sh
          
      - name: Performance baseline
        run: |
          # Établissement de nouvelles baselines
          ./scripts/performance-baseline.sh
```

---

## 📈 Métriques et KPIs de Déploiement

### Tableau de Bord des Déploiements

| Métrique | Dev | Staging | Prod | Objectif |
|----------|-----|---------|------|----------|
| **Deployment Frequency** | 10+/jour | 2-5/jour | 1-2/semaine | Augmenter |
| **Lead Time** | <30min | <60min | <2h | Réduire |
| **MTTR** | <5min | <15min | <30min | Réduire |
| **Change Failure Rate** | <10% | <5% | <2% | Réduire |
| **Deployment Success Rate** | >90% | >95% | >99% | Augmenter |

### Scripts de Collecte de Métriques

```bash
#!/bin/bash
# collect-deployment-metrics.sh

ENVIRONMENT=${1:-prod}
DEPLOYMENT_ID=${2:-$(date +%s)}
SERVICE_NAME=${3:-aw-api-gateway}

# =============================================================================
# Collecte des métriques de déploiement
# =============================================================================

collect_deployment_metrics() {
    local start_time="$1"
    local end_time="$2"
    
    echo "📊 Collecting deployment metrics..."
    
    # Métriques ALB
    local total_requests=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/ApplicationELB \
        --metric-name RequestCount \
        --dimensions Name=LoadBalancer,Value=accessweaver-${ENVIRONMENT}-alb \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 60 \
        --statistics Sum \
        --query 'Datapoints[].Value' \
        --output text | awk '{sum+=$1} END {print sum}')
    
    local error_count=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/ApplicationELB \
        --metric-name HTTPCode_Target_5XX_Count \
        --dimensions Name=LoadBalancer,Value=accessweaver-${ENVIRONMENT}-alb \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 60 \
        --statistics Sum \
        --query 'Datapoints[].Value' \
        --output text | awk '{sum+=$1} END {print sum}')
    
    # Calcul du taux d'erreur
    local error_rate=0
    if [[ "$total_requests" -gt 0 ]]; then
        error_rate=$(echo "scale=2; ($error_count / $total_requests) * 100" | bc)
    fi
    
    # Métriques ECS
    local cpu_avg=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/ECS \
        --metric-name CPUUtilization \
        --dimensions Name=ServiceName,Value=accessweaver-${ENVIRONMENT}-${SERVICE_NAME} Name=ClusterName,Value=accessweaver-${ENVIRONMENT}-cluster \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 300 \
        --statistics Average \
        --query 'Datapoints[].Value' \
        --output text | awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')
    
    # Stockage des métriques
    cat > "/tmp/deployment-metrics-${DEPLOYMENT_ID}.json" << EOF
{
    "deployment_id": "$DEPLOYMENT_ID",
    "environment": "$ENVIRONMENT",
    "service_name": "$SERVICE_NAME",
    "timestamp": "$(date -Iseconds)",
    "metrics": {
        "total_requests": $total_requests,
        "error_count": $error_count,
        "error_rate_percent": $error_rate,
        "average_cpu_utilization": $cpu_avg,
        "deployment_duration_seconds": $(($(date -d "$end_time" +%s) - $(date -d "$start_time" +%s)))
    }
}
EOF
    
    echo "✅ Metrics collected: Error rate ${error_rate}%, Avg CPU ${cpu_avg}%"
}

# Envoi vers système de métriques (CloudWatch Custom)
send_custom_metrics() {
    local deployment_metrics="$1"
    
    # Parse JSON metrics
    local error_rate=$(echo "$deployment_metrics" | jq -r '.metrics.error_rate_percent')
    local duration=$(echo "$deployment_metrics" | jq -r '.metrics.deployment_duration_seconds')
    
    # Envoi vers CloudWatch Custom Metrics
    aws cloudwatch put-metric-data \
        --namespace "AccessWeaver/Deployments" \
        --metric-data \
        MetricName=DeploymentErrorRate,Value=$error_rate,Unit=Percent,Dimensions=Environment=$ENVIRONMENT,Service=$SERVICE_NAME \
        MetricName=DeploymentDuration,Value=$duration,Unit=Seconds,Dimensions=Environment=$ENVIRONMENT,Service=$SERVICE_NAME
    
    echo "📈 Custom metrics sent to CloudWatch"
}
```

---

## 🚨 Alerting et Notifications Avancées

### Configuration Slack/Teams

```bash
#!/bin/bash
# notification-system.sh

send_deployment_notification() {
    local status="$1"           # SUCCESS, FAILED, STARTED, ROLLBACK
    local environment="$2"
    local service="$3"
    local details="$4"
    
    local color=""
    local emoji=""
    local urgency=""
    
    case "$status" in
        "STARTED")
            color="#36a64f"
            emoji="🚀"
            urgency="info"
            ;;
        "SUCCESS")
            color="#36a64f"
            emoji="✅"
            urgency="info"
            ;;
        "FAILED")
            color="#ff0000"
            emoji="❌"
            urgency="critical"
            ;;
        "ROLLBACK")
            color="#ff9900"
            emoji="🔄"
            urgency="warning"
            ;;
    esac
    
    # Notification Slack
    if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
        local slack_payload=$(cat << EOF
{
    "attachments": [
        {
            "color": "$color",
            "title": "$emoji AccessWeaver Deployment $status",
            "fields": [
                {
                    "title": "Environment",
                    "value": "$environment",
                    "short": true
                },
                {
                    "title": "Service",
                    "value": "$service",
                    "short": true
                },
                {
                    "title": "Details",
                    "value": "$details",
                    "short": false
                },
                {
                    "title": "Timestamp",
                    "value": "$(date -Iseconds)",
                    "short": true
                }
            ]
        }
    ]
}
EOF
        )
        
        curl -X POST -H 'Content-type: application/json' \
             --data "$slack_payload" \
             "$SLACK_WEBHOOK_URL"
    fi
    
    # Notification PagerDuty (prod uniquement)
    if [[ "$environment" == "prod" && "$urgency" == "critical" && -n "$PAGERDUTY_ROUTING_KEY" ]]; then
        local pagerduty_payload=$(cat << EOF
{
    "routing_key": "$PAGERDUTY_ROUTING_KEY",
    "event_action": "trigger",
    "dedup_key": "accessweaver-deployment-$service-$environment",
    "payload": {
        "summary": "AccessWeaver Production Deployment Failed - $service",
        "severity": "critical",
        "source": "deployment-system",
        "custom_details": {
            "environment": "$environment",
            "service": "$service",
            "details": "$details"
        }
    }
}
EOF
        )
        
        curl -X POST -H 'Content-type: application/json' \
             --data "$pagerduty_payload" \
             "https://events.pagerduty.com/v2/enqueue"
    fi
}

# Notification avec contexte enrichi
send_enriched_notification() {
    local status="$1"
    local environment="$2"
    local service="$3"
    
    # Collecte d'informations contextuelles
    local commit_sha=$(git rev-parse --short HEAD)
    local commit_author=$(git log -1 --pretty=format:'%an')
    local commit_message=$(git log -1 --pretty=format:'%s')
    local deployment_url="https://console.aws.amazon.com/ecs/home?region=eu-west-1#/clusters/accessweaver-${environment}-cluster/services"
    
    local details="
**Commit:** \`$commit_sha\` by $commit_author
**Message:** $commit_message
**Dashboard:** [View Deployment]($deployment_url)
"
    
    send_deployment_notification "$status" "$environment" "$service" "$details"
}
```

---

## 🔧 Scripts d'Automatisation Complets

### Script Universel de Déploiement

```bash
#!/bin/bash
# deploy-universal.sh - Script intelligent de déploiement

set -e

# =============================================================================
# Configuration
# =============================================================================
ENVIRONMENT=${1:-staging}
SERVICE_NAME=${2:-aw-api-gateway}
IMAGE_TAG=${3:-latest}
STRATEGY=${4:-auto}  # auto, recreate, rolling, blue_green, canary

# Validation des paramètres
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "❌ Invalid environment: $ENVIRONMENT"
    exit 1
fi

# Détection automatique de la stratégie
detect_deployment_strategy() {
    if [[ "$STRATEGY" == "auto" ]]; then
        case "$ENVIRONMENT" in
            "dev")
                echo "recreate"
                ;;
            "staging")
                echo "rolling_update"
                ;;
            "prod")
                # Analyse du risque du changement
                local risk_level=$(analyze_change_risk)
                if [[ "$risk_level" == "high" ]]; then
                    echo "canary"
                else
                    echo "blue_green"
                fi
                ;;
        esac
    else
        echo "$STRATEGY"
    fi
}

analyze_change_risk() {
    # Analyse des changements pour déterminer le risque
    local changed_files=$(git diff --name-only HEAD~1)
    local risk="low"
    
    # Fichiers à haut risque
    if echo "$changed_files" | grep -E "(database|migration|schema)" > /dev/null; then
        risk="high"
    fi
    
    if echo "$changed_files" | grep -E "(security|auth|permission)" > /dev/null; then
        risk="high"
    fi
    
    # Taille du changement
    local lines_changed=$(git diff --stat HEAD~1 | tail -1 | awk '{print $4}')
    if [[ "$lines_changed" -gt 500 ]]; then
        risk="high"
    fi
    
    echo "$risk"
}

# =============================================================================
# Orchestrateur principal
# =============================================================================
main() {
    local detected_strategy=$(detect_deployment_strategy)
    
    echo "🚀 AccessWeaver Deployment Orchestrator"
    echo "   Environment: $ENVIRONMENT"
    echo "   Service: $SERVICE_NAME"
    echo "   Image Tag: $IMAGE_TAG"
    echo "   Strategy: $detected_strategy"
    echo ""
    
    # Notification de début
    send_enriched_notification "STARTED" "$ENVIRONMENT" "$SERVICE_NAME"
    
    # Pré-déploiement
    echo "🔍 Pre-deployment checks..."
    if ! run_pre_deployment_checks; then
        send_enriched_notification "FAILED" "$ENVIRONMENT" "$SERVICE_NAME"
        exit 1
    fi
    
    # Déploiement selon la stratégie
    local deployment_start=$(date +%s)
    
    case "$detected_strategy" in
        "recreate")
            ./scripts/deploy-recreate.sh "$SERVICE_NAME" "$IMAGE_TAG"
            ;;
        "rolling_update")
            ./scripts/deploy-rolling.sh "$SERVICE_NAME" "$IMAGE_TAG"
            ;;
        "blue_green")
            ./scripts/deploy-blue-green.sh "$SERVICE_NAME" "$IMAGE_TAG"
            ;;
        "canary")
            ./scripts/deploy-canary.sh "$SERVICE_NAME" "$IMAGE_TAG"
            ;;
        *)
            echo "❌ Unknown deployment strategy: $detected_strategy"
            exit 1
            ;;
    esac
    
    local deployment_end=$(date +%s)
    local duration=$((deployment_end - deployment_start))
    
    # Post-déploiement
    echo "✅ Deployment completed in ${duration}s"
    
    # Validation post-déploiement
    if run_post_deployment_validation "$detected_strategy"; then
        send_enriched_notification "SUCCESS" "$ENVIRONMENT" "$SERVICE_NAME"
        echo "🎉 Deployment successful!"
    else
        send_enriched_notification "FAILED" "$ENVIRONMENT" "$SERVICE_NAME"
        echo "💥 Post-deployment validation failed!"
        exit 1
    fi
}

run_pre_deployment_checks() {
    echo "  ✓ Checking AWS connectivity..."
    aws sts get-caller-identity > /dev/null
    
    echo "  ✓ Verifying ECR image exists..."
    aws ecr describe-images \
        --repository-name "accessweaver/$SERVICE_NAME" \
        --image-ids imageTag="$IMAGE_TAG" > /dev/null
    
    echo "  ✓ Checking cluster health..."
    local cluster_status=$(aws ecs describe-clusters \
        --clusters "accessweaver-${ENVIRONMENT}-cluster" \
        --query 'clusters[0].status' \
        --output text)
    
    if [[ "$cluster_status" != "ACTIVE" ]]; then
        echo "❌ Cluster not active: $cluster_status"
        return 1
    fi
    
    return 0
}

run_post_deployment_validation() {
    local strategy="$1"
    
    case "$strategy" in
        "recreate"|"rolling_update")
            # Validation basique
            sleep 30
            curl -f "https://accessweaver-${ENVIRONMENT}.com/actuator/health"
            ;;
        "blue_green"|"canary")
            # Validation complète
            ./scripts/validate-canary.sh "$ENVIRONMENT" "$SERVICE_NAME" 100 180
            ;;
    esac
}

# Gestion des signaux pour cleanup
cleanup() {
    echo "🧹 Cleaning up deployment process..."
    # Cleanup logic ici
}

trap cleanup EXIT

main "$@"
```

---

## 📋 Checklist de Déploiement par Environnement

### Développement (Recreate)
```markdown
## Pre-Deployment
- [ ] Code compilé et testé localement
- [ ] Image Docker buildée et pushée
- [ ] Variables d'environnement vérifiées

## Deployment
- [ ] Service arrêté proprement
- [ ] Nouvelle image déployée
- [ ] Health check basique passé

## Post-Deployment
- [ ] API accessible
- [ ] Fonctionnalités de base testées
- [ ] Logs vérifiés pour erreurs
```

### Staging (Rolling Update)
```markdown
## Pre-Deployment
- [ ] Tests unitaires passés (>90% coverage)
- [ ] Tests d'intégration validés
- [ ] Image scannée pour vulnérabilités
- [ ] Configuration staging vérifiée

## Deployment
- [ ] Rolling update démarré
- [ ] Health checks progressifs
- [ ] Métriques surveillées
- [ ] Rollback automatique configuré

## Post-Deployment
- [ ] Tests end-to-end automatisés
- [ ] Performance baseline établie
- [ ] Monitoring alertes vérifiées
- [ ] Documentation mise à jour
```

### Production (Blue/Green + Canary)
```markdown
## Pre-Deployment
- [ ] Approbation change management
- [ ] Backup de configuration actuelle
- [ ] Plan de rollback documenté
- [ ] Équipe on-call notifiée
- [ ] Maintenance window planifiée

## Deployment
- [ ] Blue/Green switch préparé
- [ ] Validation canary (si applicable)
- [ ] Métriques business surveillées
- [ ] Alerting temps réel actif

## Post-Deployment
- [ ] Tests de régression complets
- [ ] Monitoring 24h continu
- [ ] Performance comparée à baseline
- [ ] Incident response team notifiée
- [ ] Post-mortem plannifié (si issues)
```

---

## 🔄 Evolution et Optimisation Continue

### Métriques d'Amélioration Continue

```bash
#!/bin/bash
# deployment-optimization.sh

# Analyse des tendances de déploiement
analyze_deployment_trends() {
    local environment="$1"
    local days_back="${2:-30}"
    
    echo "📈 Analyzing deployment trends for $environment (last $days_back days)"
    
    # Requête CloudWatch pour métriques custom
    local avg_duration=$(aws cloudwatch get-metric-statistics \
        --namespace "AccessWeaver/Deployments" \
        --metric-name DeploymentDuration \
        --dimensions Name=Environment,Value="$environment" \
        --start-time "$(date -d "$days_back days ago" -Iseconds)" \
        --end-time "$(date -Iseconds)" \
        --period 86400 \
        --statistics Average \
        --query 'Datapoints[].Value' \
        --output text | awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')
    
    local success_rate=$(aws cloudwatch get-metric-statistics \
        --namespace "AccessWeaver/Deployments" \
        --metric-name DeploymentSuccess \
        --dimensions Name=Environment,Value="$environment" \
        --start-time "$(date -d "$days_back days ago" -Iseconds)" \
        --end-time "$(date -Iseconds)" \
        --period 86400 \
        --statistics Average \
        --query 'Datapoints[].Value' \
        --output text | awk '{sum+=$1; count++} END {if(count>0) print (sum/count)*100; else print 0}')
    
    # Génération du rapport
    cat << EOF

🎯 Deployment Performance Report - $environment
═══════════════════════════════════════════════

Average Deployment Duration: ${avg_duration}s
Success Rate: ${success_rate}%

Recommendations:
EOF
    
    # Recommandations basées sur les métriques
    if (( $(echo "$avg_duration > 600" | bc -l) )); then
        echo "⚠️  Consider optimizing deployment duration (current: ${avg_duration}s)"
    fi
    
    if (( $(echo "$success_rate < 95" | bc -l) )); then
        echo "⚠️  Success rate below target (current: ${success_rate}%)"
    fi
}

# Suggestions d'optimisation automatiques
suggest_optimizations() {
    local environment="$1"
    
    echo "💡 Deployment Optimization Suggestions:"
    
    case "$environment" in
        "dev")
            echo "  • Consider implementing feature flags to reduce deployment frequency"
            echo "  • Optimize Docker image layers for faster recreate deployments"
            ;;
        "staging")
            echo "  • Implement automated performance testing in deployment pipeline"
            echo "  • Consider parallel deployment for independent services"
            ;;
        "prod")
            echo "  • Evaluate canary deployment for high-risk changes"
            echo "  • Implement automated rollback based on business metrics"
            ;;
    esac
}
```

---

## 📚 Ressources et Documentation

### Scripts de Formation

```bash
#!/bin/bash
# deployment-training.sh - Simulation de déploiement pour formation

simulate_deployment_scenario() {
    local scenario="$1"
    
    case "$scenario" in
        "rollback")
            echo "🎭 Simulating failed deployment requiring rollback..."
            # Simulation d'échec contrôlé
            ;;
        "canary")
            echo "🎭 Simulating canary deployment with gradual traffic increase..."
            # Simulation canary
            ;;
        "disaster")
            echo "🎭 Simulating disaster recovery scenario..."
            # Simulation disaster recovery
            ;;
    esac
}

# Menu interactif pour formation
deployment_training_menu() {
    echo "🎓 AccessWeaver Deployment Training"
    echo "1. Recreate deployment (dev)"
    echo "2. Rolling update (staging)"  
    echo "3. Blue/Green deployment (prod)"
    echo "4. Canary deployment (prod)"
    echo "5. Rollback scenario"
    echo "6. Disaster recovery"
    
    read -p "Select scenario (1-6): " choice
    
    case "$choice" in
        1) simulate_deployment_scenario "recreate" ;;
        2) simulate_deployment_scenario "rolling" ;;
        3) simulate_deployment_scenario "blue_green" ;;
        4) simulate_deployment_scenario "canary" ;;
        5) simulate_deployment_scenario "rollback" ;;
        6) simulate_deployment_scenario "disaster" ;;
        *) echo "Invalid choice" ;;
    esac
}
```

### Documentation des Runbooks

```markdown
## 🆘 Runbook - Deployment Emergency Procedures

### Incident: Deployment Failed in Production

#### Immediate Actions (0-5 minutes)
1. **Stop ongoing deployment**
   ```bash
   aws ecs update-service --cluster accessweaver-prod-cluster \
     --service accessweaver-prod-aw-api-gateway --desired-count 0
   ```

2. **Activate incident response**
    - Notify on-call engineer
    - Create incident in PagerDuty
    - Start incident bridge call

3. **Assess impact**
    - Check error rates in CloudWatch
    - Verify customer impact via support channels

#### Recovery Actions (5-30 minutes)
1. **Execute rollback**
   ```bash
   ./scripts/emergency-rollback.sh prod aw-api-gateway
   ```

2. **Verify recovery**
    - Health checks passing
    - Error rates normalized
    - Customer services restored

#### Post-Incident (30+ minutes)
1. **Root cause analysis**
2. **Update runbooks**
3. **Improve deployment process**
```

---

## 🎯 Conclusion et Recommandations

### Matrice de Décision Finale

| Situation | Stratégie Recommandée | Justification |
|-----------|----------------------|---------------|
| **Feature mineure dev** | Recreate | Rapidité, simplicité |
| **Bug fix urgent staging** | Rolling Update | Zero downtime, validation rapide |
| **Release majeure prod** | Blue/Green | Sécurité, rollback instantané |
| **Feature expérimentale** | Canary | Validation progressive, risque contrôlé |
| **Hotfix critique** | Blue/Green | Déploiement rapide, sécurisé |

### Prochaines Évolutions

1. **GitOps avec ArgoCD**
   - Déploiement déclaratif
   - Synchronisation automatique
   - Rollback via Git

2. **Feature Flags avancés**
   - Déploiement découplé de l'activation
   - Tests A/B natifs
   - Rollback feature-level

3. **Deployment as Code**
   - Configuration Terraform des stratégies
   - Versioning des configurations de déploiement
   - Validation automatique des changements

4. **Machine Learning pour prédiction**
   - Prédiction des risques de déploiement
   - Optimisation automatique des seuils
   - Détection d'anomalies précoce

---

**📖 Cette documentation est vivante** - mise à jour après chaque incident et amélioration du processus de déploiement.

**🔄 Révision recommandée** : Trimestrielle avec l'équipe DevOps et les retours d'expérience des déploiements.
