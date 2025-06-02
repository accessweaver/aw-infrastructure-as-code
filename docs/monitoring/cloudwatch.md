# 📊 CloudWatch Dashboards & Métriques - AccessWeaver

Monitoring natif AWS avec dashboards enterprise, métriques custom et alerting proactif pour AccessWeaver.

## 🎯 Objectifs

### ✅ Dashboards Ops 24/7
- **Vue d'ensemble** système en temps réel
- **Drill-down par tenant** pour isolation des problèmes
- **Corrélation infrastructure + application** metrics
- **Dashboards accessibles** aux équipes non-techniques

### ✅ Métriques Custom AccessWeaver
- **Auth rate & latency** par tenant et endpoint
- **Decision latency** pour RBAC/ABAC (p50, p95, p99)
- **Cache hit ratio** optimisé par type de permission
- **Usage analytics** pour billing et capacity planning

### ✅ Alerting Proactif
- **ML Anomaly Detection** sur les patterns de trafic
- **Composite alarms** avec corrélation multi-services
- **Zero false-positives** avec seuils adaptatifs
- **Integration SNS/Slack** avec context enrichi

### ✅ Cost Optimization
- **Log retention** adaptatif par importance
- **Metrics filtering** pour éviter les coûts inutiles
- **Reserved Capacity** pour workloads stables
- **Cross-region syncing** optimisé

## 🏗 Architecture Monitoring

```
┌─────────────────────────────────────────────────────────┐
│                    CloudWatch                          │
│                                                         │
│  ┌─────────────────┐ ┌─────────────────┐ ┌───────────┐ │
│  │   Dashboards    │ │     Alarms      │ │   Logs    │ │
│  │                 │ │                 │ │           │ │
│  │ • System Health │ │ • Composite     │ │ • JSON    │ │
│  │ • Tenant Usage  │ │ • ML Anomaly    │ │ • Struct  │ │
│  │ • Performance   │ │ • Thresholds    │ │ • GDPR    │ │
│  │ • Business KPIs │ │ • Auto-scaling  │ │ • Costs   │ │
│  └─────────────────┘ └─────────────────┘ └───────────┘ │
│                                                         │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              Custom Metrics                         │ │
│  │                                                     │ │
│  │ AccessWeaver/Authorization                          │ │
│  │ ├── decision_latency (p50/p95/p99)                  │ │
│  │ ├── authorization_rate (tenant/endpoint)            │ │
│  │ ├── cache_efficiency (hit_ratio/evictions)          │ │
│  │ ├── tenant_usage (requests/storage/compute)         │ │
│  │ └── business_metrics (MAU/conversion/churn)         │ │
│  │                                                     │ │
│  │ AccessWeaver/Infrastructure                         │ │
│  │ ├── service_health (ECS/ALB/RDS/Redis)              │ │
│  │ ├── resource_utilization (CPU/Memory/Storage)       │ │
│  │ ├── network_performance (latency/throughput)        │ │
│  │ └── cost_tracking (resource/tenant/time)            │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│                External Integration                     │
│                                                         │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐    │
│  │     SNS      │ │    Slack     │ │  PagerDuty   │    │
│  │   Topics     │ │  WebHooks    │ │  Integration │    │
│  └──────────────┘ └──────────────┘ └──────────────┘    │
│                                                         │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              Data Export                            │ │
│  │                                                     │ │
│  │ • S3 (long-term storage)                            │ │
│  │ • Kinesis (real-time streaming)                     │ │
│  │ • EventBridge (event-driven automation)            │ │
│  │ • DataDog/Grafana (external dashboards)            │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## 📈 Dashboards Enterprise

### 1. System Health Dashboard

#### Vue d'ensemble Infrastructure

```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "accessweaver-prod-alb"],
          [".", "TargetResponseTime", ".", "."],
          [".", "HTTPCode_Target_2XX_Count", ".", "."],
          [".", "HTTPCode_ELB_5XX_Count", ".", "."]
        ],
        "period": 300,
        "stat": "Average",
        "region": "eu-west-1",
        "title": "🌐 ALB Performance",
        "yAxis": {
          "left": {
            "min": 0
          }
        },
        "annotations": {
          "horizontal": [
            {
              "label": "Response Time SLA",
              "value": 200
            }
          ]
        }
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ECS", "CPUUtilization", "ServiceName", "accessweaver-prod-aw-api-gateway", "ClusterName", "accessweaver-prod-cluster"],
          [".", "MemoryUtilization", ".", ".", ".", "."],
          [".", "CPUUtilization", "ServiceName", "accessweaver-prod-aw-pdp-service", ".", "."],
          [".", "MemoryUtilization", ".", ".", ".", "."]
        ],
        "period": 300,
        "stat": "Average",
        "region": "eu-west-1",
        "title": "🚀 ECS Services Health",
        "yAxis": {
          "left": {
            "min": 0,
            "max": 100
          }
        }
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "accessweaver-prod-postgres"],
          [".", "DatabaseConnections", ".", "."],
          ["AWS/ElastiCache", "CPUUtilization", "CacheClusterId", "accessweaver-prod-redis-001"],
          [".", "CacheHitRate", ".", "."]
        ],
        "period": 300,
        "stat": "Average",
        "region": "eu-west-1",
        "title": "💾 Data Layer Performance",
        "yAxis": {
          "left": {
            "min": 0
          }
        }
      }
    }
  ]
}
```

#### Logs Insights Queries Intégrées

```sql
-- Top 10 erreurs par service (dernière heure)
fields @timestamp, service, level, message, tenant_id, trace_id
| filter level = "ERROR"
| stats count() as error_count by service, message
| sort error_count desc
| limit 10

-- Latence moyenne des décisions d'autorisation par tenant
fields @timestamp, tenant_id, operation_duration_ms
| filter operation = "authorization_check"
| stats avg(operation_duration_ms) as avg_latency by tenant_id
| sort avg_latency desc

-- Cache hit ratio par type de permission
fields @timestamp, cache_operation, cache_result, permission_type
| filter cache_operation = "get"
| stats count() as total, count(cache_result = "hit") as hits by permission_type
| eval hit_ratio = hits / total * 100
| sort hit_ratio asc
```

### 2. Tenant Usage Dashboard

#### Multi-Tenant Metrics

```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AccessWeaver/Authorization", "RequestRate", "TenantId", "tenant-1"],
          [".", ".", ".", "tenant-2"],
          [".", ".", ".", "tenant-3"],
          [".", ".", ".", "tenant-4"],
          [".", ".", ".", "tenant-5"]
        ],
        "period": 300,
        "stat": "Sum",
        "region": "eu-west-1",
        "title": "📊 Requests par Tenant (Top 5)",
        "yAxis": {
          "left": {
            "min": 0
          }
        },
        "annotations": {
          "horizontal": [
            {
              "label": "Rate Limit Warning",
              "value": 1000
            }
          ]
        }
      }
    },
    {
      "type": "log",
      "properties": {
        "query": "SOURCE '/aws/ecs/accessweaver-prod/aw-api-gateway'\n| fields @timestamp, tenant_id, endpoint, response_time_ms\n| filter operation = \"authorization_check\"\n| stats avg(response_time_ms) as avg_latency, count() as request_count by tenant_id\n| sort avg_latency desc\n| limit 20",
        "region": "eu-west-1",
        "title": "🎯 Tenant Performance Analytics",
        "view": "table"
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AccessWeaver/Business", "ActiveUsers", "TenantId", "ALL"],
          [".", "MonthlyAuthRequests", ".", "."],
          [".", "StorageUsageGB", ".", "."],
          [".", "ComputeUnitsConsumed", ".", "."]
        ],
        "period": 3600,
        "stat": "Average",
        "region": "eu-west-1",
        "title": "💼 Business Metrics",
        "yAxis": {
          "left": {
            "min": 0
          }
        }
      }
    }
  ]
}
```

### 3. Performance Deep Dive Dashboard

#### Decision Latency Analysis

```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AccessWeaver/Authorization", "DecisionLatency", "Percentile", "p50"],
          [".", ".", ".", "p95"],
          [".", ".", ".", "p99"],
          [".", ".", ".", "p99.9"]
        ],
        "period": 300,
        "stat": "Average",
        "region": "eu-west-1",
        "title": "⚡ Authorization Decision Latency",
        "yAxis": {
          "left": {
            "min": 0,
            "max": 100
          }
        },
        "annotations": {
          "horizontal": [
            {
              "label": "SLA Target (p95)",
              "value": 10
            },
            {
              "label": "Critical Threshold (p99)",
              "value": 50
            }
          ]
        }
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AccessWeaver/Cache", "HitRatio", "CacheType", "permissions"],
          [".", ".", ".", "roles"],
          [".", ".", ".", "policies"],
          [".", ".", ".", "sessions"]
        ],
        "period": 300,
        "stat": "Average",
        "region": "eu-west-1",
        "title": "🎯 Cache Efficiency by Type",
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

## 🔧 Métriques Custom AccessWeaver

### 1. Authorization Metrics

#### Code Java Spring Boot

```java
@Component
public class AuthorizationMetrics {
    
    private final MeterRegistry meterRegistry;
    private final Timer.Sample decisionTimer;
    
    // Compteurs par tenant
    private final Map<String, Counter> authRequestCounters = new ConcurrentHashMap<>();
    private final Map<String, Timer> decisionLatencyTimers = new ConcurrentHashMap<>();
    
    public AuthorizationMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
    }
    
    /**
     * Track authorization decision latency
     */
    public Timer.Sample startDecisionTimer(String tenantId, String resource, String action) {
        Timer timer = getDecisionLatencyTimer(tenantId);
        
        Timer.Sample sample = Timer.start(meterRegistry);
        
        // Tags pour segmentation
        sample.tag("tenant_id", tenantId)
              .tag("resource_type", extractResourceType(resource))
              .tag("action", action)
              .tag("environment", getEnvironment());
              
        return sample;
    }
    
    public void recordDecision(Timer.Sample sample, String tenantId, boolean allowed, 
                              String reason, boolean fromCache) {
        sample.stop(Timer.builder("accessweaver.authorization.decision_latency")
            .description("Time taken for authorization decision")
            .tag("tenant_id", tenantId)
            .tag("result", allowed ? "allowed" : "denied")
            .tag("reason", reason)
            .tag("cache_hit", String.valueOf(fromCache))
            .register(meterRegistry));
            
        // Increment request counter
        getAuthRequestCounter(tenantId).increment();
        
        // Record result distribution
        meterRegistry.counter("accessweaver.authorization.decisions",
            "tenant_id", tenantId,
            "result", allowed ? "allowed" : "denied",
            "source", fromCache ? "cache" : "computed")
            .increment();
    }
    
    /**
     * Track cache performance
     */
    public void recordCacheOperation(String tenantId, String cacheType, 
                                   String operation, boolean hit) {
        meterRegistry.counter("accessweaver.cache.operations",
            "tenant_id", tenantId,
            "cache_type", cacheType,
            "operation", operation,
            "result", hit ? "hit" : "miss")
            .increment();
            
        // Cache hit ratio gauge
        Gauge.builder("accessweaver.cache.hit_ratio")
            .description("Cache hit ratio by type")
            .tag("tenant_id", tenantId)
            .tag("cache_type", cacheType)
            .register(meterRegistry, () -> calculateHitRatio(tenantId, cacheType));
    }
    
    /**
     * Business metrics
     */
    public void recordActiveUser(String tenantId, String userId) {
        meterRegistry.gauge("accessweaver.business.active_users",
            Tags.of("tenant_id", tenantId),
            getActiveUserCount(tenantId));
    }
    
    public void recordStorageUsage(String tenantId, long sizeBytes) {
        meterRegistry.gauge("accessweaver.business.storage_usage_bytes",
            Tags.of("tenant_id", tenantId),
            sizeBytes);
    }
    
    /**
     * Error tracking
     */
    public void recordError(String tenantId, String service, String errorType, 
                           String errorMessage, Exception exception) {
        meterRegistry.counter("accessweaver.errors",
            "tenant_id", tenantId,
            "service", service,
            "error_type", errorType,
            "error_class", exception.getClass().getSimpleName())
            .increment();
            
        // Error rate gauge
        Gauge.builder("accessweaver.service.error_rate")
            .description("Error rate per service")
            .tag("service", service)
            .tag("tenant_id", tenantId)
            .register(meterRegistry, () -> calculateErrorRate(service, tenantId));
    }
    
    // Helper methods
    private Timer getDecisionLatencyTimer(String tenantId) {
        return decisionLatencyTimers.computeIfAbsent(tenantId, 
            tid -> Timer.builder("accessweaver.authorization.decision_latency")
                .description("Authorization decision latency by tenant")
                .tag("tenant_id", tid)
                .register(meterRegistry));
    }
    
    private Counter getAuthRequestCounter(String tenantId) {
        return authRequestCounters.computeIfAbsent(tenantId,
            tid -> Counter.builder("accessweaver.authorization.requests")
                .description("Authorization requests by tenant")
                .tag("tenant_id", tid)
                .register(meterRegistry));
    }
}
```

### 2. Aspect pour Tracking Automatique

```java
@Aspect
@Component
public class MetricsAspect {
    
    private final AuthorizationMetrics metrics;
    
    @Around("@annotation(TrackAuthorization)")
    public Object trackAuthorizationDecision(ProceedingJoinPoint joinPoint) throws Throwable {
        // Extract tenant context
        String tenantId = TenantContext.getCurrentTenantId();
        String resource = extractResource(joinPoint.getArgs());
        String action = extractAction(joinPoint.getArgs());
        
        Timer.Sample sample = metrics.startDecisionTimer(tenantId, resource, action);
        
        try {
            Object result = joinPoint.proceed();
            
            // Extract decision details
            AuthorizationResult authResult = (AuthorizationResult) result;
            metrics.recordDecision(sample, tenantId, 
                authResult.isAllowed(), 
                authResult.getReason(),
                authResult.isFromCache());
                
            return result;
            
        } catch (Exception e) {
            metrics.recordError(tenantId, "authorization", 
                "decision_error", e.getMessage(), e);
            throw e;
        }
    }
    
    @Around("@annotation(TrackCache)")
    public Object trackCacheOperation(ProceedingJoinPoint joinPoint) throws Throwable {
        String tenantId = TenantContext.getCurrentTenantId();
        String cacheType = extractCacheType(joinPoint);
        String operation = extractOperation(joinPoint);
        
        long startTime = System.currentTimeMillis();
        boolean cacheHit = false;
        
        try {
            Object result = joinPoint.proceed();
            cacheHit = (result != null);
            
            metrics.recordCacheOperation(tenantId, cacheType, operation, cacheHit);
            
            return result;
            
        } finally {
            long duration = System.currentTimeMillis() - startTime;
            // Record cache operation latency
        }
    }
}
```

### 3. Custom Annotations

```java
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface TrackAuthorization {
    String operation() default "";
    String[] tags() default {};
}

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface TrackCache {
    String cacheType();
    String operation();
}

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface TrackPerformance {
    String operation();
    long warningThresholdMs() default 1000;
    long errorThresholdMs() default 5000;
}
```

## 🚨 Alerting Proactif

### 1. Composite Alarms

```json
{
  "AlarmName": "AccessWeaver-SystemHealth-Critical",
  "AlarmDescription": "Composite alarm for critical system health",
  "AlarmRule": "(ALARM('AccessWeaver-ALB-HighLatency') OR ALARM('AccessWeaver-ECS-HighCPU') OR ALARM('AccessWeaver-RDS-ConnectionIssues')) AND NOT ALARM('AccessWeaver-MaintenanceMode')",
  "ActionsEnabled": true,
  "AlarmActions": [
    "arn:aws:sns:eu-west-1:123456789012:accessweaver-critical-alerts"
  ],
  "OKActions": [
    "arn:aws:sns:eu-west-1:123456789012:accessweaver-recovery-notifications"
  ],
  "TreatMissingData": "breaching"
}
```

### 2. ML Anomaly Detection

```json
{
  "MetricName": "accessweaver.authorization.request_rate",
  "Namespace": "AccessWeaver/Authorization",
  "Dimensions": [
    {
      "Name": "TenantId",
      "Value": "*"
    }
  ],
  "Stat": "Average",
  "AnomalyDetector": {
    "MetricMathAnomalyDetector": {
      "MetricDataQueries": [
        {
          "Id": "m1",
          "MetricStat": {
            "Metric": {
              "MetricName": "RequestRate",
              "Namespace": "AccessWeaver/Authorization",
              "Dimensions": [
                {
                  "Name": "TenantId",
                  "Value": "*"
                }
              ]
            },
            "Period": 300,
            "Stat": "Average"
          }
        }
      ]
    }
  }
}
```

### 3. Lambda Function pour Enrichissement d'Alertes

```python
import json
import boto3
import requests
from datetime import datetime, timedelta

def lambda_handler(event, context):
    """
    Enrichit les alertes CloudWatch avec du contexte et route vers Slack
    """
    
    # Parse SNS message
    sns_message = json.loads(event['Records'][0]['Sns']['Message'])
    alarm_name = sns_message['AlarmName']
    new_state = sns_message['NewStateValue']
    reason = sns_message['NewStateReason']
    
    # Extract tenant and service context
    context_data = extract_alarm_context(alarm_name)
    
    # Get additional metrics for context
    additional_metrics = get_related_metrics(context_data)
    
    # Determine severity and escalation
    severity = determine_severity(alarm_name, context_data)
    escalation_needed = should_escalate(severity, context_data)
    
    # Format message for Slack
    slack_message = format_slack_message(
        alarm_name, new_state, reason, 
        context_data, additional_metrics, 
        severity, escalation_needed
    )
    
    # Send to appropriate Slack channel
    channel = get_slack_channel(severity, context_data)
    send_slack_message(channel, slack_message)
    
    # Trigger escalation if needed
    if escalation_needed:
        trigger_escalation(alarm_name, context_data, severity)
    
    return {
        'statusCode': 200,
        'body': json.dumps('Alert processed successfully')
    }

def format_slack_message(alarm_name, state, reason, context, metrics, severity, escalate):
    """
    Format enriched Slack message
    """
    
    emoji = {
        'CRITICAL': '🚨',
        'HIGH': '⚠️',
        'MEDIUM': '📢',
        'LOW': 'ℹ️'
    }
    
    color = {
        'CRITICAL': 'danger',
        'HIGH': 'warning', 
        'MEDIUM': 'good',
        'LOW': '#439FE0'
    }
    
    message = {
        "channel": context.get('slack_channel', '#alerts'),
        "username": "AccessWeaver Monitor",
        "icon_emoji": ":robot_face:",
        "attachments": [
            {
                "color": color[severity],
                "title": f"{emoji[severity]} {alarm_name}",
                "title_link": f"https://console.aws.amazon.com/cloudwatch/home#alarmsV2:alarm/{alarm_name}",
                "text": reason,
                "fields": [
                    {
                        "title": "State",
                        "value": state,
                        "short": True
                    },
                    {
                        "title": "Severity",
                        "value": severity,
                        "short": True
                    },
                    {
                        "title": "Tenant",
                        "value": context.get('tenant_id', 'ALL'),
                        "short": True
                    },
                    {
                        "title": "Service", 
                        "value": context.get('service', 'Unknown'),
                        "short": True
                    }
                ],
                "actions": [
                    {
                        "type": "button",
                        "text": "View Dashboard",
                        "url": context.get('dashboard_url', '')
                    },
                    {
                        "type": "button", 
                        "text": "View Logs",
                        "url": context.get('logs_url', '')
                    }
                ],
                "footer": "AccessWeaver Monitoring",
                "ts": int(datetime.now().timestamp())
            }
        ]
    }
    
    if escalate:
        message["attachments"][0]["fields"].append({
            "title": "⚡ Action Required",
            "value": "Escalating to on-call engineer",
            "short": False
        })
    
    return message
```

## 💰 Cost Optimization

### 1. Metrics Filtering Strategy

```yaml
# CloudWatch Agent Configuration
metrics:
  namespace: AccessWeaver
  
  # High-frequency metrics (1min resolution)
  high_frequency:
    - authorization.decision_latency
    - authorization.request_rate  
    - system.cpu_utilization
    - system.memory_utilization
    - cache.hit_ratio
    
  # Medium-frequency metrics (5min resolution)  
  medium_frequency:
    - business.active_users
    - business.storage_usage
    - errors.error_rate
    - network.throughput
    
  # Low-frequency metrics (15min resolution)
  low_frequency:
    - business.monthly_requests
    - cost.resource_usage
    - audit.compliance_metrics
    
  # Conditional metrics (only in prod)
  conditional:
    performance_insights: prod
    detailed_monitoring: prod
    x_ray_tracing: prod
    
  # Sampling configuration
  sampling:
    error_logs: 100%      # Always capture errors
    info_logs: 10%        # Sample info logs  
    debug_logs: 1%        # Minimal debug sampling
    trace_logs: 0%        # Disabled by default
```

### 2. Log Retention Policy

```json
{
  "log_groups": {
    "/aws/ecs/accessweaver-prod/aw-api-gateway": {
      "retention_days": 30,
      "filter_pattern": "[timestamp, request_id, level=\"ERROR\" || level=\"WARN\", ...]"
    },
    "/aws/ecs/accessweaver-prod/aw-pdp-service": {
      "retention_days": 14,
      "filter_pattern": "[timestamp, request_id, level, tenant_id, operation=\"authorization_check\", ...]"
    },
    "/aws/ecs/accessweaver-staging": {
      "retention_days": 7
    },
    "/aws/ecs/accessweaver-dev": {
      "retention_days": 3
    }
  },
  
  "export_configuration": {
    "s3_bucket": "accessweaver-logs-archive",
    "lifecycle_policy": {
      "transition_to_ia": 30,
      "transition_to_glacier": 90,
      "expiration": 365
    },
    "compression": "gzip",
    "format": "parquet"
  }
}
```

### 3. Reserved Capacity Planning

```bash
#!/bin/bash
# cloudwatch-capacity-planning.sh

# Analyze historical usage for Reserved Capacity
aws logs insights start-query \
  --log-group-name "/aws/ecs/accessweaver-prod" \
  --start-time $(date -d '30 days ago' +%s) \
  --end-time $(date +%s) \
  --query-string '
    fields @timestamp, tenant_id
    | stats count() as requests by bin(5m)
    | sort @timestamp desc
  ' \
  > usage_analysis.json

# Calculate baseline metrics
python3 << EOF
import json
import statistics

with open('usage_analysis.json', 'r') as f:
    data = json.load(f)

requests = [int(item['requests']) for item in data['results']]

baseline = statistics.median(requests)
peak = max(requests) 
recommended_capacity = baseline * 1.2  # 20% buffer

print(f"Baseline: {baseline} req/5min")
print(f"Peak: {peak} req/5min") 
print(f"Recommended Reserved: {recommended_capacity} req/5min")
print(f"Potential Monthly Savings: ${(baseline * 0.3 * 24 * 30):.2f}")
EOF
```

## 🔍 Advanced Queries & Analytics

### 1. Performance Analysis Queries

```sql
-- P95 latency trend by tenant (last 24h)
fields @timestamp, tenant_id, operation_duration_ms
| filter operation = "authorization_check"
| filter @timestamp > @timestamp - 1d
| stats 
    avg(operation_duration_ms) as avg_latency,
    pct(operation_duration_ms, 95) as p95_latency,
    count() as request_count
  by tenant_id, bin(1h)
| sort @timestamp desc

-- Error correlation analysis
fields @timestamp, service, tenant_id, level, message, trace_id
| filter level = "ERROR"
| filter @timestamp > @timestamp - 1h
| stats count() as error_count by service, tenant_id
| sort error_count desc
| limit 20

-- Cache efficiency by tenant and type
fields @timestamp, tenant_id, cache_type, cache_result
| filter cache_operation = "get"
| stats 
    count() as total_ops,
    count(cache_result = "hit") as hits
  by tenant_id, cache_type
| eval hit_ratio = hits / total_ops * 100
| sort hit_ratio asc

-- Business intelligence - Usage patterns
fields @timestamp, tenant_id, endpoint, user_id
| filter endpoint like /api/v1/
| filter @timestamp > @timestamp - 7d
| stats 
    count() as total_requests,
    count_distinct(user_id) as active_users,
    avg(response_time_ms) as avg_response_time
  by tenant_id, bin(1d)
| sort @timestamp desc

-- Cost analysis by tenant
fields @timestamp, tenant_id, compute_units, storage_bytes, bandwidth_bytes
| filter @timestamp > @timestamp - 30d
| stats 
    sum(compute_units) as total_compute,
    sum(storage_bytes) as total_storage,
    sum(bandwidth_bytes) as total_bandwidth
  by tenant_id
| eval estimated_cost = total_compute * 0.0001 + total_storage * 0.000001 + total_bandwidth * 0.00001
| sort estimated_cost desc

-- Security audit - Failed authorization attempts
fields @timestamp, tenant_id, user_id, resource, action, result, reason
| filter operation = "authorization_check" and result = "denied"
| filter @timestamp > @timestamp - 1h
| stats count() as failed_attempts by tenant_id, user_id, resource
| sort failed_attempts desc
| limit 50

-- Performance bottleneck identification
fields @timestamp, service, operation, duration_ms, tenant_id
| filter duration_ms > 1000  # Slow operations > 1s
| stats 
    count() as slow_ops,
    avg(duration_ms) as avg_duration,
    max(duration_ms) as max_duration
  by service, operation
| sort slow_ops desc
```

### 2. Custom Dashboard Templates

#### Executive Summary Dashboard

```json
{
  "dashboard_name": "AccessWeaver - Executive Summary",
  "period_start": "P7D",
  "widgets": [
    {
      "type": "number",
      "properties": {
        "metrics": [
          ["AccessWeaver/Business", "TotalActiveUsers"]
        ],
        "period": 86400,
        "stat": "Maximum",
        "region": "eu-west-1",
        "title": "👥 Total Active Users (7d)",
        "setPeriodToTimeRange": true,
        "sparkline": true,
        "trend": true
      }
    },
    {
      "type": "number", 
      "properties": {
        "metrics": [
          ["AccessWeaver/Authorization", "TotalRequests"]
        ],
        "period": 86400,
        "stat": "Sum",
        "region": "eu-west-1", 
        "title": "🔐 Authorization Requests (7d)",
        "setPeriodToTimeRange": true,
        "sparkline": true,
        "trend": true
      }
    },
    {
      "type": "number",
      "properties": {
        "metrics": [
          ["AccessWeaver/System", "Availability"]
        ],
        "period": 3600,
        "stat": "Average",
        "region": "eu-west-1",
        "title": "⚡ System Availability (%)",
        "setPeriodToTimeRange": true,
        "sparkline": false,
        "trend": false
      }
    },
    {
      "type": "number",
      "properties": {
        "metrics": [
          ["AccessWeaver/Authorization", "AverageLatency"]
        ],
        "period": 3600,
        "stat": "Average", 
        "region": "eu-west-1",
        "title": "⏱️ Avg Response Time (ms)",
        "setPeriodToTimeRange": true,
        "sparkline": true,
        "trend": true
      }
    },
    {
      "type": "log",
      "properties": {
        "query": "SOURCE '/aws/ecs/accessweaver-prod'\n| fields @timestamp, tenant_id\n| stats count() as requests by tenant_id\n| sort requests desc\n| limit 10",
        "region": "eu-west-1",
        "title": "📊 Top 10 Tenants by Usage",
        "view": "table"
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/Billing", "EstimatedCharges", "Currency", "USD", "ServiceName", "AmazonCloudWatch"],
          ["...", "AmazonECS"],
          ["...", "AmazonRDS"],
          ["...", "AmazonElastiCache"]
        ],
        "period": 86400,
        "stat": "Maximum",
        "region": "us-east-1",
        "title": "💰 Infrastructure Costs (USD)",
        "yAxis": {
          "left": {
            "min": 0
          }
        }
      }
    }
  ]
}
```

## 📱 Mobile-Ready Dashboards

### 1. Ops Dashboard Mobile

```json
{
  "dashboard_name": "AccessWeaver - Mobile Ops",
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AccessWeaver/System", "OverallHealth"]
        ],
        "period": 300,
        "stat": "Average",
        "region": "eu-west-1",
        "title": "🟢 System Status",
        "view": "singleValue",
        "stacked": false
      }
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AccessWeaver/Alerts", "CriticalAlerts"],
          [".", "WarningAlerts"]
        ],
        "period": 300,
        "stat": "Sum",
        "region": "eu-west-1",
        "title": "🚨 Active Alerts",
        "view": "singleValue"
      }
    },
    {
      "type": "log",
      "properties": {
        "query": "SOURCE '/aws/ecs/accessweaver-prod'\n| fields @timestamp, level, service, message\n| filter level = \"ERROR\"\n| sort @timestamp desc\n| limit 5",
        "region": "eu-west-1",
        "title": "🔴 Recent Errors",
        "view": "table"
      }
    }
  ]
}
```

## 🔮 Predictive Analytics

### 1. Capacity Forecasting

```python
import boto3
import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression
from datetime import datetime, timedelta

class CapacityForecaster:
    
    def __init__(self):
        self.cloudwatch = boto3.client('cloudwatch')
        self.models = {}
        
    def collect_historical_data(self, metric_name, days=90):
        """
        Collect historical metrics for forecasting
        """
        end_time = datetime.now()
        start_time = end_time - timedelta(days=days)
        
        response = self.cloudwatch.get_metric_statistics(
            Namespace='AccessWeaver/Authorization',
            MetricName=metric_name,
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,  # 1 hour
            Statistics=['Average']
        )
        
        data = []
        for point in response['Datapoints']:
            data.append({
                'timestamp': point['Timestamp'],
                'value': point['Average']
            })
            
        return pd.DataFrame(data).sort_values('timestamp')
    
    def train_forecast_model(self, metric_name):
        """
        Train ML model for capacity forecasting
        """
        df = self.collect_historical_data(metric_name)
        
        # Feature engineering
        df['hour'] = df['timestamp'].dt.hour
        df['day_of_week'] = df['timestamp'].dt.dayofweek
        df['day_of_month'] = df['timestamp'].dt.day
        df['trend'] = range(len(df))
        
        # Prepare features
        features = ['hour', 'day_of_week', 'day_of_month', 'trend']
        X = df[features]
        y = df['value']
        
        # Train model
        model = LinearRegression()
        model.fit(X, y)
        
        self.models[metric_name] = {
            'model': model,
            'features': features,
            'last_timestamp': df['timestamp'].max()
        }
        
        return model
    
    def forecast_capacity(self, metric_name, hours_ahead=168):  # 1 week
        """
        Forecast capacity requirements
        """
        if metric_name not in self.models:
            self.train_forecast_model(metric_name)
            
        model_info = self.models[metric_name]
        model = model_info['model']
        
        # Generate future timestamps
        start_time = model_info['last_timestamp']
        future_times = [start_time + timedelta(hours=i) for i in range(1, hours_ahead + 1)]
        
        # Prepare future features
        future_data = []
        for i, ts in enumerate(future_times):
            future_data.append({
                'hour': ts.hour,
                'day_of_week': ts.dayofweek, 
                'day_of_month': ts.day,
                'trend': len(self.collect_historical_data(metric_name)) + i
            })
            
        X_future = pd.DataFrame(future_data)
        
        # Make predictions
        predictions = model.predict(X_future)
        
        # Calculate confidence intervals (simple approach)
        historical_data = self.collect_historical_data(metric_name)
        std_dev = historical_data['value'].std()
        
        forecast_data = []
        for i, pred in enumerate(predictions):
            forecast_data.append({
                'timestamp': future_times[i],
                'predicted_value': pred,
                'lower_bound': pred - 2 * std_dev,
                'upper_bound': pred + 2 * std_dev
            })
            
        return pd.DataFrame(forecast_data)
    
    def detect_anomalies(self, metric_name, threshold_std=2):
        """
        Detect anomalies in metrics using statistical methods
        """
        df = self.collect_historical_data(metric_name, days=30)
        
        # Calculate rolling statistics
        df['rolling_mean'] = df['value'].rolling(window=24).mean()  # 24 hour window
        df['rolling_std'] = df['value'].rolling(window=24).std()
        
        # Identify anomalies
        df['anomaly'] = (
            (df['value'] > df['rolling_mean'] + threshold_std * df['rolling_std']) |
            (df['value'] < df['rolling_mean'] - threshold_std * df['rolling_std'])
        )
        
        return df[df['anomaly'] == True]
    
    def generate_capacity_report(self):
        """
        Generate comprehensive capacity report
        """
        metrics = [
            'RequestRate',
            'DecisionLatency', 
            'CacheHitRatio',
            'ActiveUsers'
        ]
        
        report = {
            'generated_at': datetime.now(),
            'forecasts': {},
            'anomalies': {},
            'recommendations': []
        }
        
        for metric in metrics:
            # Generate forecast
            forecast = self.forecast_capacity(metric)
            report['forecasts'][metric] = forecast.to_dict('records')
            
            # Detect anomalies
            anomalies = self.detect_anomalies(metric)
            report['anomalies'][metric] = anomalies.to_dict('records')
            
            # Generate recommendations
            max_predicted = forecast['predicted_value'].max()
            current_capacity = self.get_current_capacity(metric)
            
            if max_predicted > current_capacity * 0.8:
                report['recommendations'].append({
                    'metric': metric,
                    'type': 'scale_up',
                    'reason': f'Predicted peak ({max_predicted:.2f}) approaching capacity limit',
                    'urgency': 'high' if max_predicted > current_capacity * 0.9 else 'medium'
                })
                
        return report
```

## 🔧 Deployment & Configuration

### 1. Terraform Configuration

```hcl
# cloudwatch-dashboards.tf

resource "aws_cloudwatch_dashboard" "system_health" {
  dashboard_name = "AccessWeaver-SystemHealth-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      # System Overview
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "${var.project_name}-${var.environment}-alb"],
            [".", "TargetResponseTime", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_ELB_5XX_Count", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "🌐 Load Balancer Performance"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      # ECS Services
      {
        type   = "metric" 
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "${var.project_name}-${var.environment}-aw-api-gateway", "ClusterName", "${var.project_name}-${var.environment}-cluster"],
            [".", "MemoryUtilization", ".", ".", ".", "."],
            [".", "CPUUtilization", "ServiceName", "${var.project_name}-${var.environment}-aw-pdp-service", ".", "."],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average" 
          region = var.aws_region
          title  = "🚀 ECS Services Health"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Component   = "monitoring"
  }
}

# Custom Metrics Namespace
resource "aws_cloudwatch_log_metric_filter" "authorization_latency" {
  name           = "authorization-decision-latency"
  log_group_name = "/aws/ecs/${var.project_name}-${var.environment}/aw-api-gateway"
  
  pattern = "[timestamp, request_id, level, tenant_id, operation=\"authorization_check\", duration_ms, ...]"
  
  metric_transformation {
    name      = "DecisionLatency"
    namespace = "AccessWeaver/Authorization"
    value     = "$duration_ms"
    
    dimensions = {
      TenantId = "$tenant_id"
    }
  }
}

# Composite Alarm for System Health
resource "aws_cloudwatch_composite_alarm" "system_health" {
  alarm_name        = "AccessWeaver-${var.environment}-SystemHealth"
  alarm_description = "Overall system health for AccessWeaver ${var.environment}"
  
  alarm_rule = join(" OR ", [
    "ALARM('${aws_cloudwatch_metric_alarm.alb_high_latency.alarm_name}')",
    "ALARM('${aws_cloudwatch_metric_alarm.ecs_high_cpu.alarm_name}')", 
    "ALARM('${aws_cloudwatch_metric_alarm.rds_connection_issues.alarm_name}')"
  ])
  
  actions_enabled = true
  alarm_actions   = [aws_sns_topic.alerts.arn]
  ok_actions      = [aws_sns_topic.alerts.arn]
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Severity    = "critical"
  }
}
```

### 2. Application Configuration

```yaml
# application-prod.yml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: when-authorized
    metrics:
      enabled: true
  metrics:
    export:
      cloudwatch:
        enabled: true
        namespace: AccessWeaver/Authorization
        batch-size: 20
        step: PT1M  # 1 minute resolution
        
    distribution:
      percentiles-histogram:
        http.server.requests: true
        accessweaver.authorization.decision_latency: true
        
    tags:
      environment: ${ENVIRONMENT}
      service: ${SPRING_APPLICATION_NAME}
      version: ${APPLICATION_VERSION:unknown}

# Custom metrics configuration
accessweaver:
  monitoring:
    metrics:
      enabled: true
      high-cardinality-tags: tenant_id,resource_type,action
      
    tracing:
      enabled: true
      sampling-rate: 0.1  # 10% sampling in prod
      
    alerts:
      decision-latency-threshold-ms: 50
      error-rate-threshold-percent: 1.0
      cache-hit-ratio-threshold-percent: 80.0
```

## 📋 Maintenance & Best Practices

### 1. Dashboard Maintenance Schedule

```bash
#!/bin/bash
# dashboard-maintenance.sh

# Weekly dashboard optimization
optimize_dashboards() {
    echo "🔧 Optimizing CloudWatch dashboards..."
    
    # Remove unused metrics
    aws cloudwatch list-metrics --namespace "AccessWeaver" \
        --query 'Metrics[?LastDataPoint < `2024-01-01`]' \
        > unused_metrics.json
    
    # Archive old dashboard versions
    aws cloudwatch list-dashboards \
        --query 'DashboardEntries[?LastModified < `2024-01-01`]' \
        > old_dashboards.json
        
    # Optimize log retention
    aws logs describe-log-groups \
        --query 'logGroups[?starts_with(logGroupName, `/aws/ecs/accessweaver`)]' \
        | jq -r '.[].logGroupName' \
        | while read log_group; do
            # Adjust retention based on usage
            usage=$(aws logs describe-log-streams --log-group-name "$log_group" --query 'length(logStreams)')
            if [ "$usage" -lt 10 ]; then
                aws logs put-retention-policy --log-group-name "$log_group" --retention-in-days 7
            fi
        done
}

# Monthly cost analysis
analyze_costs() {
    echo "💰 Analyzing CloudWatch costs..."
    
    # Generate cost report
    python3 << EOF
import boto3
import pandas as pd
from datetime import datetime, timedelta

ce = boto3.client('ce')

# Get CloudWatch costs for last 30 days
response = ce.get_cost_and_usage(
    TimePeriod={
        'Start': (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d'),
        'End': datetime.now().strftime('%Y-%m-%d')
    },
    Granularity='DAILY',
    Metrics=['BlendedCost'],
    GroupBy=[
        {'Type': 'DIMENSION', 'Key': 'SERVICE'}
    ],
    Filter={
        'Dimensions': {
            'Key': 'SERVICE',
            'Values': ['AmazonCloudWatch']
        }
    }
)

total_cost = sum(float(item['Metrics']['BlendedCost']['Amount']) 
                for group in response['ResultsByTime'] 
                for item in group['Groups'])

print(f"Total CloudWatch cost (30d): \${total_cost:.2f}")

# Recommendations
if total_cost > 500:
    print("⚠️  High CloudWatch costs detected")
    print("Consider optimizing log retention and metric resolution")
elif total_cost > 200:
    print("📊 Moderate CloudWatch usage")
    print("Monitor for cost optimization opportunities")
else:
    print("✅ CloudWatch costs within expected range")
EOF
}

# Quarterly dashboard review
quarterly_review() {
    echo "📈 Quarterly dashboard review..."
    
    # Check dashboard usage
    aws cloudwatch get-insights-summary \
        --start-time $(date -d '90 days ago' +%s) \
        --end-time $(date +%s) \
        > dashboard_usage.json
        
    # Identify unused dashboards
    jq -r '.Summaries[] | select(.UniqueViewers < 2) | .DashboardName' dashboard_usage.json \
        > unused_dashboards.txt
        
    echo "Dashboards with low usage:"
    cat unused_dashboards.txt
}

# Run maintenance based on schedule
case "$1" in
    "weekly")
        optimize_dashboards
        ;;
    "monthly") 
        analyze_costs
        ;;
    "quarterly")
        quarterly_review
        ;;
    *)
        echo "Usage: $0 {weekly|monthly|quarterly}"
        exit 1
        ;;
esac
```

### 2. Performance Tuning Guide

```markdown
## CloudWatch Performance Optimization

### 1. Metric Resolution Optimization
- **High-frequency (1min)**: Critical alerts and real-time dashboards
- **Medium-frequency (5min)**: Operational monitoring
- **Low-frequency (15min)**: Trend analysis and business metrics

### 2. Query Optimization
- Use metric filters instead of parsing in Insights
- Batch CloudWatch API calls
- Cache frequently accessed metrics
- Use composite alarms for complex conditions

### 3. Cost Control Strategies
- Implement metric lifecycle policies
- Use log sampling for high-volume streams
- Optimize dashboard refresh rates
- Archive historical data to S3

### 4. Alert Tuning
- Use percentage-based thresholds for scalability
- Implement anomaly detection for seasonal patterns
- Group related alerts into composite alarms
- Set appropriate evaluation periods to avoid flapping
```

## 🎯 Next Steps

Avec ce guide CloudWatch complet, vous avez maintenant :

✅ **Dashboards enterprise** multi-niveaux (system, tenant, performance)  
✅ **Métriques custom** AccessWeaver intégrées  
✅ **Alerting proactif** avec ML et composite alarms  
✅ **Cost optimization** automatisée  
✅ **Mobile-ready** dashboards pour ops 24/7

**Prochaines étapes :**
1. **Alerting avancé** (monitoring/alerting.md) - Système d'alerting intelligent
2. **Distributed tracing** (monitoring/tracing.md) - Correlation cross-services
3. **Performance monitoring** (monitoring/performance.md) - APM enterprise

---

⚠️ **ATTENTION : Longueur de conversation** ⚠️

Notre conversation devient volumineuse. Pour maintenir la performance et la clarité, je vous propose de démarrer une nouvelle session avec ce prompt de continuation :

```
Tu es un expert DevOps/Infrastructure spécialisé en Alerting & Observabilité pour AccessWeaver.

CONTEXTE PROJET :
- AccessWeaver = SaaS d'autorisation (RBAC/ABAC/ReBAC) multi-tenant
- Stack : Java 21, Spring Boot 3.x, PostgreSQL, Redis, Angular  
- Infrastructure : AWS ECS Fargate, ALB, RDS, ElastiCache, Terraform

PROGRESSION MONITORING & OBSERVABILITÉ :
✅ Setup strategy (coûts, outils, architecture)
✅ Metrics strategy (45+ métriques business/techniques)  
✅ Logs strategy (JSON structuré, RGPD, correlation)
✅ CloudWatch COMPLET (dashboards enterprise, métriques custom, alerting proactif, cost optimization)

MISSION ACTUELLE : Continuer avec monitoring/alerting.md
- Système d'alerting intelligent avec ML anomaly detection
- Zero false-positives avec seuils adaptatifs
- Escalation automatique et integration Slack/PagerDuty
- Correlation multi-services et incident management
- Runbooks automatisés pour résolution proactive

OBJECTIFS :
- Alerting proactif (pas réactif) avec prediction
- Integration complète DevOps/SRE workflows  
- Documentation avec artifacts prêts-à-déployer
- Support multi-tenant native dans tous les alerts

CONTRAINTES :
- Zero false-positive policy stricte
- Coûts alerting maîtrisés (<$50/mois)
- Response time < 2min pour critical alerts
- Compliance RGPD dans incident handling

DÉMARRAGE : Créer monitoring/alerting.md avec système d'alerting enterprise pour AccessWeaver, en utilisant les métriques CloudWatch définies précédemment.
```

Souhaitez-vous continuer avec cette nouvelle session, ou préférez-vous que je termine un autre aspect du monitoring dans cette conversation ?