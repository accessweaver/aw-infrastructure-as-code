# 📊 Configuration Monitoring - AccessWeaver

Configuration complète du stack de monitoring et observabilité pour AccessWeaver - Système d'autorisation enterprise multi-tenant.

---

## 🎯 Vue d'Ensemble

### Stack de Monitoring AccessWeaver
```
📊 Observabilité Enterprise
├── 📈 CloudWatch (Métriques + Logs)
├── 🔍 AWS X-Ray (Tracing distribué)
├── 📋 Custom Dashboards (Ops + Business)
├── 🚨 Alerting intelligent (SNS + Slack)
├── 📝 Structured Logging (JSON + ELK ready)
└── 💰 Cost Optimization (Budgets + Alerts)
```

### Objectifs Monitoring
- **🎯 Proactif** : Détecter les problèmes avant les utilisateurs
- **📊 Observabilité** : Visibilité complète sur performances et usage
- **🔧 Opérationnel** : Support 24/7 avec dashboards temps réel
- **💼 Business** : Métriques métier pour product management
- **💰 Économique** : Monitoring maîtrisé (~$50-200/mois selon env)

---

## 🏗 Architecture de Monitoring

### Vue d'Ensemble Technique
```
┌─────────────────────────────────────────────────────────┐
│                    Applications                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│  │API Gateway  │ │PDP Service  │ │PAP Service  │       │
│  │   Logs ←────┼─┤   Logs ←────┼─┤   Logs      │       │
│  │ Metrics ←───┼─┤ Metrics ←───┼─┤ Metrics     │       │
│  │ Traces ←────┼─┤ Traces ←────┼─┤ Traces      │       │
│  └─────────────┘ └─────────────┘ └─────────────┘       │
└─────────────────┬───────────────┬───────────────────────┘
                  │               │
        ┌─────────▼─────────────┐ │
        │   Spring Boot         │ │
        │   Micrometer         │ │
        │   - CloudWatch       │ │
        │   - Custom Metrics   │ │
        │   - JVM Metrics      │ │
        └─────────┬─────────────┘ │
                  │               │
        ┌─────────▼─────────────┐ │
        │     AWS X-Ray         │ │
        │   - Request traces    │ │
        │   - Service map       │ │
        │   - Performance       │ │
        └─────────┬─────────────┘ │
                  │               │
        ┌─────────▼─────────────────▼─────────┐
        │           CloudWatch                │
        │  ┌─────────────┐ ┌─────────────┐   │
        │  │   Metrics   │ │    Logs     │   │
        │  │             │ │             │   │
        │  │• CPU/Memory │ │• App logs   │   │
        │  │• Requests   │ │• Access logs│   │
        │  │• Latency    │ │• Error logs │   │
        │  │• Errors     │ │• Audit logs │   │
        │  └─────────────┘ └─────────────┘   │
        └─────────────┬───────────────────────┘
                      │
        ┌─────────────▼───────────────────────┐
        │         Alerting & Actions          │
        │  ┌─────────────┐ ┌─────────────┐   │
        │  │     SNS     │ │  Dashboards │   │
        │  │             │ │             │   │
        │  │• Email      │ │• CloudWatch │   │
        │  │• Slack      │ │• Custom     │   │
        │  │• PagerDuty  │ │• Grafana    │   │
        │  └─────────────┘ └─────────────┘   │
        └─────────────────────────────────────┘
```

---

## 🚀 Setup Phase 1 : Infrastructure de Base

### 1.1 - Module Terraform Monitoring

```hcl
# modules/monitoring/main.tf
module "monitoring" {
  source = "../../modules/monitoring"
  
  project_name = "accessweaver"
  environment  = var.environment
  
  # SNS Topics pour alerting
  enable_slack_integration = true
  slack_webhook_url       = var.slack_webhook_url
  pagerduty_endpoint      = var.pagerduty_endpoint
  
  # Retention des logs
  log_retention_days = var.environment == "prod" ? 90 : 30
  
  # Dashboards
  enable_business_dashboard = true
  enable_ops_dashboard     = true
  
  # Cost monitoring
  monthly_budget_limit = var.environment == "prod" ? 1000 : 300
}
```

### 1.2 - Configuration CloudWatch Agent

```yaml
# cloudwatch-agent-config.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "metrics": {
    "namespace": "AccessWeaver/${environment}",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait", 
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "diskio": {
        "measurement": [
          "io_time"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/applications/accessweaver-*.log",
            "log_group_name": "/aws/ecs/accessweaver-${environment}",
            "log_stream_name": "{instance_id}-application",
            "timezone": "UTC",
            "timestamp_format": "%Y-%m-%d %H:%M:%S"
          }
        ]
      }
    }
  }
}
```

---

## 🔧 Setup Phase 2 : Configuration Spring Boot

### 2.1 - Dependencies Monitoring

```xml
<!-- pom.xml -->
<dependencies>
  <!-- Micrometer pour CloudWatch -->
  <dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-cloudwatch2</artifactId>
  </dependency>
  
  <!-- Spring Boot Actuator -->
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
  </dependency>
  
  <!-- AWS X-Ray -->
  <dependency>
    <groupId>com.amazonaws</groupId>
    <artifactId>aws-xray-recorder-sdk-spring</artifactId>
    <version>2.15.0</version>
  </dependency>
  
  <!-- Logging structured -->
  <dependency>
    <groupId>net.logstash.logback</groupId>
    <artifactId>logstash-logback-encoder</artifactId>
    <version>7.4</version>
  </dependency>
  
  <!-- Resilience4j pour circuit breaker metrics -->
  <dependency>
    <groupId>io.github.resilience4j</groupId>
    <artifactId>resilience4j-micrometer</artifactId>
  </dependency>
</dependencies>
```

### 2.2 - Configuration Application

```yaml
# application.yml - Monitoring Configuration
management:
  endpoints:
    web:
      exposure:
        include: "health,info,metrics,prometheus,env,configprops,loggers"
      base-path: "/actuator"
  endpoint:
    health:
      show-details: when-authorized
      show-components: always
      probes:
        enabled: true
    metrics:
      enabled: true
  metrics:
    web:
      server:
        request:
          autotime:
            enabled: true
            percentiles: 0.5,0.95,0.99
    distribution:
      percentiles-histogram:
        http.server.requests: true
      percentiles:
        http.server.requests: 0.5,0.95,0.99
      sla:
        http.server.requests: 50ms,100ms,200ms,500ms
    export:
      cloudwatch:
        namespace: "AccessWeaver/${ENVIRONMENT:dev}"
        enabled: true
        step: PT1M
        batch-size: 20
    tags:
      application: "${spring.application.name}"
      environment: "${ENVIRONMENT:dev}"
      tenant: "${TENANT_ID:unknown}"

# AWS Configuration
cloud:
  aws:
    region:
      static: "${AWS_REGION:eu-west-1}"
    credentials:
      access-key: "${AWS_ACCESS_KEY_ID:}"
      secret-key: "${AWS_SECRET_ACCESS_KEY:}"

# X-Ray Configuration
aws:
  xray:
    tracing-name: "AccessWeaver-${spring.application.name}"
    enabled: true
    context-missing: LOG_ERROR

# Logging Configuration
logging:
  level:
    com.accessweaver: ${LOG_LEVEL:INFO}
    org.springframework.security: WARN
    org.hibernate: WARN
  pattern:
    console: "%d{HH:mm:ss.SSS} [%thread] %-5level [%X{traceId},%X{spanId}] %logger{36} - %msg%n"
  config: classpath:logback-spring.xml
```

### 2.3 - Configuration Logback Structuré

```xml
<!-- logback-spring.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <include resource="org/springframework/boot/logging/logback/defaults.xml"/>
    
    <!-- Console Appender pour développement -->
    <springProfile name="dev,default">
        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder>
                <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level [%X{traceId:-},%X{spanId:-},%X{tenantId:-}] %logger{36} - %msg%n</pattern>
            </encoder>
        </appender>
        <root level="INFO">
            <appender-ref ref="CONSOLE"/>
        </root>
    </springProfile>
    
    <!-- JSON Appender pour staging/prod -->
    <springProfile name="staging,prod">
        <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
            <encoder class="net.logstash.logback.encoder.LoggingEventCompositeJsonEncoder">
                <providers>
                    <timestamp/>
                    <version/>
                    <logLevel/>
                    <message/>
                    <mdc/>
                    <loggerName/>
                    <pattern>
                        <pattern>
                            {
                                "application": "accessweaver",
                                "service": "${spring.application.name:-unknown}",
                                "environment": "${ENVIRONMENT:-unknown}",
                                "traceId": "%X{traceId:-}",
                                "spanId": "%X{spanId:-}",
                                "tenantId": "%X{tenantId:-}",
                                "userId": "%X{userId:-}",
                                "requestId": "%X{requestId:-}",
                                "timestamp": "%d{yyyy-MM-dd'T'HH:mm:ss.SSSZ}",
                                "level": "%level",
                                "logger": "%logger",
                                "thread": "%thread",
                                "message": "%message"
                            }
                        </pattern>
                    </pattern>
                    <stackTrace/>
                </providers>
            </encoder>
        </appender>
        <root level="INFO">
            <appender-ref ref="JSON"/>
        </root>
    </springProfile>
    
    <!-- Logger spécifique pour audit -->
    <logger name="com.accessweaver.audit" level="INFO" additivity="false">
        <appender name="AUDIT" class="ch.qos.logback.core.ConsoleAppender">
            <encoder class="net.logstash.logback.encoder.LoggingEventCompositeJsonEncoder">
                <providers>
                    <timestamp/>
                    <pattern>
                        <pattern>
                            {
                                "type": "AUDIT",
                                "application": "accessweaver",
                                "service": "${spring.application.name:-unknown}",
                                "environment": "${ENVIRONMENT:-unknown}",
                                "traceId": "%X{traceId:-}",
                                "tenantId": "%X{tenantId:-}",
                                "userId": "%X{userId:-}",
                                "action": "%X{action:-}",
                                "resource": "%X{resource:-}",
                                "timestamp": "%d{yyyy-MM-dd'T'HH:mm:ss.SSSZ}",
                                "message": "%message"
                            }
                        </pattern>
                    </pattern>
                </providers>
            </encoder>
        </appender>
        <appender-ref ref="AUDIT"/>
    </logger>
</configuration>
```

---

## 📊 Setup Phase 3 : Métriques Custom AccessWeaver

### 3.1 - Configuration Micrometer

```java
@Configuration
@EnableConfigurationProperties(MonitoringProperties.class)
public class MonitoringConfiguration {
    
    private final MonitoringProperties properties;
    
    public MonitoringConfiguration(MonitoringProperties properties) {
        this.properties = properties;
    }
    
    @Bean
    @ConditionalOnProperty(name = "management.metrics.export.cloudwatch.enabled", havingValue = "true")
    public CloudWatchConfig cloudWatchConfig() {
        return new CloudWatchConfig() {
            @Override
            public String namespace() {
                return properties.getNamespace();
            }
            
            @Override
            public Duration step() {
                return Duration.ofMinutes(1);
            }
            
            @Override
            public int batchSize() {
                return 20;
            }
            
            @Override
            public String get(String key) {
                return null;
            }
        };
    }
    
    @Bean
    public MeterRegistryCustomizer<MeterRegistry> metricsCommonTags() {
        return registry -> registry.config()
            .commonTags(
                "application", properties.getApplicationName(),
                "environment", properties.getEnvironment(),
                "service", properties.getServiceName()
            );
    }
    
    @Bean
    public TimedAspect timedAspect(MeterRegistry registry) {
        return new TimedAspect(registry);
    }
    
    @Bean
    public CountedAspect countedAspect(MeterRegistry registry) {
        return new CountedAspect(registry);
    }
}
```

### 3.2 - Métriques Custom pour AccessWeaver

```java
@Component
public class AccessWeaverMetrics {
    
    private final MeterRegistry meterRegistry;
    private final Counter authorizationChecks;
    private final Counter authorizationDenied;
    private final Timer authorizationLatency;
    private final Gauge activeTenants;
    private final Counter policyChanges;
    
    public AccessWeaverMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
        
        // Compteurs d'autorisation
        this.authorizationChecks = Counter.builder("accessweaver.authorization.checks")
            .description("Total authorization checks performed")
            .register(meterRegistry);
            
        this.authorizationDenied = Counter.builder("accessweaver.authorization.denied")
            .description("Total authorization checks denied")
            .register(meterRegistry);
            
        // Latence des vérifications d'autorisation
        this.authorizationLatency = Timer.builder("accessweaver.authorization.latency")
            .description("Authorization check latency")
            .publishPercentiles(0.5, 0.95, 0.99)
            .register(meterRegistry);
            
        // Gauge pour tenants actifs
        this.activeTenants = Gauge.builder("accessweaver.tenants.active")
            .description("Number of active tenants")
            .register(meterRegistry, this, AccessWeaverMetrics::getActiveTenantCount);
            
        // Changements de policies
        this.policyChanges = Counter.builder("accessweaver.policies.changes")
            .description("Total policy changes")
            .register(meterRegistry);
    }
    
    // Méthodes d'instrumentation
    public void recordAuthorizationCheck(String tenantId, String action, String resource, boolean allowed, Duration duration) {
        authorizationChecks.increment(
            Tags.of(
                "tenant", tenantId,
                "action", action,
                "resource", resource,
                "result", allowed ? "allowed" : "denied"
            )
        );
        
        if (!allowed) {
            authorizationDenied.increment(
                Tags.of(
                    "tenant", tenantId,
                    "action", action,
                    "resource", resource
                )
            );
        }
        
        authorizationLatency.record(duration, 
            Tags.of(
                "tenant", tenantId,
                "result", allowed ? "allowed" : "denied"
            )
        );
    }
    
    public void recordPolicyChange(String tenantId, String policyType, String operation) {
        policyChanges.increment(
            Tags.of(
                "tenant", tenantId,
                "policy_type", policyType,
                "operation", operation
            )
        );
    }
    
    // Business metrics
    public void recordUserActivity(String tenantId, String userId, String action) {
        Counter.builder("accessweaver.user.activity")
            .description("User activity tracking")
            .tags("tenant", tenantId, "action", action)
            .register(meterRegistry)
            .increment();
    }
    
    public void recordAPIUsage(String tenantId, String endpoint, int statusCode, Duration duration) {
        Timer.builder("accessweaver.api.requests")
            .description("API request duration and count")
            .tags(
                "tenant", tenantId,
                "endpoint", endpoint,
                "status", String.valueOf(statusCode),
                "status_class", statusCode >= 400 ? "error" : "success"
            )
            .register(meterRegistry)
            .record(duration);
    }
    
    private double getActiveTenantCount() {
        // Implementation pour compter les tenants actifs
        // Peut être appelé depuis un service ou repository
        return 0.0; // Placeholder
    }
}
```

### 3.3 - Intercepteur pour Métriques Automatiques

```java
@Component
@Slf4j
public class MetricsInterceptor implements HandlerInterceptor {
    
    private final AccessWeaverMetrics metrics;
    private final MeterRegistry meterRegistry;
    
    public MetricsInterceptor(AccessWeaverMetrics metrics, MeterRegistry meterRegistry) {
        this.metrics = metrics;
        this.meterRegistry = meterRegistry;
    }
    
    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        request.setAttribute("startTime", System.nanoTime());
        
        // Ajouter tenant ID au MDC pour logs
        String tenantId = extractTenantId(request);
        if (tenantId != null) {
            MDC.put("tenantId", tenantId);
        }
        
        // Ajouter request ID
        String requestId = UUID.randomUUID().toString();
        MDC.put("requestId", requestId);
        request.setAttribute("requestId", requestId);
        
        return true;
    }
    
    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response, 
                               Object handler, Exception ex) {
        
        Long startTime = (Long) request.getAttribute("startTime");
        if (startTime != null) {
            Duration duration = Duration.ofNanos(System.nanoTime() - startTime);
            
            String tenantId = MDC.get("tenantId");
            String endpoint = request.getRequestURI();
            int statusCode = response.getStatus();
            
            // Enregistrer métriques API
            if (tenantId != null) {
                metrics.recordAPIUsage(tenantId, endpoint, statusCode, duration);
            }
            
            // Métriques globales
            Timer.builder("accessweaver.http.requests")
                .description("HTTP request duration")
                .tags(
                    "method", request.getMethod(),
                    "status", String.valueOf(statusCode),
                    "endpoint", endpoint
                )
                .register(meterRegistry)
                .record(duration);
        }
        
        // Nettoyer MDC
        MDC.clear();
    }
    
    private String extractTenantId(HttpServletRequest request) {
        // Extraire depuis header ou JWT token
        String tenantHeader = request.getHeader("X-Tenant-ID");
        if (tenantHeader != null) {
            return tenantHeader;
        }
        
        // Ou depuis Authorization header / JWT
        String authHeader = request.getHeader("Authorization");
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            // Decoder JWT et extraire tenant ID
            // Implementation dépend de votre système d'auth
        }
        
        return null;
    }
}
```

---

## 🚨 Setup Phase 4 : Alerting et Notifications

### 4.1 - Configuration SNS Topics

```hcl
# modules/monitoring/sns.tf
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"

  tags = {
    Name        = "${var.project_name}-${var.environment}-alerts"
    Environment = var.environment
    Purpose     = "monitoring-alerts"
  }
}

resource "aws_sns_topic" "critical_alerts" {
  name = "${var.project_name}-${var.environment}-critical-alerts"

  tags = {
    Name        = "${var.project_name}-${var.environment}-critical-alerts"
    Environment = var.environment
    Purpose     = "critical-monitoring-alerts"
  }
}

# Email subscriptions
resource "aws_sns_topic_subscription" "email_alerts" {
  count     = length(var.alert_email_addresses)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email_addresses[count.index]
}

# Slack integration via Lambda
resource "aws_sns_topic_subscription" "slack_alerts" {
  count     = var.enable_slack_integration ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier[0].arn
}
```

### 4.2 - Alertes CloudWatch

```hcl
# modules/monitoring/alarms.tf
# Alerte CPU élevé
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  for_each = var.ecs_service_names

  alarm_name          = "${var.project_name}-${var.environment}-${each.value}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.environment == "prod" ? "70" : "80"
  alarm_description   = "This metric monitors ECS CPU utilization for ${each.value}"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = each.value
    ClusterName = "${var.project_name}-${var.environment}-cluster"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.value}-cpu-alarm"
    Environment = var.environment
    Service     = each.value
  }
}

# Alerte taux d'erreur élevé
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.project_name}-${var.environment}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "20"
  alarm_description   = "High 5XX error rate detected"
  alarm_actions       = [aws_sns_topic.critical_alerts.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-error-rate-alarm"
    Environment = var.environment
  }
}

# Alerte latence élevée
resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "${var.project_name}-${var.environment}-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.environment == "prod" ? "1.0" : "2.0"
  alarm_description   = "High response time detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

# Alertes métier AccessWeaver
resource "aws_cloudwatch_metric_alarm" "authorization_failures" {
  alarm_name          = "${var.project_name}-${var.environment}-auth-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "accessweaver.authorization.denied"
  namespace           = "AccessWeaver/${var.environment}"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"  # Plus de 100 refus en 5 minutes
  alarm_description   = "High number of authorization denials"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-${var.environment}-auth-failures"
    Environment = var.environment
    Type        = "business-metric"
  }
}
```

---

## 💰 Setup Phase 5 : Cost Management

### 5.1 - Budget CloudWatch

```hcl
# modules/monitoring/budgets.tf
resource "aws_budgets_budget" "monitoring_costs" {
  name         = "${var.project_name}-${var.environment}-monitoring-budget"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  cost_filters {
    service = [
      "Amazon CloudWatch",
      "AWS X-Ray",
      "Amazon Simple Notification Service"
    ]
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = var.alert_email_addresses
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_email_addresses
  }
}
```

### 5.2 - Optimisation des Coûts

```yaml
# Cost optimization strategies
monitoring_optimization:
  cloudwatch:
    # Réduire la fréquence de certaines métriques
    low_priority_metrics_interval: "5m"  # Au lieu de 1m
    high_priority_metrics_interval: "1m"
    
    # Retention différenciée
    log_retention:
      dev: 7    # jours
      staging: 30
      prod: 90
      
    # Filtrage des logs
    log_filtering:
      exclude_debug_logs: true
      exclude_health_checks: true
      sample_rate: 0.1  # 10% sampling pour logs non-critiques
      
  x_ray:
    # Sampling rules pour contrôler les coûts
    sampling_rate: 0.1  # 10% des traces en dev/staging
    sampling_rate_prod: 0.05  # 5% en production
    
    # Retention
    retention_days: 30
```

---

## 📋 Checklist de Déploiement

### ✅ Phase 1 : Préparation
- [ ] Créer le module Terraform monitoring
- [ ] Configurer les SNS topics
- [ ] Définir les variables d'environnement
- [ ] Préparer les credentials AWS

### ✅ Phase 2 : Application
- [ ] Ajouter les dépendances monitoring aux services
- [ ] Configurer Micrometer dans chaque service
- [ ] Implémenter les métriques custom
- [ ] Configurer le logging structuré

### ✅ Phase 3 : Infrastructure
- [ ] Déployer les ressources CloudWatch
- [ ] Configurer les alertes
- [ ] Tester les notifications
- [ ] Valider les budgets

### ✅ Phase 4 : Validation
- [ ] Vérifier la collecte de métriques
- [ ] Tester les alertes avec seuils bas
- [ ] Valider les dashboards
- [ ] Documentation pour l'équipe ops

---

## 🔧 Scripts d'Installation

### Script de Déploiement Monitoring

```bash
#!/bin/bash
# deploy-monitoring.sh

set -e

ENV=${1:-dev}
REGION=${2:-eu-west-1}

echo "🚀 Deploying AccessWeaver monitoring stack for $ENV"

# 1. Deploy infrastructure
echo "📊 Deploying monitoring infrastructure..."
cd terraform/modules/monitoring
terraform init
terraform plan -var="environment=$ENV" -var="region=$REGION"
terraform apply -auto-approve

# 2. Configure CloudWatch agent
echo "📈 Configuring CloudWatch agent..."
aws ssm put-parameter \
    --name "/accessweaver/$ENV/cloudwatch-config" \
    --value "$(cat cloudwatch-agent-config.json)" \
    --type "String" \
    --overwrite

# 3. Deploy dashboards
echo "📋 Creating dashboards..."
aws cloudwatch put-dashboard \
    --dashboard-name "AccessWeaver-$ENV-Operations" \
    --dashboard-body "$(cat dashboards/ops-dashboard.json)"

aws cloudwatch put-dashboard \
    --dashboard-name "AccessWeaver-$ENV-Business" \
    --dashboard-body "$(cat dashboards/business-dashboard.json)"

# 4. Test alerting
echo "🚨 Testing alerting configuration..."
aws sns publish \
    --topic-arn "arn:aws:sns:$REGION:$(aws sts get-caller-identity --query Account --output text):accessweaver-$ENV-alerts" \
    --message "Test alert from AccessWeaver monitoring setup"

echo "✅ Monitoring deployment completed for $ENV"
echo "📊 CloudWatch dashboards: https://console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:"
echo "🚨 Check your email/Slack for test alert"
```

### Script de Validation

```bash
#!/bin/bash
# validate-monitoring.sh

ENV=${1:-dev}
REGION=${2:-eu-west-1}

echo "🔍 Validating AccessWeaver monitoring for $ENV"

# 1. Check metrics are being published
echo "📊 Checking metric publication..."
METRIC_COUNT=$(aws cloudwatch list-metrics \
    --namespace "AccessWeaver/$ENV" \
    --query 'length(Metrics)' \
    --output text)

if [ "$METRIC_COUNT" -gt 0 ]; then
    echo "✅ Found $METRIC_COUNT custom metrics"
else
    echo "❌ No custom metrics found"
    exit 1
fi

# 2. Check log groups exist
echo "📝 Checking log groups..."
LOG_GROUPS=$(aws logs describe-log-groups \
    --log-group-name-prefix "/aws/ecs/accessweaver-$ENV" \
    --query 'length(logGroups)' \
    --output text)

if [ "$LOG_GROUPS" -gt 0 ]; then
    echo "✅ Found $LOG_GROUPS log groups"
else
    echo "❌ No log groups found"
fi

# 3. Check alarms are configured
echo "🚨 Checking alarms..."
ALARM_COUNT=$(aws cloudwatch describe-alarms \
    --alarm-name-prefix "accessweaver-$ENV" \
    --query 'length(MetricAlarms)' \
    --output text)

echo "✅ Found $ALARM_COUNT alarms configured"

# 4. Test API endpoint monitoring
echo "🌐 Testing API monitoring..."
if command -v curl &> /dev/null; then
    RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null https://api-$ENV.accessweaver.com/actuator/health)
    if [ "$RESPONSE" = "200" ]; then
        echo "✅ Health endpoint responding"
    else
        echo "⚠️ Health endpoint returned $RESPONSE"
    fi
fi

echo "✅ Monitoring validation completed"
```

---

## 🔍 Troubleshooting

### Problèmes Courants

#### 1. Métriques non visibles dans CloudWatch

```bash
# Diagnostic
echo "🔍 Debugging metrics..."

# Vérifier la configuration Micrometer
curl -s http://localhost:8080/actuator/metrics | jq '.names[] | select(startswith("accessweaver"))'

# Vérifier les permissions IAM
aws sts get-caller-identity
aws iam get-role --role-name accessweaver-ecs-task-role

# Vérifier les logs d'erreur
aws logs filter-log-events \
    --log-group-name "/aws/ecs/accessweaver-$ENV/aw-api-gateway" \
    --filter-pattern "CloudWatch" \
    --start-time $(date -d '1 hour ago' +%s)000
```

#### 2. Alertes non reçues

```bash
# Test SNS topic
aws sns publish \
    --topic-arn "arn:aws:sns:eu-west-1:123456789012:accessweaver-$ENV-alerts" \
    --message "Test message" \
    --subject "Test Alert"

# Vérifier les subscriptions
aws sns list-subscriptions-by-topic \
    --topic-arn "arn:aws:sns:eu-west-1:123456789012:accessweaver-$ENV-alerts"

# Vérifier les métriques d'alarme
aws cloudwatch get-metric-statistics \
    --namespace "AWS/ECS" \
    --metric-name "CPUUtilization" \
    --start-time $(date -d '1 hour ago' --iso-8601) \
    --end-time $(date --iso-8601) \
    --period 300 \
    --statistics Average
```

#### 3. X-Ray traces manquantes

```java
// Vérifier la configuration X-Ray
@RestController
public class TracingTestController {
    
    @GetMapping("/test-tracing")
    @XRayEnabled
    public ResponseEntity<String> testTracing() {
        
        // Vérifier si X-Ray est actif
        Segment segment = AWSXRay.getCurrentSegment();
        if (segment != null) {
            log.info("X-Ray trace ID: {}", segment.getTraceId());
            return ResponseEntity.ok("Tracing active: " + segment.getTraceId());
        } else {
            log.warn("X-Ray tracing not active");
            return ResponseEntity.ok("Tracing not active");
        }
    }
}
```

---

## 📊 Métriques de Référence

### Seuils Recommandés par Environnement

| Métrique | Dev | Staging | Prod | Critique |
|----------|-----|---------|------|----------|
| **CPU ECS** | 85% | 80% | 70% | 90% |
| **Memory ECS** | 90% | 85% | 80% | 95% |
| **Response Time** | 3s | 2s | 1s | 5s |
| **Error Rate 5xx** | 5% | 3% | 1% | 10% |
| **DB Connections** | 80% | 70% | 60% | 90% |
| **Redis Memory** | 90% | 85% | 80% | 95% |
| **Auth Denials** | 500/5min | 200/5min | 100/5min | 1000/5min |

### Coûts Monitoring par Environnement

| Service | Dev/mois | Staging/mois | Prod/mois |
|---------|----------|--------------|-----------|
| **CloudWatch Metrics** | $15 | $30 | $60 |
| **CloudWatch Logs** | $10 | $25 | $50 |
| **X-Ray Traces** | $5 | $15 | $30 |
| **SNS Notifications** | $1 | $2 | $5 |
| **Lambda (Slack)** | $1 | $2 | $3 |
| **Total Estimé** | **$32** | **$74** | **$148** |

---

## 🚀 Prochaines Étapes

1. **Valider le setup de base** avec ce document
2. **Créer les métriques détaillées** (monitoring/metrics.md)
3. **Configurer les dashboards** (monitoring/cloudwatch.md)
4. **Implémenter l'alerting intelligent** (monitoring/alerting.md)
5. **Setup du tracing distribué** (monitoring/tracing.md)

---

**📋 Status de la documentation :**
- ✅ Setup infrastructure et configuration
- ⏳ Métriques business et techniques détaillées
- ⏳ Dashboards opérationnels et métier
- ⏳ Stratégie d'alerting proactive
- ⏳ Tracing distribué et correlation