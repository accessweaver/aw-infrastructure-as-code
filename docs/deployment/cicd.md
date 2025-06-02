# 🔄 CI/CD Pipeline - AccessWeaver

Guide complet pour déployer AccessWeaver avec GitHub Actions, incluant tests automatisés, déploiements multi-environnements et monitoring pipeline.

## 🎯 Vue d'Ensemble

### ✅ Pipeline Automatisé Complet
- **Déploiement automatique** sur 3 environnements (dev/staging/prod)
- **Tests multi-niveaux** : unit, integration, e2e, infrastructure
- **Validation sécurité** : scanning, compliance, vulnerability assessment
- **Zero-downtime deployments** avec rollback automatique
- **Monitoring pipeline** avec notifications Slack/Teams

### ✅ Stratégie GitOps
- **Dev** : Auto-deploy sur push `main` (développement continu)
- **Staging** : Auto-deploy sur merge PR → `main` (validation pré-prod)
- **Prod** : Manual deploy sur tag release `v*` (contrôle strict)

### ✅ Architecture Pipeline
```
┌─────────────────────────────────────────────────────────┐
│                    GitHub Actions                       │
│                                                         │
│  🔄 Trigger Events:                                     │
│    • Push main → Deploy Dev                             │
│    • PR merge → Deploy Staging                         │
│    • Tag v* → Deploy Prod (manual approval)            │
│                                                         │
│  🧪 Test Stages:                                        │
│    • Unit Tests (Java + Terraform)                     │
│    • Integration Tests (API + Infrastructure)          │
│    • Security Scanning (SAST, DAST, Infrastructure)    │
│    • Performance Tests (Load + Stress)                 │
│                                                         │
│  🚀 Deploy Stages:                                      │
│    • Terraform Plan + Validation                       │
│    • Infrastructure Deployment                         │
│    • Application Deployment                            │
│    • Health Checks + Smoke Tests                       │
│                                                         │
│  📊 Monitoring:                                         │
│    • Pipeline Metrics                                   │
│    • Deployment Status                                  │
│    • Notifications (Slack/Teams)                       │
│    • Rollback Triggers                                  │
└─────────────────────────────────────────────────────────┘
```

## 📁 Structure CI/CD Repository

### Repository Setup

Créer le repository principal : `accessweaver-cicd`

```
accessweaver-cicd/
├── .github/
│   ├── workflows/
│   │   ├── 01-dev-deployment.yml         # Pipeline dev automatique
│   │   ├── 02-staging-deployment.yml     # Pipeline staging PR-based
│   │   ├── 03-prod-deployment.yml        # Pipeline prod manual
│   │   ├── 04-infrastructure-tests.yml   # Tests infra dédiés
│   │   ├── 05-security-scan.yml          # Security scanning
│   │   └── 06-performance-tests.yml      # Load testing
│   ├── scripts/
│   │   ├── terraform-plan.sh             # Script Terraform plan
│   │   ├── terraform-apply.sh            # Script Terraform apply
│   │   ├── health-check.sh               # Health checks post-deploy
│   │   ├── rollback.sh                   # Rollback automatique
│   │   └── notify-slack.sh               # Notifications Slack
│   └── templates/
│       ├── terraform-plan-comment.md     # Template PR comment
│       └── deployment-report.md          # Template rapport déploiement
├── terraform/
│   ├── environments/ → symlink to aw-infrastructure-as-code
│   └── modules/ → symlink to aw-infrastructure-as-code
├── tests/
│   ├── integration/                      # Tests d'intégration
│   ├── e2e/                             # Tests end-to-end
│   ├── performance/                     # Tests de performance
│   └── security/                        # Tests de sécurité
├── config/
│   ├── dev.env                          # Variables dev
│   ├── staging.env                      # Variables staging
│   └── prod.env                         # Variables prod
└── docs/
    ├── pipeline-overview.md             # Vue d'ensemble
    ├── troubleshooting.md               # Guide dépannage
    └── rollback-procedures.md           # Procédures rollback
```

## 🔧 Configuration GitHub Repository

### 1. Secrets GitHub Actions

```bash
# AWS Credentials par environnement
AWS_ACCESS_KEY_ID_DEV
AWS_SECRET_ACCESS_KEY_DEV
AWS_ACCESS_KEY_ID_STAGING  
AWS_SECRET_ACCESS_KEY_STAGING
AWS_ACCESS_KEY_ID_PROD
AWS_SECRET_ACCESS_KEY_PROD

# Terraform Backend
TF_BACKEND_BUCKET_DEV=accessweaver-terraform-state-dev-123456789012
TF_BACKEND_BUCKET_STAGING=accessweaver-terraform-state-staging-123456789012
TF_BACKEND_BUCKET_PROD=accessweaver-terraform-state-prod-123456789012

# Application Secrets
DATABASE_PASSWORD_DEV
DATABASE_PASSWORD_STAGING  
DATABASE_PASSWORD_PROD
REDIS_AUTH_TOKEN_DEV
REDIS_AUTH_TOKEN_STAGING
REDIS_AUTH_TOKEN_PROD
JWT_SECRET_DEV
JWT_SECRET_STAGING
JWT_SECRET_PROD

# Monitoring & Notifications
SLACK_WEBHOOK_URL
TEAMS_WEBHOOK_URL
DATADOG_API_KEY
PINGDOM_API_KEY

# Container Registry
ECR_REGISTRY=123456789012.dkr.ecr.eu-west-1.amazonaws.com
DOCKER_HUB_USERNAME
DOCKER_HUB_TOKEN
```

### 2. Environment Protection Rules

```yaml
# Repository Settings → Environments
environments:
  development:
    protection_rules: none
    secrets: dev_secrets
    
  staging:
    protection_rules:
      - required_reviewers: 1
      - wait_timer: 0
    secrets: staging_secrets
    
  production:
    protection_rules:
      - required_reviewers: 2
      - wait_timer: 30  # 30 minutes
      - required_status_checks: 
          - staging-deployment
          - security-scan
          - performance-tests
    secrets: prod_secrets
```

## 🚀 Pipeline 1 : Développement Auto-Deploy

### `.github/workflows/01-dev-deployment.yml`

```yaml
name: 🔄 Dev Auto-Deployment

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'
      - 'src/**'
      - 'docker/**'
      - '.github/workflows/**'
  workflow_dispatch:

env:
  AWS_REGION: eu-west-1
  ENVIRONMENT: dev
  TF_VERSION: 1.6.0

jobs:
  # =========================================================================
  # Job 1: Tests Préalables
  # =========================================================================
  tests:
    name: 🧪 Tests & Validation
    runs-on: ubuntu-latest
    environment: development
    
    steps:
      - name: 📥 Checkout Code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: ☕ Setup Java 21
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'

      - name: 🏗️ Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: 🔧 Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID_DEV }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY_DEV }}
          aws-region: ${{ env.AWS_REGION }}

      - name: 🧪 Unit Tests - Java
        run: |
          cd src/
          ./mvnw clean test
          
      - name: 🧪 Unit Tests - Terraform
        run: |
          cd terraform/
          terraform fmt -check -recursive
          terraform validate -recursive

      - name: 📊 SonarQube Analysis
        uses: sonarqube-quality-gate-action@master
        with:
          scanMetadataReportFile: target/sonar/report-task.txt
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}

      - name: 🔒 Security Scan - SAST
        uses: github/codeql-action/analyze@v3
        with:
          languages: java

  # =========================================================================
  # Job 2: Build & Push Images
  # =========================================================================
  build:
    name: 🏗️ Build & Push Images
    runs-on: ubuntu-latest
    needs: tests
    environment: development
    
    outputs:
      image-tag: ${{ steps.build.outputs.image-tag }}
    
    steps:
      - name: 📥 Checkout Code
        uses: actions/checkout@v4

      - name: 🔧 Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID_DEV }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY_DEV }}
          aws-region: ${{ env.AWS_REGION }}

      - name: 🔐 Login to ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: 🏗️ Build and Push Images
        id: build
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: dev-${{ github.sha }}
        run: |
          # Build all AccessWeaver services
          services=("aw-api-gateway" "aw-pdp-service" "aw-pap-service" "aw-tenant-service" "aw-audit-service")
          
          for service in "${services[@]}"; do
            echo "🏗️ Building $service..."
            docker build -t $ECR_REGISTRY/accessweaver/$service:$IMAGE_TAG ./src/$service/
            docker build -t $ECR_REGISTRY/accessweaver/$service:dev-latest ./src/$service/
            
            echo "📤 Pushing $service..."
            docker push $ECR_REGISTRY/accessweaver/$service:$IMAGE_TAG
            docker push $ECR_REGISTRY/accessweaver/$service:dev-latest
          done
          
          echo "image-tag=$IMAGE_TAG" >> $GITHUB_OUTPUT

  # =========================================================================
  # Job 3: Infrastructure Deployment
  # =========================================================================
  deploy-infrastructure:
    name: 🏗️ Deploy Infrastructure
    runs-on: ubuntu-latest
    needs: [tests, build]
    environment: development
    
    steps:
      - name: 📥 Checkout Code
        uses: actions/checkout@v4

      - name: 🏗️ Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: 🔧 Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID_DEV }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY_DEV }}
          aws-region: ${{ env.AWS_REGION }}

      - name: 📋 Terraform Plan
        id: plan
        run: |
          cd terraform/environments/dev/
          
          # Initialize
          terraform init \
            -backend-config="bucket=${{ secrets.TF_BACKEND_BUCKET_DEV }}" \
            -backend-config="key=dev/terraform.tfstate" \
            -backend-config="region=${{ env.AWS_REGION }}"
          
          # Plan
          terraform plan \
            -var="image_tag=${{ needs.build.outputs.image-tag }}" \
            -var="database_password=${{ secrets.DATABASE_PASSWORD_DEV }}" \
            -var="redis_auth_token=${{ secrets.REDIS_AUTH_TOKEN_DEV }}" \
            -out=tfplan

      - name: 🚀 Terraform Apply
        if: steps.plan.outcome == 'success'
        run: |
          cd terraform/environments/dev/
          terraform apply -auto-approve tfplan

      - name: 📊 Export Terraform Outputs
        id: outputs
        run: |
          cd terraform/environments/dev/
          ALB_DNS=$(terraform output -raw alb_dns_name)
          API_URL=$(terraform output -raw public_url)
          
          echo "alb-dns=$ALB_DNS" >> $GITHUB_OUTPUT
          echo "api-url=$API_URL" >> $GITHUB_OUTPUT

  # =========================================================================
  # Job 4: Application Deployment
  # =========================================================================
  deploy-application:
    name: 🚀 Deploy Application
    runs-on: ubuntu-latest
    needs: [build, deploy-infrastructure]
    environment: development
    
    steps:
      - name: 📥 Checkout Code
        uses: actions/checkout@v4

      - name: 🔧 Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID_DEV }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY_DEV }}
          aws-region: ${{ env.AWS_REGION }}

      - name: 🚀 Update ECS Services
        run: |
          services=("aw-api-gateway" "aw-pdp-service" "aw-pap-service" "aw-tenant-service" "aw-audit-service")
          
          for service in "${services[@]}"; do
            echo "🔄 Updating $service..."
            
            aws ecs update-service \
              --cluster accessweaver-dev-cluster \
              --service accessweaver-dev-$service \
              --force-new-deployment
              
            echo "⏳ Waiting for $service to be stable..."
            aws ecs wait services-stable \
              --cluster accessweaver-dev-cluster \
              --services accessweaver-dev-$service \
              --max-attempts 30 \
              --delay 30
              
            echo "✅ $service updated successfully"
          done

  # =========================================================================
  # Job 5: Health Checks & Validation
  # =========================================================================
  health-checks:
    name: 🏥 Health Checks
    runs-on: ubuntu-latest
    needs: [deploy-infrastructure, deploy-application]
    environment: development
    
    steps:
      - name: 📥 Checkout Code
        uses: actions/checkout@v4

      - name: 🏥 API Health Checks
        env:
          API_URL: ${{ needs.deploy-infrastructure.outputs.api-url }}
        run: |
          echo "🔍 Testing API health at $API_URL"
          
          # Wait for services to be ready
          sleep 60
          
          # Health check endpoints
          endpoints=(
            "$API_URL/actuator/health"
            "$API_URL/actuator/info"
            "$API_URL/api/v1/health"
          )
          
          for endpoint in "${endpoints[@]}"; do
            echo "🔍 Testing $endpoint"
            
            response=$(curl -s -o /dev/null -w "%{http_code}" "$endpoint" || echo "000")
            
            if [ "$response" = "200" ]; then
              echo "✅ $endpoint - OK ($response)"
            else
              echo "❌ $endpoint - FAILED ($response)"
              exit 1
            fi
          done

      - name: 🧪 Smoke Tests
        env:
          API_URL: ${{ needs.deploy-infrastructure.outputs.api-url }}
        run: |
          # Test API functionality
          ./.github/scripts/smoke-tests.sh "$API_URL"

  # =========================================================================
  # Job 6: Notifications
  # =========================================================================
  notify:
    name: 📢 Notifications
    runs-on: ubuntu-latest
    needs: [tests, build, deploy-infrastructure, deploy-application, health-checks]
    if: always()
    
    steps:
      - name: 📢 Slack Notification
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          channel: '#accessweaver-deployments'
          webhook_url: ${{ secrets.SLACK_WEBHOOK_URL }}
          fields: repo,message,commit,author,action,eventName,ref,workflow
          custom_payload: |
            {
              "text": "🔄 Dev Deployment",
              "attachments": [{
                "color": "${{ job.status == 'success' && 'good' || 'danger' }}",
                "fields": [{
                  "title": "Environment",
                  "value": "Development",
                  "short": true
                }, {
                  "title": "Status",
                  "value": "${{ job.status }}",
                  "short": true
                }, {
                  "title": "API URL",
                  "value": "${{ needs.deploy-infrastructure.outputs.api-url }}",
                  "short": false
                }]
              }]
            }
```

## 🎭 Pipeline 2 : Staging PR-Based

### `.github/workflows/02-staging-deployment.yml`

```yaml
name: 🎭 Staging Deployment

on:
  pull_request:
    types: [closed]
    branches: [main]
  workflow_dispatch:

env:
  AWS_REGION: eu-west-1
  ENVIRONMENT: staging
  TF_VERSION: 1.6.0

jobs:
  # =========================================================================
  # Job 1: Pre-deployment Validation
  # =========================================================================
  validate:
    name: ✅ Pre-deployment Validation
    runs-on: ubuntu-latest
    if: github.event.pull_request.merged == true
    environment: staging
    
    steps:
      - name: 📥 Checkout Code
        uses: actions/checkout@v4

      - name: 🔍 Validate Deployment Readiness
        run: |
          # Check if dev deployment was successful
          echo "🔍 Checking dev deployment status..."
          
          # Validate infrastructure state
          echo "🏗️ Validating infrastructure requirements..."
          
          # Check security scan results
          echo "🔒 Validating security requirements..."

  # =========================================================================
  # Job 2: Comprehensive Testing
  # =========================================================================
  comprehensive-tests:
    name: 🧪 Comprehensive Testing
    runs-on: ubuntu-latest
    needs: validate
    environment: staging
    
    steps:
      - name: 📥 Checkout Code
        uses: actions/checkout@v4

      - name: ☕ Setup Java 21
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'

      - name: 🧪 Integration Tests
        run: |
          cd tests/integration/
          npm install
          npm run test:staging

      - name: 🔒 Security Tests
        run: |
          cd tests/security/
          ./run-security-tests.sh staging

      - name: ⚡ Performance Tests
        run: |
          cd tests/performance/
          ./run-load-tests.sh staging

  # Similar structure to dev deployment but with:
  # - More comprehensive testing
  # - Required approvals
  # - Integration with external monitoring
  # - Blue/Green deployment strategy
```

## 🚀 Pipeline 3 : Production Manual Deploy

### `.github/workflows/03-prod-deployment.yml`

```yaml
name: 🚀 Production Deployment

on:
  push:
    tags: ['v*']
  workflow_dispatch:
    inputs:
      version:
        description: 'Release version to deploy'
        required: true
        type: string

env:
  AWS_REGION: eu-west-1
  ENVIRONMENT: prod
  TF_VERSION: 1.6.0

jobs:
  # =========================================================================
  # Job 1: Production Readiness Gate
  # =========================================================================
  production-gate:
    name: 🚨 Production Readiness Gate
    runs-on: ubuntu-latest
    environment: production
    
    steps:
      - name: 📥 Checkout Code
        uses: actions/checkout@v4

      - name: 🔍 Staging Validation
        run: |
          # Verify staging deployment is healthy
          echo "🔍 Verifying staging environment health..."
          
          # Check all required approvals
          echo "✅ Checking approvals..."
          
          # Validate security compliance
          echo "🔒 Validating security compliance..."
          
          # Check performance benchmarks
          echo "⚡ Validating performance benchmarks..."

  # Similar to staging but with:
  # - Manual approval gates
  # - Blue/Green deployment
  # - Extensive monitoring
  # - Automatic rollback triggers
  # - Multi-region deployment
```

## 🧪 Testing Integration

### Integration Tests Structure

```bash
# tests/integration/
├── api/
│   ├── auth.test.js              # Authentication flows
│   ├── rbac.test.js              # RBAC functionality
│   ├── multi-tenant.test.js      # Multi-tenancy isolation
│   └── performance.test.js       # API performance
├── infrastructure/
│   ├── terraform.test.go         # Terratest infrastructure
│   ├── networking.test.js        # VPC, subnets, routing
│   ├── database.test.js          # RDS connectivity, RLS
│   └── cache.test.js             # Redis functionality
├── security/
│   ├── vulnerability-scan.js     # CVE scanning
│   ├── compliance.test.js        # GDPR, SOC2 compliance
│   └── penetration.test.js       # Basic penetration testing
└── e2e/
    ├── user-journey.test.js      # Complete user flows
    ├── admin-flows.test.js       # Admin functionality
    └── tenant-isolation.test.js  # Multi-tenant isolation
```

### Sample Integration Test

```javascript
// tests/integration/api/rbac.test.js
describe('RBAC Authorization Tests', () => {
  let apiUrl;
  let adminToken;
  let userToken;

  beforeAll(async () => {
    apiUrl = process.env.API_URL || 'https://dev.accessweaver.com';
    
    // Setup test tenants and users
    adminToken = await getAdminToken();
    userToken = await getUserToken();
  });

  test('Admin can create policies', async () => {
    const response = await fetch(`${apiUrl}/api/v1/policies`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${adminToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        name: 'test-policy',
        rules: [
          {
            resources: ['documents'],
            actions: ['read'],
            effect: 'allow'
          }
        ]
      })
    });

    expect(response.status).toBe(201);
  });

  test('User cannot access other tenant data', async () => {
    const response = await fetch(`${apiUrl}/api/v1/policies?tenant=other-tenant`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${userToken}`
      }
    });

    expect(response.status).toBe(403);
  });
});
```

## 🔒 Security Pipeline

### `.github/workflows/05-security-scan.yml`

```yaml
name: 🔒 Security Scanning

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM UTC
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  security-scan:
    name: 🔒 Comprehensive Security Scan
    runs-on: ubuntu-latest
    
    steps:
      - name: 📥 Checkout Code
        uses: actions/checkout@v4

      - name: 🔍 SAST - CodeQL
        uses: github/codeql-action/analyze@v3
        with:
          languages: java

      - name: 🔍 SAST - SonarCloud
        uses: SonarSource/sonarcloud-github-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}

      - name: 🔍 Dependencies - Snyk
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}

      - name: 🔍 Infrastructure - Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: terraform/
          framework: terraform

      - name: 🔍 Container Images - Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'accessweaver:latest'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: 📊 Upload Results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'
```

## 📊 Monitoring & Notifications

### Pipeline Monitoring

```yaml
# .github/workflows/monitoring.yml
name: 📊 Pipeline Monitoring

on:
  workflow_run:
    workflows: ["🔄 Dev Auto-Deployment", "🎭 Staging Deployment", "🚀 Production Deployment"]
    types: [completed]

jobs:
  monitor:
    runs-on: ubuntu-latest
    steps:
      - name: 📊 Collect Pipeline Metrics
        run: |
          # Collect deployment metrics
          echo "Pipeline: ${{ github.event.workflow_run.name }}"
          echo "Status: ${{ github.event.workflow_run.conclusion }}"
          echo "Duration: ${{ github.event.workflow_run.updated_at - github.event.workflow_run.created_at }}"
          
          # Send to monitoring system
          curl -X POST "${{ secrets.DATADOG_WEBHOOK }}" \
            -H "Content-Type: application/json" \
            -d '{
              "pipeline": "${{ github.event.workflow_run.name }}",
              "status": "${{ github.event.workflow_run.conclusion }}",
              "environment": "${{ env.ENVIRONMENT }}",
              "duration": "${{ github.event.workflow_run.updated_at - github.event.workflow_run.created_at }}"
            }'

      - name: 🚨 Alert on Failures
        if: github.event.workflow_run.conclusion == 'failure'
        run: |
          ./.github/scripts/alert-failure.sh
```

## 🔄 Rollback Automation

### Automatic Rollback Script

```bash
#!/bin/bash
# .github/scripts/rollback.sh

set -e

ENVIRONMENT=${1:-dev}
PREVIOUS_VERSION=${2}

echo "🔄 Starting rollback for $ENVIRONMENT to version $PREVIOUS_VERSION"

# Get current infrastructure state
current_version=$(terraform output -raw current_image_tag)
echo "Current version: $current_version"

if [ -z "$PREVIOUS_VERSION" ]; then
    # Get previous version from git tags
    PREVIOUS_VERSION=$(git tag --sort=-version:refname | head -2 | tail -1)
fi

echo "Rolling back to version: $PREVIOUS_VERSION"

# Rollback ECS services
services=("aw-api-gateway" "aw-pdp-service" "aw-pap-service" "aw-tenant-service" "aw-audit-service")

for service in "${services[@]}"; do
    echo "🔄 Rolling back $service..."
    
    # Get previous task definition
    task_def_arn=$(aws ecs describe-services \
        --cluster "accessweaver-${ENVIRONMENT}-cluster" \
        --services "accessweaver-${ENVIRONMENT}-${service}" \
        --query 'services[0].deployments[?status==`PRIMARY`].taskDefinition' \
        --output text)
    
    # Get previous revision
    family=$(echo $task_def_arn | cut -d'/' -f2 | cut -d':' -f1)
    current_revision=$(echo $task_def_arn | cut -d':' -f2)
    previous_revision=$((current_revision - 1))
    
    if [ $previous_revision -gt 0 ]; then
        previous_task_def="${family}:${previous_revision}"
        
        echo "Rolling back $service to $previous_task_def"
        
        aws ecs update-service \
            --cluster "accessweaver-${ENVIRONMENT}-cluster" \
            --service "accessweaver-${ENVIRONMENT}-${service}" \
            --task-definition "$previous_task_def"
            
        # Wait for rollback to complete
        aws ecs wait services-stable \
            --cluster "accessweaver-${ENVIRONMENT}-cluster" \
            --services "accessweaver-${ENVIRONMENT}-${service}"
            
        echo "✅ $service rolled back successfully"
    else
        echo "❌ No previous revision found for $service"
        exit 1
    fi
done

# Health check after rollback
echo "🏥 Running health checks..."
sleep 30

api_url=$(terraform output -raw public_url)
health_response=$(curl -s -o /dev/null -w "%{http_code}" "$api_url/actuator/health")

if [ "$health_response" = "200" ]; then
    echo "✅ Rollback successful - health checks passed"
    
    # Notify success
    curl -X POST "$SLACK_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"text\": \"✅ Rollback successful for $ENVIRONMENT\",
            \"attachments\": [{
                \"color\": \"good\",
                \"fields\": [{
                    \"title\": \"Environment\",
                    \"value\": \"$ENVIRONMENT\",
                    \"short\": true
                }, {
                    \"title\": \"Rolled back to\",
                    \"value\": \"$PREVIOUS_VERSION\",
                    \"short\": true
                }]
            }]
        }"
else
    echo "❌ Rollback failed - health checks failed"
    exit 1
fi
```

## 📋 Checklist Déploiement

### Pré-déploiement
- [ ] ✅ Tous les tests passent (unit, integration, e2e)
- [ ] ✅ Security scan sans vulnérabilités critiques
- [ ] ✅ Performance tests dans les seuils acceptables
- [ ] ✅ Infrastructure Terraform validée
- [ ] ✅ Secrets mis à jour dans GitHub
- [ ] ✅ Équipe notifiée du déploiement

### Post-déploiement
- [ ] ✅ Health checks API passent
- [ ] ✅ Smoke tests fonctionnels
- [ ] ✅ Monitoring dashboard vérifié
- [ ] ✅ Logs applicatifs normaux
- [ ] ✅ Métriques dans les plages normales
- [ ] ✅ Backup automatique testé

## 🚨 Troubleshooting Pipeline

### Erreurs Communes

#### 1. Terraform Apply Failed
```bash
# Diagnostic
terraform refresh
terraform plan

# Actions
- Vérifier les credentials AWS
- Valider les quotas AWS
- Checker les conflits de ressources
- Examiner les logs Terraform
```

#### 2. ECS Service Update Failed
```bash
# Diagnostic
aws ecs describe-services --cluster accessweaver-dev-cluster --services accessweaver-dev-aw-api-gateway

# Actions courantes
- Vérifier les health checks
- Examiner les logs CloudWatch
- Valider les task definitions
- Checker la connectivité réseau
```

#### 3. Health Check Timeout
```bash
# Diagnostic
curl -v https://dev.accessweaver.com/actuator/health

# Actions
- Vérifier le démarrage des services
- Examiner les logs d'application
- Valider la connectivité ALB → ECS
- Checker les security groups
```

#### 4. Build Failed
```bash
# Actions
- Vérifier les dépendances Maven
- Examiner les logs de compilation
- Valider les variables d'environnement
- Checker l'espace disque disponible
```

### Scripts de Debug

```bash
#!/bin/bash
# .github/scripts/debug-deployment.sh

ENVIRONMENT=${1:-dev}

echo "🔍 Debugging deployment for $ENVIRONMENT"

# 1. Check ECS services status
echo "📊 ECS Services Status:"
aws ecs list-services --cluster "accessweaver-${ENVIRONMENT}-cluster" \
  --query 'serviceArns[*]' --output table

# 2. Check task health
echo "🏥 Task Health:"
aws ecs list-tasks --cluster "accessweaver-${ENVIRONMENT}-cluster" \
  --query 'taskArns[*]' --output table

# 3. Check ALB target health
echo "🎯 ALB Target Health:"
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names "accessweaver-${ENVIRONMENT}-api-gateway-tg" \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

# 4. Check recent logs
echo "📋 Recent Logs:"
aws logs tail "/ecs/accessweaver-${ENVIRONMENT}/aw-api-gateway" --since 10m

echo "🔍 Debug complete"
```

## 📱 Notifications Avancées

### Slack Integration

```yaml
# .github/scripts/notify-slack.sh
#!/bin/bash

ENVIRONMENT=${1}
STATUS=${2}
API_URL=${3}
IMAGE_TAG=${4}

# Determine color based on status
if [ "$STATUS" = "success" ]; then
    COLOR="good"
    EMOJI="✅"
elif [ "$STATUS" = "failure" ]; then
    COLOR="danger"
    EMOJI="❌"
else
    COLOR="warning"
    EMOJI="⚠️"
fi

# Create rich Slack message
curl -X POST "$SLACK_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{
        \"username\": \"AccessWeaver CI/CD\",
        \"icon_emoji\": \":robot_face:\",
        \"text\": \"$EMOJI Deployment $STATUS for $ENVIRONMENT\",
        \"attachments\": [{
            \"color\": \"$COLOR\",
            \"fields\": [{
                \"title\": \"Environment\",
                \"value\": \"$ENVIRONMENT\",
                \"short\": true
            }, {
                \"title\": \"Status\",
                \"value\": \"$STATUS\",
                \"short\": true
            }, {
                \"title\": \"Image Tag\",
                \"value\": \"$IMAGE_TAG\",
                \"short\": true
            }, {
                \"title\": \"API URL\",
                \"value\": \"$API_URL\",
                \"short\": false
            }, {
                \"title\": \"Deployed By\",
                \"value\": \"$GITHUB_ACTOR\",
                \"short\": true
            }, {
                \"title\": \"Commit\",
                \"value\": \"<https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA|$GITHUB_SHA>\",
                \"short\": true
            }],
            \"actions\": [{
                \"type\": \"button\",
                \"text\": \"View Logs\",
                \"url\": \"https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID\"
            }, {
                \"type\": \"button\",
                \"text\": \"Health Check\",
                \"url\": \"$API_URL/actuator/health\"
            }]
        }]
    }"
```

### Teams Integration

```bash
#!/bin/bash
# .github/scripts/notify-teams.sh

ENVIRONMENT=${1}
STATUS=${2}
API_URL=${3}

# Teams webhook with adaptive cards
curl -X POST "$TEAMS_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{
        \"@type\": \"MessageCard\",
        \"@context\": \"https://schema.org/extensions\",
        \"summary\": \"AccessWeaver Deployment $STATUS\",
        \"themeColor\": \"$([ "$STATUS" = "success" ] && echo "00FF00" || echo "FF0000")\",
        \"sections\": [{
            \"activityTitle\": \"AccessWeaver Deployment\",
            \"activitySubtitle\": \"Environment: $ENVIRONMENT\",
            \"activityImage\": \"https://github.com/accessweaver.png\",
            \"facts\": [{
                \"name\": \"Status\",
                \"value\": \"$STATUS\"
            }, {
                \"name\": \"Environment\",
                \"value\": \"$ENVIRONMENT\"
            }, {
                \"name\": \"Deployed By\",
                \"value\": \"$GITHUB_ACTOR\"
            }, {
                \"name\": \"API URL\",
                \"value\": \"$API_URL\"
            }],
            \"markdown\": true
        }],
        \"potentialAction\": [{
            \"@type\": \"OpenUri\",
            \"name\": \"View Pipeline\",
            \"targets\": [{
                \"os\": \"default\",
                \"uri\": \"https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID\"
            }]
        }, {
            \"@type\": \"OpenUri\",
            \"name\": \"Health Check\",
            \"targets\": [{
                \"os\": \"default\",
                \"uri\": \"$API_URL/actuator/health\"
            }]
        }]
    }"
```

## 🎯 Pipeline Optimization

### Cache Strategy

```yaml
# Optimisations de cache pour accélérer les builds
- name: 📦 Cache Maven Dependencies
  uses: actions/cache@v3
  with:
    path: ~/.m2
    key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}
    restore-keys: ${{ runner.os }}-m2

- name: 📦 Cache Docker Layers
  uses: actions/cache@v3
  with:
    path: /tmp/.buildx-cache
    key: ${{ runner.os }}-buildx-${{ github.sha }}
    restore-keys: |
      ${{ runner.os }}-buildx-

- name: 📦 Cache Terraform
  uses: actions/cache@v3
  with:
    path: |
      ~/.terraform.d/
      .terraform/
    key: ${{ runner.os }}-terraform-${{ hashFiles('**/.terraform.lock.hcl') }}
    restore-keys: ${{ runner.os }}-terraform-
```

### Parallel Execution

```yaml
# Exécution parallèle pour accélérer les déploiements
strategy:
  matrix:
    service: [aw-api-gateway, aw-pdp-service, aw-pap-service, aw-tenant-service, aw-audit-service]
  fail-fast: false
  max-parallel: 3

steps:
  - name: 🏗️ Build ${{ matrix.service }}
    run: |
      docker build -t $ECR_REGISTRY/accessweaver/${{ matrix.service }}:$IMAGE_TAG ./src/${{ matrix.service }}/
      docker push $ECR_REGISTRY/accessweaver/${{ matrix.service }}:$IMAGE_TAG
```

## 📊 Métriques Pipeline

### Dashboard Métriques

```yaml
# Configuration pour dashboard Grafana/DataDog
pipeline_metrics:
  deployment_frequency:
    description: "Nombre de déploiements par jour"
    query: "sum(rate(github_actions_runs_total[1d]))"
    
  deployment_success_rate:
    description: "Taux de succès des déploiements"
    query: "sum(rate(github_actions_runs_success_total[1d])) / sum(rate(github_actions_runs_total[1d]))"
    
  deployment_duration:
    description: "Durée moyenne des déploiements"
    query: "avg(github_actions_run_duration_seconds)"
    
  time_to_recovery:
    description: "Temps de récupération après échec"
    query: "avg(time_between_failure_and_next_success)"

environments:
  - name: development
    target_deployment_frequency: "10/day"
    target_success_rate: "95%"
    target_duration: "15min"
    
  - name: staging
    target_deployment_frequency: "5/day"
    target_success_rate: "98%"
    target_duration: "25min"
    
  - name: production
    target_deployment_frequency: "2/day"
    target_success_rate: "99.5%"
    target_duration: "45min"
```

### Pipeline Analytics

```javascript
// .github/scripts/collect-metrics.js
const { Octokit } = require("@octokit/rest");

class PipelineAnalytics {
    constructor() {
        this.octokit = new Octokit({
            auth: process.env.GITHUB_TOKEN
        });
    }

    async collectMetrics() {
        const { data: workflows } = await this.octokit.rest.actions.listWorkflowRuns({
            owner: 'accessweaver',
            repo: 'accessweaver-cicd',
            per_page: 100
        });

        const metrics = {
            total_runs: workflows.total_count,
            success_rate: this.calculateSuccessRate(workflows.workflow_runs),
            avg_duration: this.calculateAverageDuration(workflows.workflow_runs),
            deployments_per_day: this.calculateDeploymentFrequency(workflows.workflow_runs)
        };

        await this.sendToMonitoring(metrics);
    }

    calculateSuccessRate(runs) {
        const successful = runs.filter(run => run.conclusion === 'success').length;
        return (successful / runs.length) * 100;
    }

    calculateAverageDuration(runs) {
        const durations = runs.map(run => 
            new Date(run.updated_at) - new Date(run.created_at)
        );
        return durations.reduce((a, b) => a + b, 0) / durations.length;
    }

    async sendToMonitoring(metrics) {
        // Send to DataDog, Grafana, ou autre système de monitoring
        console.log('Pipeline Metrics:', metrics);
    }
}
```

## 🔐 Security Best Practices

### Secrets Management

```yaml
# Rotation automatique des secrets
name: 🔐 Secret Rotation

on:
  schedule:
    - cron: '0 0 1 * *'  # Monthly

jobs:
  rotate-secrets:
    runs-on: ubuntu-latest
    steps:
      - name: 🔄 Rotate Database Passwords
        run: |
          # Generate new passwords
          NEW_PASSWORD=$(openssl rand -base64 32)
          
          # Update in AWS Secrets Manager
          aws secretsmanager update-secret \
            --secret-id "accessweaver/prod/database" \
            --secret-string "{\"password\":\"$NEW_PASSWORD\"}"
          
          # Update GitHub secrets
          gh secret set DATABASE_PASSWORD_PROD --body "$NEW_PASSWORD"
          
          # Trigger deployment to update applications
          gh workflow run production-deployment.yml
```

### Access Control

```yaml
# RBAC pour les déploiements
deployment_permissions:
  development:
    - developers
    - platform-team
    
  staging:
    - senior-developers
    - platform-team
    - qa-team
    
  production:
    - platform-team
    - tech-leads
    - security-team

approval_matrix:
  development: 0  # Auto-deployment
  staging: 1      # 1 approval required
  production: 2   # 2 approvals required
```

## 📚 Documentation Pipeline

### Auto-Generated Documentation

```yaml
# .github/workflows/docs-update.yml
name: 📚 Update Documentation

on:
  push:
    branches: [main]
    paths: ['terraform/**', '.github/workflows/**']

jobs:
  update-docs:
    runs-on: ubuntu-latest
    steps:
      - name: 📥 Checkout
        uses: actions/checkout@v4

      - name: 📚 Generate Terraform Docs
        uses: terraform-docs/gh-actions@main
        with:
          working-dir: terraform/
          output-file: README.md
          output-method: inject

      - name: 📚 Generate Architecture Diagrams
        run: |
          # Generate infrastructure diagrams
          python scripts/generate-diagrams.py
          
      - name: 📤 Commit Updates
        uses: stefanzweifel/git-auto-commit-action@v4
        with:
          commit_message: '📚 Auto-update documentation'
```

### Infrastructure Documentation

```python
# scripts/generate-diagrams.py
import boto3
import diagrams
from diagrams.aws.compute import ECS
from diagrams.aws.database import RDS, ElastiCache
from diagrams.aws.network import ALB, VPC

def generate_architecture_diagram():
    with diagrams.Diagram("AccessWeaver Architecture", show=False):
        # Load Balancer
        alb = ALB("Application Load Balancer")
        
        # ECS Services
        with diagrams.Cluster("ECS Fargate"):
            api_gateway = ECS("API Gateway")
            pdp_service = ECS("PDP Service")
            pap_service = ECS("PAP Service")
            tenant_service = ECS("Tenant Service")
            audit_service = ECS("Audit Service")
        
        # Databases
        postgres = RDS("PostgreSQL")
        redis = ElastiCache("Redis")
        
        # Connections
        alb >> api_gateway
        api_gateway >> [pdp_service, pap_service, tenant_service, audit_service]
        [pdp_service, pap_service, tenant_service, audit_service] >> postgres
        [pdp_service, pap_service] >> redis

if __name__ == "__main__":
    generate_architecture_diagram()
```

## 🎯 Prochaines Étapes

### Phase 1 : Implémentation Immédiate
1. **✅ Créer repository `accessweaver-cicd`**
2. **✅ Configurer secrets GitHub Actions**
3. **✅ Implémenter pipeline dev auto-deploy**
4. **✅ Tester déploiement dev complet**
5. **✅ Ajouter notifications Slack/Teams**

### Phase 2 : Staging & Production
1. **🔄 Pipeline staging PR-based**
2. **🔄 Pipeline production manual**
3. **🔄 Tests d'intégration complets**
4. **🔄 Monitoring pipeline avancé**
5. **🔄 Rollback automatique**

### Phase 3 : Optimisation
1. **⚡ Cache et parallélisation**
2. **📊 Métriques et analytics**
3. **🔐 Rotation secrets automatique**
4. **📚 Documentation auto-générée**
5. **🎯 Blue/Green deployments**

---

## 💡 Support & Troubleshooting

### Contacts Pipeline
- **DevOps Team** : devops@accessweaver.com
- **Platform Team** : platform@accessweaver.com
- **Security Team** : security@accessweaver.com

### Ressources Utiles
- **🔗 Pipeline Dashboard** : [GitHub Actions](https://github.com/accessweaver/accessweaver-cicd/actions)
- **📊 Monitoring** : [DataDog Dashboard](https://app.datadoghq.com/dashboard/accessweaver-pipeline)
- **💬 Support** : [#accessweaver-cicd](https://slack.com/channels/accessweaver-cicd)
- **📚 Documentation** : [Internal Wiki](https://wiki.accessweaver.com/cicd)

**🎯 Ce guide CI/CD fournit une base solide pour déployer AccessWeaver de manière fiable et sécurisée sur AWS. Les pipelines sont conçus pour être évolutifs et maintenables, avec un focus sur l'automation et l'observabilité.**