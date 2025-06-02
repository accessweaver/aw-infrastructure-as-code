# 📊 Stratégie de Logging - AccessWeaver

Stratégie complète de logging enterprise pour AccessWeaver avec focus sur la sécurité, compliance RGPD et observabilité multi-tenant.

## 🎯 Objectifs du Logging

### ✅ Observabilité Complète
- **Correlation cross-services** avec trace ID unique
- **Logs structurés JSON** pour parsing automatique
- **Context multi-tenant** automatique dans tous les logs
- **Performance tracking** des décisions d'autorisation

### ✅ Sécurité & Audit
- **Audit trail complet** pour compliance (RGPD, SOX)
- **Détection d'anomalies** automatique (failed auth, brute force)
- **Anonymisation des données** sensibles (emails, IPs)
- **Immutabilité des logs** avec signatures

### ✅ Coûts Maîtrisés
- **Retention intelligente** par criticité des logs
- **Compression et archivage** automatique
- **Sampling adaptatif** pour les logs debug
- **Budget alerting** CloudWatch

### ✅ DevOps Experience
- **Centralization ELK/CloudWatch** avec dashboards
- **Alerting temps réel** sur erreurs critiques
- **Debugging facilité** avec search/filter avancé
- **Structured queries** avec KQL/CloudWatch Insights

## 🏗 Architecture de Logging

```
                              AccessWeaver Services
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │API Gateway  │ │PDP Service  │ │PAP Service  │ │Tenant Svc   │           │
│  │             │ │             │ │             │ │             │           │
│  │ Logback+    │ │ Logback+    │ │ Logback+    │ │ Logback+    │           │
│  │ JSON Encoder│ │ JSON Encoder│ │ JSON Encoder│ │ JSON Encoder│           │
│  │             │ │             │ │             │ │             │           │
│  │ - Auth logs │ │ - Decision  │ │ - Policy    │ │ - Tenant    │           │
│  │ - API calls │ │   logs      │ │   changes   │ │   operations│           │
│  │ - Errors    │ │ - Performance│ │ - CRUD ops  │ │ - Billing   │           │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘           │
│         │               │               │               │                   │
└─────────┼───────────────┼───────────────┼───────────────┼───────────────────┘
          │               │               │               │
          ▼               ▼               ▼               ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Log Aggregation                                   │
│                                                                             │
│  ┌─────────────────────┐          ┌─────────────────────┐                  │
│  │   CloudWatch Logs   │          │    ELK Stack        │                  │
│  │                     │          │  (Optional)         │                  │
│  │ - Real-time streams │◄────────►│ - Elasticsearch     │                  │
│  │ - 14-90 days        │          │ - Logstash          │                  │
│  │ - Insights queries  │          │ - Kibana            │                  │
│  │ - Metric filters    │          │ - 1+ year retention │                  │
│  └─────────────────────┘          └─────────────────────┘                  │
│         │                                   │                              │
│         ▼                                   ▼                              │
│  ┌─────────────────────┐          ┌─────────────────────┐                  │
│  │   S3 Archive        │          │   Alerting          │                  │
│  │                     │          │                     │                  │
│  │ - Long-term storage │          │ - SNS/Slack/Email   │                  │
│  │ - Glacier/Deep      │          │ - PagerDuty         │                  │
│  │ - GDPR compliance   │          │ - Custom webhooks   │                  │
│  └─────────────────────┘          └─────────────────────┘                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 📋 Niveaux de Log & Classification

### **TRACE** (Dev uniquement)
```json
{
  "timestamp": "2024-12-16T10:30:00.123Z",
  "level": "TRACE",
  "logger": "com.accessweaver.pdp.PolicyEvaluator",
  "message": "Evaluating OPA policy for permission check",
  "tenantId": "tenant-123",
  "traceId": "abc123def456",
  "spanId": "span789",
  "thread": "http-nio-8081-exec-1",
  "method": "evaluatePolicy",
  "duration": 2.3,
  "policyId": "policy-456",
  "resource": "document:123",
  "action": "read"
}
```

### **DEBUG** (Dev/Staging)
```json
{
  "timestamp": "2024-12-16T10:30:00.123Z",
  "level": "DEBUG",
  "logger": "com.accessweaver.gateway.AuthFilter",
  "message": "JWT token validated successfully",
  "tenantId": "tenant-123",
  "traceId": "abc123def456",
  "userId": "user-789",
  "sessionId": "session-456",
  "userAgent": "Mozilla/5.0...",
  "clientIp": "203.0.113.***", // IP anonymisée pour RGPD
  "authMethod": "jwt",
  "scopes": ["read:documents", "write:policies"]
}
```

### **INFO** (Tous environnements)
```json
{
  "timestamp": "2024-12-16T10:30:00.123Z",
  "level": "INFO",
  "logger": "com.accessweaver.audit.AuditService",
  "message": "Authorization decision recorded",
  "tenantId": "tenant-123",
  "traceId": "abc123def456",
  "eventType": "AUTHORIZATION_DECISION",
  "userId": "user-789",
  "resource": "document:123",
  "action": "read",
  "decision": "ALLOW",
  "policyId": "policy-456",
  "duration": 15.2,
  "compliance": {
    "gdpr": true,
    "retention": "5_YEARS"
  }
}
```

### **WARN** (Surveillance)
```json
{
  "timestamp": "2024-12-16T10:30:00.123Z",
  "level": "WARN",
  "logger": "com.accessweaver.security.RateLimiter",
  "message": "Rate limit approaching threshold",
  "tenantId": "tenant-123",
  "traceId": "abc123def456",
  "userId": "user-789",
  "clientIp": "203.0.113.***",
  "currentRate": 450,
  "maxRate": 500,
  "windowMinutes": 5,
  "alertType": "RATE_LIMIT_WARNING",
  "severity": "medium"
}
```

### **ERROR** (Alerting immédiat)
```json
{
  "timestamp": "2024-12-16T10:30:00.123Z",
  "level": "ERROR",
  "logger": "com.accessweaver.pdp.PolicyDecisionPoint",
  "message": "Failed to evaluate authorization policy",
  "tenantId": "tenant-123",
  "traceId": "abc123def456",
  "userId": "user-789",
  "exception": {
    "class": "com.accessweaver.exception.PolicyEvaluationException",
    "message": "OPA engine timeout",
    "stackTrace": "com.accessweaver.exception.PolicyEvaluationException: OPA engine timeout\n\tat com.accessweaver...",
    "cause": "java.util.concurrent.TimeoutException"
  },
  "resource": "document:123",
  "action": "read",
  "policyId": "policy-456",
  "impact": "USER_DENIED_ACCESS",
  "recovery": "FALLBACK_TO_DEFAULT_DENY",
  "alertRequired": true
}
```

## 🔧 Configuration Logback par Service

### **API Gateway - logback-spring.xml**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <!-- Configuration pour environnement -->
    <springProfile name="dev">
        <property name="LOG_LEVEL" value="DEBUG"/>
        <property name="LOG_PATTERN" value="%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"/>
    </springProfile>
    
    <springProfile name="staging,prod">
        <property name="LOG_LEVEL" value="INFO"/>
        <property name="LOG_PATTERN" value="STRUCTURED_JSON"/>
    </springProfile>

    <!-- Console Appender (dev uniquement) -->
    <springProfile name="dev">
        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder>
                <pattern>${LOG_PATTERN}</pattern>
            </encoder>
        </appender>
    </springProfile>

    <!-- JSON Appender pour CloudWatch -->
    <springProfile name="staging,prod">
        <appender name="JSON_CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder class="net.logstash.logback.encoder.LoggingEventCompositeJsonEncoder">
                <providers>
                    <timestamp>
                        <timeZone>UTC</timeZone>
                        <pattern>yyyy-MM-dd'T'HH:mm:ss.SSSXXX</pattern>
                    </timestamp>
                    <logLevel/>
                    <loggerName/>
                    <message/>
                    <mdc/>
                    <pattern>
                        <pattern>
                            {
                                "service": "aw-api-gateway",
                                "version": "${app.version:-unknown}",
                                "environment": "${spring.profiles.active}",
                                "host": "${HOSTNAME:-unknown}",
                                "pod": "${POD_NAME:-unknown}"
                            }
                        </pattern>
                    </pattern>
                    <stackTrace/>
                </providers>
            </encoder>
        </appender>
    </springProfile>

    <!-- Appender pour logs de sécurité -->
    <appender name="SECURITY_LOG" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>logs/security.log</file>
        <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
            <fileNamePattern>logs/security.%d{yyyy-MM-dd}.%i.gz</fileNamePattern>
            <maxFileSize>100MB</maxFileSize>
            <maxHistory>90</maxHistory>
            <totalSizeCap>5GB</totalSizeCap>
        </rollingPolicy>
        <encoder class="net.logstash.logback.encoder.LoggingEventCompositeJsonEncoder">
            <!-- Configuration identique au JSON_CONSOLE -->
        </encoder>
    </appender>

    <!-- Appender pour audit trail -->
    <appender name="AUDIT_LOG" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>logs/audit.log</file>
        <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
            <fileNamePattern>logs/audit.%d{yyyy-MM-dd}.%i.gz</fileNamePattern>
            <maxFileSize>500MB</maxFileSize>
            <maxHistory>2555</maxHistory> <!-- 7 ans pour compliance -->
            <totalSizeCap>50GB</totalSizeCap>
        </rollingPolicy>
        <encoder class="net.logstash.logback.encoder.LoggingEventCompositeJsonEncoder">
            <!-- Configuration avec signature HMAC pour immutabilité -->
        </encoder>
    </appender>

    <!-- Async Appenders pour performance -->
    <appender name="ASYNC_JSON" class="ch.qos.logback.classic.AsyncAppender">
        <appender-ref ref="JSON_CONSOLE"/>
        <queueSize>1024</queueSize>
        <discardingThreshold>0</discardingThreshold>
        <includeCallerData>false</includeCallerData>
        <neverBlock>true</neverBlock>
    </appender>

    <!-- Loggers spécialisés -->
    
    <!-- Logger sécurité -->
    <logger name="SECURITY" level="INFO" additivity="false">
        <appender-ref ref="SECURITY_LOG"/>
        <appender-ref ref="ASYNC_JSON"/>
    </logger>

    <!-- Logger audit -->
    <logger name="AUDIT" level="INFO" additivity="false">
        <appender-ref ref="AUDIT_LOG"/>
        <appender-ref ref="ASYNC_JSON"/>
    </logger>

    <!-- Logger performance -->
    <logger name="PERFORMANCE" level="INFO" additivity="false">
        <appender-ref ref="ASYNC_JSON"/>
    </logger>

    <!-- Réduction du bruit des frameworks -->
    <logger name="org.springframework" level="WARN"/>
    <logger name="org.hibernate" level="WARN"/>
    <logger name="com.netflix" level="WARN"/>
    <logger name="reactor.netty" level="WARN"/>

    <!-- Logger racine -->
    <root level="${LOG_LEVEL}">
        <springProfile name="dev">
            <appender-ref ref="CONSOLE"/>
        </springProfile>
        <springProfile name="staging,prod">
            <appender-ref ref="ASYNC_JSON"/>
        </springProfile>
    </root>
</configuration>
```

### **PDP Service - Configuration spécialisée**

```xml
<!-- Configuration similaire mais avec loggers spécifiques OPA -->
<logger name="com.accessweaver.pdp.opa" level="DEBUG" additivity="false">
    <appender-ref ref="ASYNC_JSON"/>
</logger>

<logger name="POLICY_EVALUATION" level="INFO" additivity="false">
    <appender-ref ref="AUDIT_LOG"/>
    <appender-ref ref="ASYNC_JSON"/>
</logger>

<!-- Logger pour les décisions lentes -->
<logger name="SLOW_DECISIONS" level="WARN" additivity="false">
    <appender-ref ref="ASYNC_JSON"/>
</logger>
```

## 📝 Logging Components Java

### **Centralized Logger Configuration**

```java
@Component
@Slf4j
public class AccessWeaverLogger {
    
    // Loggers spécialisés
    private static final Logger SECURITY_LOGGER = LoggerFactory.getLogger("SECURITY");
    private static final Logger AUDIT_LOGGER = LoggerFactory.getLogger("AUDIT");
    private static final Logger PERFORMANCE_LOGGER = LoggerFactory.getLogger("PERFORMANCE");
    private static final Logger POLICY_EVALUATION_LOGGER = LoggerFactory.getLogger("POLICY_EVALUATION");
    
    /**
     * Log d'authentification (succès ou échec)
     */
    public void logAuthentication(String tenantId, String userId, boolean success, 
                                String authMethod, String clientIp, String userAgent) {
        MDC.put("tenantId", tenantId);
        MDC.put("userId", userId);
        MDC.put("clientIp", anonymizeIp(clientIp));
        MDC.put("authMethod", authMethod);
        MDC.put("userAgent", truncateUserAgent(userAgent));
        
        if (success) {
            SECURITY_LOGGER.info("Authentication successful");
        } else {
            SECURITY_LOGGER.warn("Authentication failed");
        }
        
        clearMDC();
    }
    
    /**
     * Log de décision d'autorisation (audit trail obligatoire)
     */
    public void logAuthorizationDecision(String tenantId, String userId, String resource, 
                                       String action, String decision, String policyId, 
                                       long durationMs) {
        MDC.put("tenantId", tenantId);
        MDC.put("userId", userId);
        MDC.put("resource", resource);
        MDC.put("action", action);
        MDC.put("decision", decision);
        MDC.put("policyId", policyId);
        MDC.put("duration", String.valueOf(durationMs));
        MDC.put("eventType", "AUTHORIZATION_DECISION");
        
        AUDIT_LOGGER.info("Authorization decision recorded");
        
        // Log performance si décision lente
        if (durationMs > 100) { // > 100ms
            PERFORMANCE_LOGGER.warn("Slow authorization decision detected");
        }
        
        clearMDC();
    }
    
    /**
     * Log d'erreur avec context complet
     */
    public void logError(String tenantId, String component, String operation, 
                        Throwable exception, Map<String, Object> context) {
        MDC.put("tenantId", tenantId);
        MDC.put("component", component);
        MDC.put("operation", operation);
        MDC.put("errorClass", exception.getClass().getSimpleName());
        MDC.put("errorMessage", exception.getMessage());
        
        // Ajouter le context personnalisé
        context.forEach((key, value) -> MDC.put(key, String.valueOf(value)));
        
        log.error("Operation failed: {}", operation, exception);
        
        clearMDC();
    }
    
    /**
     * Log de modification de policy (audit critique)
     */
    public void logPolicyChange(String tenantId, String userId, String policyId, 
                              String operation, Object oldValue, Object newValue) {
        MDC.put("tenantId", tenantId);
        MDC.put("userId", userId);
        MDC.put("policyId", policyId);
        MDC.put("operation", operation);
        MDC.put("eventType", "POLICY_CHANGE");
        
        // Sérialisation sécurisée des valeurs (sans données sensibles)
        if (oldValue != null) {
            MDC.put("oldValue", sanitizeForLogging(oldValue));
        }
        if (newValue != null) {
            MDC.put("newValue", sanitizeForLogging(newValue));
        }
        
        AUDIT_LOGGER.info("Policy modified");
        
        clearMDC();
    }
    
    /**
     * Log de tentative d'accès suspect (sécurité)
     */
    public void logSuspiciousActivity(String tenantId, String userId, String activityType, 
                                    String details, String clientIp) {
        MDC.put("tenantId", tenantId);
        MDC.put("userId", userId);
        MDC.put("activityType", activityType);
        MDC.put("details", details);
        MDC.put("clientIp", anonymizeIp(clientIp));
        MDC.put("alertRequired", "true");
        MDC.put("severity", "high");
        
        SECURITY_LOGGER.warn("Suspicious activity detected");
        
        clearMDC();
    }
    
    // Utilitaires RGPD
    private String anonymizeIp(String ip) {
        if (ip == null) return null;
        // 203.0.113.45 → 203.0.113.***
        int lastDot = ip.lastIndexOf('.');
        return lastDot > 0 ? ip.substring(0, lastDot) + ".***" : ip;
    }
    
    private String truncateUserAgent(String userAgent) {
        return userAgent != null && userAgent.length() > 200 ? 
               userAgent.substring(0, 200) + "..." : userAgent;
    }
    
    private String sanitizeForLogging(Object obj) {
        // Supprime/masque les données sensibles avant logging
        String json = JsonUtils.toJson(obj);
        return json.replaceAll("\"password\"\\s*:\\s*\"[^\"]*\"", "\"password\":\"***\"")
                  .replaceAll("\"token\"\\s*:\\s*\"[^\"]*\"", "\"token\":\"***\"")
                  .replaceAll("\"secret\"\\s*:\\s*\"[^\"]*\"", "\"secret\":\"***\"");
    }
    
    private void clearMDC() {
        MDC.clear();
    }
}
```

### **Correlation ID Filter**

```java
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class CorrelationIdFilter implements Filter {
    
    private static final String CORRELATION_ID_HEADER = "X-Correlation-ID";
    private static final String TRACE_ID_HEADER = "X-Trace-ID";
    
    @Override
    public void doFilter(ServletRequest request, ServletResponse response, 
                        FilterChain chain) throws IOException, ServletException {
        
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        HttpServletResponse httpResponse = (HttpServletResponse) response;
        
        // Récupérer ou générer correlation ID
        String correlationId = httpRequest.getHeader(CORRELATION_ID_HEADER);
        if (correlationId == null || correlationId.trim().isEmpty()) {
            correlationId = UUID.randomUUID().toString();
        }
        
        // Générer trace ID unique pour cette requête
        String traceId = generateTraceId();
        
        // Stocker dans MDC pour tous les logs de cette requête
        MDC.put("correlationId", correlationId);
        MDC.put("traceId", traceId);
        
        // Ajouter aux headers de réponse
        httpResponse.setHeader(CORRELATION_ID_HEADER, correlationId);
        httpResponse.setHeader(TRACE_ID_HEADER, traceId);
        
        try {
            chain.doFilter(request, response);
        } finally {
            // Nettoyage MDC
            MDC.remove("correlationId");
            MDC.remove("traceId");
        }
    }
    
    private String generateTraceId() {
        return System.currentTimeMillis() + "-" + 
               ThreadLocalRandom.current().nextInt(1000, 9999);
    }
}
```

### **Tenant Context Filter**

```java
@Component
@Order(2)
public class TenantContextFilter implements Filter {
    
    @Autowired
    private TenantExtractor tenantExtractor;
    
    @Override
    public void doFilter(ServletRequest request, ServletResponse response, 
                        FilterChain chain) throws IOException, ServletException {
        
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        
        try {
            // Extraire tenant ID depuis JWT ou header
            String tenantId = tenantExtractor.extractTenant(httpRequest);
            
            if (tenantId != null) {
                // Stocker dans MDC pour tous les logs
                MDC.put("tenantId", tenantId);
                
                // Stocker dans ThreadLocal pour accès business
                TenantContext.setCurrentTenant(tenantId);
            }
            
            chain.doFilter(request, response);
            
        } finally {
            // Nettoyage systématique
            MDC.remove("tenantId");
            TenantContext.clear();
        }
    }
}
```

## 📈 Rétention et Archivage

### **Stratégie par Type de Log**

| Type de Log | Dev | Staging | Production | Archive S3 | Compliance |
|-------------|-----|---------|------------|------------|------------|
| **Application** | 7 jours | 14 jours | 30 jours | 1 an | Standard |
| **Sécurité** | 7 jours | 30 jours | 90 jours | 7 ans | RGPD |
| **Audit** | 14 jours | 90 jours | 365 jours | 7 ans | SOX/GDPR |
| **Performance** | 3 jours | 7 jours | 30 jours | 6 mois | Monitoring |
| **Debug** | 1 jour | 3 jours | ❌ | ❌ | None |
| **Error** | 14 jours | 30 jours | 90 jours | 2 ans | Support |

### **Configuration CloudWatch Log Groups**

```hcl
# Terraform configuration pour les log groups
resource "aws_cloudwatch_log_group" "application_logs" {
  for_each = toset([
    "aw-api-gateway",
    "aw-pdp-service", 
    "aw-pap-service",
    "aw-tenant-service",
    "aw-audit-service"
  ])
  
  name              = "/ecs/accessweaver-${var.environment}/${each.value}"
  retention_in_days = var.environment == "prod" ? 30 : (var.environment == "staging" ? 14 : 7)
  
  tags = {
    Environment = var.environment
    Service     = each.value
    LogType     = "application"
  }
}

resource "aws_cloudwatch_log_group" "audit_logs" {
  name              = "/ecs/accessweaver-${var.environment}/audit"
  retention_in_days = var.environment == "prod" ? 365 : (var.environment == "staging" ? 90 : 14)
  
  tags = {
    Environment = var.environment
    LogType     = "audit"
    Compliance  = "GDPR"
  }
}

resource "aws_cloudwatch_log_group" "security_logs" {
  name              = "/ecs/accessweaver-${var.environment}/security"
  retention_in_days = var.environment == "prod" ? 90 : (var.environment == "staging" ? 30 : 7)
  
  tags = {
    Environment = var.environment
    LogType     = "security"
    Compliance  = "GDPR"
  }
}
```

### **Archivage S3 avec Lifecycle**

```hcl
resource "aws_s3_bucket" "log_archive" {
  bucket = "accessweaver-${var.environment}-log-archive"
  
  tags = {
    Purpose = "log-archive"
    Compliance = "GDPR"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id
  
  rule {
    id     = "audit_logs_lifecycle"
    status = "Enabled"
    
    filter {
      prefix = "audit/"
    }
    
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
    
    transition {
      days          = 365
      storage_class = "GLACIER"
    }
    
    transition {
      days          = 2555  # 7 ans
      storage_class = "DEEP_ARCHIVE"
    }
    
    expiration {
      days = 2555  # Suppression après 7 ans (compliance GDPR)
    }
  }
  
  rule {
    id     = "application_logs_lifecycle"
    status = "Enabled"
    
    filter {
      prefix = "application/"
    }
    
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    expiration {
      days = 365  # 1 an
    }
  }
}
```

## 🚨 Alerting sur Logs

### **Metric Filters CloudWatch**

```hcl
# Alerte sur erreurs 5xx
resource "aws_cloudwatch_log_metric_filter" "error_5xx" {
  name           = "accessweaver-${var.environment}-error-5xx"
  log_group_name = aws_cloudwatch_log_group.application_logs["aw-api-gateway"].name
  pattern        = "[timestamp, requestId, level=\"ERROR\", logger, message]"
  
  metric_transformation {
    name      = "ErrorCount5xx"
    namespace = "AccessWeaver/${var.environment}/Logs"
    value     = "1"
    
    default_value = "0"
  }
}

# Alerte sur tentatives d'authentification échouées
resource "aws_cloudwatch_log_metric_filter" "failed_auth" {
  name           = "accessweaver-${var.environment}-failed-auth"
  log_group_name = aws_cloudwatch_log_group.security_logs.name
  pattern        = "[timestamp, level=\"WARN\", logger=\"SECURITY\", message=\"Authentication failed\"]"
  
  metric_transformation {
    name      = "FailedAuthCount"
    namespace = "AccessWeaver/${var.environment}/Security"
    value     = "1"
  }
}

# Alerte sur décisions d'autorisation lentes
resource "aws_cloudwatch_log_metric_filter" "slow_decisions" {
  name           = "accessweaver-${var.environment}-slow-decisions"
  log_group_name = aws_cloudwatch_log_group.application_logs["aw-pdp-service"].name
  pattern        = "[timestamp, level=\"WARN\", logger=\"PERFORMANCE\", message=\"Slow authorization decision detected\"]"
  
  metric_transformation {
    name      = "SlowDecisionCount"
    namespace = "AccessWeaver/${var.environment}/Performance"
    value     = "1"
  }
}
```

### **CloudWatch Alarms**

```hcl
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "accessweaver-${var.environment}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ErrorCount5xx"
  namespace           = "AccessWeaver/${var.environment}/Logs"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.environment == "prod" ? "10" : "20"
  alarm_description   = "High error rate detected in application logs"
  
  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]
  
  treat_missing_data = "notBreaching"
  
  tags = {
    Environment = var.environment
    AlertType   = "application"
    Severity    = "high"
  }
}

resource "aws_cloudwatch_metric_alarm" "failed_auth_attacks" {
  alarm_name          = "accessweaver-${var.environment}-failed-auth-spike"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailedAuthCount"
  namespace           = "AccessWeaver/${var.environment}/Security"
  period              = "300"  # 5 minutes
  statistic           = "Sum"
  threshold           = "50"   # Plus de 50 échecs en 5min = attaque potentielle
  alarm_description   = "Potential brute force attack detected"
  
  alarm_actions = [
    aws_sns_topic.security_alerts.arn
  ]
  
  treat_missing_data = "notBreaching"
  
  tags = {
    Environment = var.environment
    AlertType   = "security"
    Severity    = "critical"
  }
}

resource "aws_cloudwatch_metric_alarm" "performance_degradation" {
  alarm_name          = "accessweaver-${var.environment}-slow-decisions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "SlowDecisionCount"
  namespace           = "AccessWeaver/${var.environment}/Performance"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"   # Plus de 10 décisions lentes en 5min
  alarm_description   = "Authorization decisions are consistently slow"
  
  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]
  
  tags = {
    Environment = var.environment
    AlertType   = "performance"
    Severity    = "medium"
  }
}
```

## 💰 Optimisation des Coûts de Logging

### **Estimation des Coûts par Environnement**

| Composant | Dev | Staging | Production |
|-----------|-----|---------|------------|
| **CloudWatch Ingestion** | $5/mois | $25/mois | $100/mois |
| **CloudWatch Storage** | $2/mois | $10/mois | $50/mois |
| **S3 Archive** | $1/mois | $5/mois | $20/mois |
| **Data Transfer** | $1/mois | $3/mois | $10/mois |
| **Total** | **~$9/mois** | **~$43/mois** | **~$180/mois** |

### **Stratégies d'Optimisation**

```java
@Component
@ConditionalOnProperty(name = "logging.cost-optimization.enabled", havingValue = "true")
public class LoggingCostOptimizer {
    
    @Value("${logging.sampling.rate:1.0}")
    private double samplingRate;
    
    @Value("${logging.debug.enabled:false}")
    private boolean debugEnabled;
    
    /**
     * Sampling adaptatif pour logs DEBUG/TRACE
     */
    public boolean shouldLog(Level level, String logger) {
        // Toujours logger ERROR/WARN
        if (level.isGreaterOrEqual(Level.WARN)) {
            return true;
        }
        
        // DEBUG/TRACE uniquement si activé et selon sampling
        if (level == Level.DEBUG && !debugEnabled) {
            return false;
        }
        
        // Sampling plus agressif pour certains loggers verbeux
        if (logger.contains("org.springframework") || logger.contains("org.hibernate")) {
            return ThreadLocalRandom.current().nextDouble() < (samplingRate * 0.1);
        }
        
        return ThreadLocalRandom.current().nextDouble() < samplingRate;
    }
    
    /**
     * Compression intelligente des stacktraces
     */
    public String compressStackTrace(Throwable throwable) {
        StringWriter sw = new StringWriter();
        PrintWriter pw = new PrintWriter(sw);
        throwable.printStackTrace(pw);
        
        String fullTrace = sw.toString();
        
        // Garder seulement les lignes AccessWeaver + cause root
        return Arrays.stream(fullTrace.split("\n"))
                .filter(line -> 
                    line.contains("com.accessweaver") || 
                    line.contains("Caused by:") ||
                    line.contains("at java.base"))
                .limit(20) // Max 20 lignes
                .collect(Collectors.joining("\n"));
    }
}
```

### **Configuration de Production Cost-Aware**

```yaml
# application-prod.yml
logging:
  cost-optimization:
    enabled: true
  sampling:
    rate: 0.1  # 10% des logs DEBUG seulement
  debug:
    enabled: false
  compression:
    enabled: true
    max-message-length: 1000
  
# Configuration par logger
logging:
  level:
    com.accessweaver: INFO
    com.accessweaver.audit: INFO    # Toujours complet pour compliance
    com.accessweaver.security: INFO # Toujours complet pour sécurité
    org.springframework: WARN
    org.hibernate: WARN
    org.hibernate.SQL: ERROR        # Pas de logs SQL en prod
    
# Async appenders optimisés
logback:
  async:
    queue-size: 2048
    discarding-threshold: 0
    include-caller-data: false      # Économise CPU/mémoire
    never-block: true
```

## 🔍 Requêtes et Dashboards

### **CloudWatch Insights Queries**

```sql
-- Top erreurs par service
fields @timestamp, service, level, message, tenantId
| filter level = "ERROR"
| stats count() by service, message
| sort count desc
| limit 20

-- Analyse des décisions d'autorisation lentes
fields @timestamp, tenantId, userId, resource, action, duration
| filter logger = "POLICY_EVALUATION" and duration > 100
| stats avg(duration), max(duration), count() by tenantId
| sort avg desc

-- Détection d'anomalies de sécurité
fields @timestamp, tenantId, userId, clientIp, activityType
| filter logger = "SECURITY" and level = "WARN"
| stats count() by clientIp, activityType
| sort count desc
| limit 50

-- Audit trail pour un utilisateur spécifique
fields @timestamp, eventType, resource, action, decision
| filter tenantId = "tenant-123" and userId = "user-456"
| filter logger = "AUDIT"
| sort @timestamp desc
| limit 100

-- Performance globale par tenant
fields @timestamp, tenantId, duration
| filter logger = "PERFORMANCE"
| stats avg(duration), p95(duration), p99(duration) by tenantId
| sort avg desc

-- Corrélation cross-services avec traceId
fields @timestamp, service, traceId, level, message
| filter traceId = "abc123def456"
| sort @timestamp asc
```

### **Dashboard Kibana/ELK**

```json
{
  "dashboard": {
    "title": "AccessWeaver - Security & Audit Dashboard",
    "panels": [
      {
        "title": "Authentication Success Rate",
        "type": "line",
        "query": {
          "query": "logger:SECURITY AND message:\"Authentication*\"",
          "timeField": "@timestamp"
        },
        "aggregations": {
          "date_histogram": {
            "field": "@timestamp",
            "interval": "5m"
          },
          "terms": {
            "field": "message.keyword",
            "size": 2
          }
        }
      },
      {
        "title": "Top Failed Resources",
        "type": "table",
        "query": {
          "query": "eventType:AUTHORIZATION_DECISION AND decision:DENY",
          "timeField": "@timestamp"
        },
        "aggregations": {
          "terms": {
            "field": "resource.keyword",
            "size": 10
          }
        }
      },
      {
        "title": "Geographic Distribution",
        "type": "map",
        "query": {
          "query": "clientIp:*",
          "timeField": "@timestamp"
        },
        "geo_field": "geoip.location"
      }
    ]
  }
}
```

## 🔒 Sécurité et Compliance RGPD

### **Anonymisation Automatique**

```java
@Component
public class GDPRLogProcessor {
    
    private static final Pattern EMAIL_PATTERN = 
        Pattern.compile("\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b");
    
    private static final Pattern IP_PATTERN = 
        Pattern.compile("\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b");
    
    private static final Pattern PHONE_PATTERN = 
        Pattern.compile("\\b(?:\\+33|0)[1-9](?:[0-9]{8})\\b");
    
    /**
     * Anonymise les données personnelles dans les logs
     */
    public String anonymizeMessage(String message) {
        if (message == null) return null;
        
        return message
            .replaceAll(EMAIL_PATTERN.pattern(), "user@***.***")
            .replaceAll(IP_PATTERN.pattern(), this::maskIp)
            .replaceAll(PHONE_PATTERN.pattern(), "+33*********")
            .replaceAll("(?i)password[\"']?\\s*[:=]\\s*[\"']?[^\\s,}]+", "password\":\"***\"")
            .replaceAll("(?i)token[\"']?\\s*[:=]\\s*[\"']?[^\\s,}]+", "token\":\"***\"");
    }
    
    private String maskIp(String ip) {
        int lastDot = ip.lastIndexOf('.');
        return lastDot > 0 ? ip.substring(0, lastDot) + ".***" : ip;
    }
    
    /**
     * Vérifie si un log contient des données personnelles
     */
    public boolean containsPII(String message) {
        return EMAIL_PATTERN.matcher(message).find() ||
               PHONE_PATTERN.matcher(message).find() ||
               message.toLowerCase().contains("password") ||
               message.toLowerCase().contains("secret");
    }
}
```

### **Signature des Logs d'Audit**

```java
@Component
public class AuditLogSigner {
    
    @Value("${audit.signing.secret}")
    private String signingSecret;
    
    private final Mac hmac;
    
    public AuditLogSigner() throws NoSuchAlgorithmException, InvalidKeyException {
        this.hmac = Mac.getInstance("HmacSHA256");
        SecretKeySpec secretKey = new SecretKeySpec(
            signingSecret.getBytes(StandardCharsets.UTF_8), 
            "HmacSHA256"
        );
        this.hmac.init(secretKey);
    }
    
    /**
     * Signe un log d'audit pour garantir l'intégrité
     */
    public String signAuditLog(String logContent) {
        byte[] signature = hmac.doFinal(logContent.getBytes(StandardCharsets.UTF_8));
        return Base64.getEncoder().encodeToString(signature);
    }
    
    /**
     * Vérifie la signature d'un log
     */
    public boolean verifyAuditLog(String logContent, String signature) {
        String expectedSignature = signAuditLog(logContent);
        return MessageDigest.isEqual(
            expectedSignature.getBytes(StandardCharsets.UTF_8),
            signature.getBytes(StandardCharsets.UTF_8)
        );
    }
}
```

## 📱 Monitoring et Alerting en Temps Réel

### **Custom Log Appender pour Alerting**

```java
public class SlackAlertAppender extends AppenderBase<ILoggingEvent> {
    
    private String webhookUrl;
    private String environment;
    private Level minimumLevel = Level.ERROR;
    
    @Override
    protected void append(ILoggingEvent event) {
        if (!event.getLevel().isGreaterOrEqual(minimumLevel)) {
            return;
        }
        
        // Éviter le spam - throttling basique
        String key = event.getLoggerName() + ":" + event.getMessage();
        if (shouldThrottle(key)) {
            return;
        }
        
        SlackMessage message = buildSlackMessage(event);
        sendToSlack(message);
    }
    
    private SlackMessage buildSlackMessage(ILoggingEvent event) {
        String tenantId = event.getMDCPropertyMap().get("tenantId");
        String traceId = event.getMDCPropertyMap().get("traceId");
        
        return SlackMessage.builder()
            .text("🚨 AccessWeaver Alert")
            .attachments(List.of(
                SlackAttachment.builder()
                    .color(getColorForLevel(event.getLevel()))
                    .title(String.format("[%s] %s", environment.toUpperCase(), event.getLevel()))
                    .text(event.getFormattedMessage())
                    .fields(List.of(
                        SlackField.builder().title("Service").value(event.getLoggerName()).shortField(true).build(),
                        SlackField.builder().title("Tenant").value(tenantId).shortField(true).build(),
                        SlackField.builder().title("Trace").value(traceId).shortField(true).build(),
                        SlackField.builder().title("Time").value(formatTimestamp(event.getTimeStamp())).shortField(true).build()
                    ))
                    .build()
            ))
            .build();
    }
    
    private void sendToSlack(SlackMessage message) {
        // Envoi asynchrone pour ne pas bloquer l'application
        CompletableFuture.runAsync(() -> {
            try {
                HttpClient client = HttpClient.newHttpClient();
                HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(webhookUrl))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(JsonUtils.toJson(message)))
                    .build();
                    
                client.send(request, HttpResponse.BodyHandlers.ofString());
            } catch (Exception e) {
                // Fallback : logger l'erreur sans créer de boucle
                System.err.println("Failed to send Slack alert: " + e.getMessage());
            }
        });
    }
}
```

## 🎯 Actions Recommandées

### **Phase 1 : Configuration de Base (Semaine 1)**
1. ✅ **Implémenter les loggers Java** avec MDC et correlation IDs
2. ✅ **Configurer Logback** avec JSON encoder pour chaque service
3. ✅ **Setup CloudWatch Log Groups** avec retention appropriée
4. ✅ **Créer les metric filters** pour alerting de base

### **Phase 2 : Sécurité et Compliance (Semaine 2)**
1. ✅ **Implémenter l'anonymisation RGPD** automatique
2. ✅ **Setup audit trail** avec signature des logs
3. ✅ **Configurer les alertes sécurité** (failed auth, suspicious activity)
4. ✅ **Tests de compliance** et validation RGPD

### **Phase 3 : Optimisation et Monitoring (Semaine 3)**
1. ✅ **Optimiser les coûts** avec sampling et compression
2. ✅ **Créer les dashboards** CloudWatch Insights
3. ✅ **Setup ELK** optionnel pour analyse avancée
4. ✅ **Formation équipe** sur les outils de monitoring

### **Phase 4 : Automation et Maintenance (Semaine 4)**
1. ✅ **Automatiser l'archivage** S3 avec lifecycle
2. ✅ **Setup alerting avancé** avec Slack/PagerDuty
3. ✅ **Monitoring des coûts** et budgets CloudWatch
4. ✅ **Documentation** et runbooks opérationnels

## 📋 Checklist de Validation

### **Fonctionnel**
- [ ] Tous les logs sont en JSON structuré
- [ ] Correlation IDs propagés cross-services
- [ ] Context tenant automatique dans tous les logs
- [ ] Audit trail complet pour decisions d'autorisation
- [ ] Anonymisation RGPD fonctionnelle

### **Performance**
- [ ] Impact CPU < 1% avec async appenders
- [ ] Latence ajoutée < 1ms par requête
- [ ] Sampling efficace en production
- [ ] Pas de blocking sur I/O logging

### **Sécurité**
- [ ] Logs d'audit signés et immutables
- [ ] Données sensibles anonymisées
- [ ] Alertes temps réel sur attaques
- [ ] Accès logs restreints (RBAC)

### **Coûts**
- [ ] Budgets CloudWatch configurés
- [ ] Alertes dépassement de coût
- [ ] Archivage S3 avec lifecycle
- [ ] Coûts < objectifs par environnement

### **Compliance**
- [ ] Retention RGPD respectée (7 ans audit)
- [ ] Anonymisation données personnelles
- [ ] Audit trail intègre et complet
- [ ] Documentation conformité validée

---

**🚀 Prochaines étapes :**
1. **Implémenter les composants Java** (AccessWeaverLogger, Filters)
2. **Configurer CloudWatch Log Groups** avec Terraform
3. **Setup les metric filters** et alerting de base
4. **Tester l'anonymisation RGPD** et audit trail

**💡 Points d'attention :**
- **Coûts CloudWatch** peuvent exploser rapidement (monitoring continu)
- **Performance impact** à mesurer avec load testing
- **RGPD compliance** critique pour le marché français
- **Corrélation cross-services** essentielle pour debugging

Cette stratégie de logging positionne AccessWeaver comme une solution enterprise avec observabilité de classe mondiale et compliance RGPD native.