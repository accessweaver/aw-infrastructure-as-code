# 📈 Stratégie des Métriques - AccessWeaver

Stratégie complète de métriques pour AccessWeaver - Système d'autorisation enterprise avec monitoring business et technique.

---

## 🎯 Philosophy des Métriques

### Approche "Golden Signals + Business"
```
🔥 Golden Signals (SRE)
├── 📊 Latency (temps de réponse)
├── 🌊 Traffic (débit de requêtes)  
├── ❌ Errors (taux d'erreur)
└── 🏃 Saturation (utilisation ressources)

💼 Business Metrics (AccessWeaver)
├── 🔐 Authorization rates (autorisations/refus)
├── 👥 Tenant activity (usage par tenant)
├── 📝 Policy management (changements de règles)
└── 💰 Revenue impact (usage facturable)
```

### Hiérarchie des Métriques
1. **🚨 Critical** : Impact direct sur la disponibilité
2. **🔶 Important** : Impact sur les performances utilisateur
3. **📊 Useful** : Aide à l'optimisation et debugging
4. **💼 Business** : KPIs produit et revenue

---

## 🏗 Architecture des Métriques

### Stack Technique
```
┌─────────────────────────────────────────────────────────┐
│                   Applications                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│  │API Gateway  │ │PDP Service  │ │PAP Service  │       │
│  │             │ │             │ │             │       │
│  │• HTTP req   │ │• Auth checks│ │• Policy ops │       │
│  │• JWT ops    │ │• Cache hits │ │• Admin ops  │       │
│  │• Rate limit │ │• DB queries │ │• Bulk ops   │       │
│  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘       │
│         │               │               │               │
└─────────┼───────────────┼───────────────┼───────────────┘
          │               │               │
    ┌─────▼───────────────▼───────────────▼─────┐
    │           Micrometer Registry             │
    │                                           │
    │  ┌─────────────┐ ┌─────────────┐         │
    │  │   Timers    │ │  Counters   │         │
    │  │• Latency    │ │• Requests   │         │
    │  │• Duration   │ │• Errors     │         │
    │  └─────────────┘ └─────────────┘         │
    │                                           │
    │  ┌─────────────┐ ┌─────────────┐         │
    │  │   Gauges    │ │ DistSummary │         │
    │  │• Resources  │ │• Sizes      │         │
    │  │• Counts     │ │• Batches    │         │
    │  └─────────────┘ └─────────────┘         │
    └─────────────┬───────────────────────────┘
                  │
    ┌─────────────▼───────────────────────────┐
    │           CloudWatch Export             │
    │                                         │
    │  Namespace: AccessWeaver/${environment} │
    │  Interval: 1 minute                     │
    │  Batch: 20 metrics                      │
    └─────────────────────────────────────────┘
```

---

## 🔐 Métriques Core Authorization

### 1. Authorization Checks (🚨 Critical)

```java
@Component
public class AuthorizationMetrics {
    
    private final MeterRegistry meterRegistry;
    
    // Compteur principal des vérifications d'autorisation
    private final Counter authorizationRequests;
    private final Counter authorizationAllowed;
    private final Counter authorizationDenied;
    
    // Timer pour la latence (critique pour UX)
    private final Timer authorizationLatency;
    
    public AuthorizationMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
        
        // Requêtes d'autorisation totales
        this.authorizationRequests = Counter.builder("accessweaver.authorization.requests.total")
            .description("Total authorization requests")
            .register(meterRegistry);
            
        // Autorisations accordées
        this.authorizationAllowed = Counter.builder("accessweaver.authorization.allowed.total")
            .description("Total authorizations allowed")
            .register(meterRegistry);
            
        // Autorisations refusées
        this.authorizationDenied = Counter.builder("accessweaver.authorization.denied.total")
            .description("Total authorizations denied")
            .register(meterRegistry);
            
        // Latence des vérifications (P50, P95, P99)
        this.authorizationLatency = Timer.builder("accessweaver.authorization.latency")
            .description("Authorization check latency")
            .publishPercentiles(0.5, 0.95, 0.99)
            .publishPercentileHistogram(true)
            .register(meterRegistry);
    }
    
    public void recordAuthorizationCheck(AuthorizationContext context, boolean allowed, Duration duration) {
        // Tags pour segmentation
        Tags tags = Tags.of(
            "tenant", context.getTenantId(),
            "action", context.getAction(),
            "resource_type", context.getResourceType(),
            "result", allowed ? "allowed" : "denied",
            "engine", context.getEngine(), // RBAC, ABAC, ReBAC
            "cache_hit", context.isCacheHit() ? "true" : "false"
        );
        
        // Enregistrement des métriques
        authorizationRequests.increment(tags);
        
        if (allowed) {
            authorizationAllowed.increment(tags);
        } else {
            authorizationDenied.increment(tags);
        }
        
        authorizationLatency.record(duration, tags);
        
        // Métrique dérivée pour taux de refus
        Gauge.builder("accessweaver.authorization.denial_rate")
            .description("Authorization denial rate")
            .tags("tenant", context.getTenantId())
            .register(meterRegistry, this, m -> calculateDenialRate(context.getTenantId()));
    }
    
    private double calculateDenialRate(String tenantId) {
        // Calcul du taux de refus sur les 5 dernières minutes
        // Implementation dépend du backend de métriques
        return 0.0; // Placeholder
    }
}
```

### 2. Cache Performance (🔶 Important)

```java
@Component
public class CacheMetrics {
    
    private final MeterRegistry meterRegistry;
    
    public CacheMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
    }
    
    public void recordCacheOperation(String operation, String tenant, boolean hit, Duration duration) {
        // Cache hits/misses
        Counter.builder("accessweaver.cache.operations")
            .description("Cache operations")
            .tags(
                "operation", operation, // get, set, delete, evict
                "tenant", tenant,
                "result", hit ? "hit" : "miss"
            )
            .register(meterRegistry)
            .increment();
            
        // Latence cache
        Timer.builder("accessweaver.cache.latency")
            .description("Cache operation latency")
            .tags(
                "operation", operation,
                "tenant", tenant
            )
            .register(meterRegistry)
            .record(duration);
    }
    
    // Métrique pour le hit ratio (gauge calculée)
    @EventListener
    @Async
    public void calculateCacheHitRatio() {
        Gauge.builder("accessweaver.cache.hit_ratio")
            .description("Cache hit ratio percentage")
            .register(meterRegistry, this, CacheMetrics::getCurrentHitRatio);
    }
    
    private double getCurrentHitRatio() {
        // Calcul du hit ratio sur une fenêtre glissante
        return 0.0; // Implementation
    }
}
```

---

## 🌐 Métriques HTTP/API

### 3. Request Metrics (🚨 Critical)

```java
@Component
public class HttpMetrics {
    
    private final MeterRegistry meterRegistry;
    
    // HTTP request timer avec percentiles
    private final Timer httpRequestTimer;
    private final Counter httpRequestsTotal;
    
    public HttpMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
        
        this.httpRequestTimer = Timer.builder("accessweaver.http.request.duration")
            .description("HTTP request duration")
            .publishPercentiles(0.5, 0.95, 0.99)
            .publishPercentileHistogram(true)
            .minimumExpectedValue(Duration.ofMillis(1))
            .maximumExpectedValue(Duration.ofSeconds(10))
            .serviceLevelObjectives(
                Duration.ofMillis(50),   // SLO: 50ms
                Duration.ofMillis(100),  // SLO: 100ms
                Duration.ofMillis(500),  // SLO: 500ms
                Duration.ofSeconds(1)    // SLO: 1s
            )
            .register(meterRegistry);
            
        this.httpRequestsTotal = Counter.builder("accessweaver.http.requests.total")
            .description("Total HTTP requests")
            .register(meterRegistry);
    }
    
    public void recordHttpRequest(HttpServletRequest request, HttpServletResponse response, Duration duration) {
        String method = request.getMethod();
        String endpoint = normalizeEndpoint(request.getRequestURI());
        String status = String.valueOf(response.getStatus());
        String statusClass = getStatusClass(response.getStatus());
        String tenantId = extractTenantId(request);
        
        Tags tags = Tags.of(
            "method", method,
            "endpoint", endpoint,
            "status", status,
            "status_class", statusClass,
            "tenant", tenantId != null ? tenantId : "unknown"
        );
        
        httpRequestsTotal.increment(tags);
        httpRequestTimer.record(duration, tags);
        
        // Métriques spécialisées par endpoint
        recordEndpointSpecificMetrics(endpoint, request, response, duration);
    }
    
    private void recordEndpointSpecificMetrics(String endpoint, HttpServletRequest request, 
                                             HttpServletResponse response, Duration duration) {
        
        if (endpoint.startsWith("/api/v1/check")) {
            // Métriques spécifiques pour l'endpoint d'autorisation
            Timer.builder("accessweaver.api.authorization.duration")
                .description("Authorization API endpoint duration")
                .tags("tenant", extractTenantId(request))
                .register(meterRegistry)
                .record(duration);
        } else if (endpoint.startsWith("/api/v1/policies")) {
            // Métriques pour la gestion des policies
            Timer.builder("accessweaver.api.policies.duration")
                .description("Policies API endpoint duration")
                .register(meterRegistry)
                .record(duration);
        }
    }
    
    private String normalizeEndpoint(String uri) {
        // Normaliser les endpoints pour éviter la cardinalité élevée
        return uri.replaceAll("/\\d+", "/{id}")
                 .replaceAll("/[a-f0-9-]{36}", "/{uuid}")
                 .replaceAll("\\?.*", ""); // Supprimer query params
    }
    
    private String getStatusClass(int status) {
        return status >= 500 ? "5xx" :
               status >= 400 ? "4xx" :
               status >= 300 ? "3xx" :
               status >= 200 ? "2xx" : "1xx";
    }
}
```

### 4. Rate Limiting Metrics (🔶 Important)

```java
@Component
public class RateLimitMetrics {
    
    private final MeterRegistry meterRegistry;
    
    public RateLimitMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
    }
    
    public void recordRateLimit(String tenantId, String endpoint, String clientId, 
                               boolean allowed, int currentCount, int limit) {
        
        // Compteur des requêtes rate limitées
        Counter.builder("accessweaver.ratelimit.requests")
            .description("Rate limiting requests")
            .tags(
                "tenant", tenantId,
                "endpoint", endpoint,
                "client", clientId,
                "result", allowed ? "allowed" : "blocked"
            )
            .register(meterRegistry)
            .increment();
            
        // Gauge pour l'utilisation actuelle du rate limit
        Gauge.builder("accessweaver.ratelimit.usage_ratio")
            .description("Rate limit usage ratio")
            .tags(
                "tenant", tenantId,
                "endpoint", endpoint
            )
            .register(meterRegistry, currentCount, count -> (double) count / limit);
    }
}
```

---

## 📊 Métriques Business

### 5. Tenant Activity (💼 Business)

```java
@Component
public class TenantMetrics {
    
    private final MeterRegistry meterRegistry;
    private final TenantRepository tenantRepository;
    
    public TenantMetrics(MeterRegistry meterRegistry, TenantRepository tenantRepository) {
        this.meterRegistry = meterRegistry;
        this.tenantRepository = tenantRepository;
        
        // Gauge pour le nombre de tenants actifs
        Gauge.builder("accessweaver.tenants.active")
            .description("Number of active tenants")
            .register(meterRegistry, this, TenantMetrics::countActiveTenants);
            
        // Gauge pour le nombre total de tenants
        Gauge.builder("accessweaver.tenants.total")
            .description("Total number of tenants")
            .register(meterRegistry, this, TenantMetrics::countTotalTenants);
    }
    
    public void recordTenantActivity(String tenantId, String activity, Object... context) {
        // Activité par tenant
        Counter.builder("accessweaver.tenant.activity")
            .description("Tenant activity tracking")
            .tags(
                "tenant", tenantId,
                "activity", activity // login, api_call, policy_change, user_add, etc.
            )
            .register(meterRegistry)
            .increment();
            
        // Volume d'activité pour billing
        if (activity.equals("authorization_check")) {
            recordBillableActivity(tenantId, "authorization", 1);
        }
    }
    
    public void recordBillableActivity(String tenantId, String activityType, double quantity) {
        // Métriques pour la facturation
        Counter.builder("accessweaver.billing.usage")
            .description("Billable usage tracking")
            .tags(
                "tenant", tenantId,
                "activity_type", activityType, // authorization, policy_change, api_call
                "plan", getTenantPlan(tenantId)
            )
            .register(meterRegistry)
            .increment(quantity);
    }
    
    private double countActiveTenants() {
        return tenantRepository.countByLastActivityAfter(
            LocalDateTime.now().minusHours(24)
        );
    }
    
    private double countTotalTenants() {
        return tenantRepository.count();
    }
    
    private String getTenantPlan(String tenantId) {
        // Récupérer le plan du tenant (free, pro, enterprise)
        return "unknown"; // Implementation
    }
}
```

### 6. Policy Management Metrics (💼 Business)

```java
@Component
public class PolicyMetrics {
    
    private final MeterRegistry meterRegistry;
    
    public PolicyMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
    }
    
    public void recordPolicyOperation(String tenantId, String operation, String policyType, 
                                    String userId, boolean success) {
        
        // Opérations sur les policies
        Counter.builder("accessweaver.policies.operations")
            .description("Policy management operations")
            .tags(
                "tenant", tenantId,
                "operation", operation, // create, update, delete, activate, deactivate
                "policy_type", policyType, // rbac, abac, rebac
                "user", userId,
                "result", success ? "success" : "error"
            )
            .register(meterRegistry)
            .increment();
    }
    
    public void recordPolicyComplexity(String tenantId, String policyId, int ruleCount, 
                                     int conditionCount, double evaluationTime) {
        
        // Complexité des policies
        Gauge.builder("accessweaver.policies.complexity.rules")
            .description("Number of rules in policy")
            .tags("tenant", tenantId, "policy", policyId)
            .register(meterRegistry, ruleCount, Integer::doubleValue);
            
        Gauge.builder("accessweaver.policies.complexity.conditions")
            .description("Number of conditions in policy")
            .tags("tenant", tenantId, "policy", policyId)
            .register(meterRegistry, conditionCount, Integer::doubleValue);
            
        // Temps d'évaluation des policies
        Timer.builder("accessweaver.policies.evaluation.time")
            .description("Policy evaluation time")
            .tags("tenant", tenantId, "policy", policyId)
            .register(meterRegistry)
            .record(Duration.ofNanos((long) (evaluationTime * 1_000_000)));
    }
}
```

---

## 🔧 Métriques Infrastructure

### 7. Database Metrics (🔶 Important)

```java
@Component
public class DatabaseMetrics {
    
    private final MeterRegistry meterRegistry;
    private final DataSource dataSource;
    
    public DatabaseMetrics(MeterRegistry meterRegistry, DataSource dataSource) {
        this.meterRegistry = meterRegistry;
        this.dataSource = dataSource;
        
        // Connection pool metrics
        if (dataSource instanceof HikariDataSource) {
            HikariDataSource hikariDataSource = (HikariDataSource) dataSource;
            
            Gauge.builder("accessweaver.db.connections.active")
                .description("Active database connections")
                .register(meterRegistry, hikariDataSource, HikariDataSource::getActiveConnections);
                
            Gauge.builder("accessweaver.db.connections.idle")
                .description("Idle database connections")
                .register(meterRegistry, hikariDataSource, HikariDataSource::getIdleConnections);
                
            Gauge.builder("accessweaver.db.connections.total")
                .description("Total database connections")
                .register(meterRegistry, hikariDataSource, HikariDataSource::getTotalConnections);
                
            Gauge.builder("accessweaver.db.connections.waiting")
                .description("Threads waiting for database connection")
                .register(meterRegistry, hikariDataSource, ds -> (double) ds.getHikariPoolMXBean().getThreadsAwaitingConnection());
        }
    }
    
    public void recordDatabaseQuery(String operation, String table, Duration duration, boolean success) {
        Timer.builder("accessweaver.db.query.duration")
            .description("Database query duration")
            .tags(
                "operation", operation, // select, insert, update, delete
                "table", table,
                "result", success ? "success" : "error"
            )
            .register(meterRegistry)
            .record(duration);
    }
    
    public void recordRowLevelSecurityCheck(String tenantId, String table, 
                                          Duration duration, boolean cacheHit) {
        // Métriques spécifiques pour RLS (Row Level Security)
        Timer.builder("accessweaver.db.rls.check.duration")
            .description("Row Level Security check duration")
            .tags(
                "tenant", tenantId,
                "table", table,
                "cache_hit", cacheHit ? "true" : "false"
            )
            .register(meterRegistry)
            .record(duration);
    }
}
```

### 8. JVM Metrics (📊 Useful)

```java
@Configuration
public class JvmMetricsConfiguration {
    
    @Bean
    public JvmMemoryMetrics jvmMemoryMetrics() {
        return new JvmMemoryMetrics();
    }
    
    @Bean
    public JvmGcMetrics jvmGcMetrics() {
        return new JvmGcMetrics();
    }
    
    @Bean
    public JvmThreadMetrics jvmThreadMetrics() {
        return new JvmThreadMetrics();
    }
    
    @Bean
    public ProcessorMetrics processorMetrics() {
        return new ProcessorMetrics();
    }
    
    @Bean
    public UptimeMetrics uptimeMetrics() {
        return new UptimeMetrics();
    }
    
    @Bean
    public DiskSpaceMetrics diskSpaceMetrics(@Value("${management.metrics.export.disk.path:/}") String path) {
        return new DiskSpaceMetrics(Paths.get(path));
    }
    
    @Bean
    public MeterRegistryCustomizer<MeterRegistry> jvmMetricsCommonTags() {
        return registry -> {
            new ClassLoaderMetrics().bindTo(registry);
            new JvmCompilationMetrics().bindTo(registry);
            new JvmHeapPressureMetrics().bindTo(registry);
        };
    }
}
```

---

## ⚡ Métriques Performance Avancées

### 9. Circuit Breaker Metrics (🔶 Important)

```java
@Component
public class ResilienceMetrics {
    
    private final MeterRegistry meterRegistry;
    
    public ResilienceMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
        
        // Enregistrer les métriques Resilience4j automatiquement
        CircuitBreakerRegistry.ofDefaults().getEventPublisher()
            .onStateTransition(event -> recordCircuitBreakerStateChange(event));
            
        RetryRegistry.ofDefaults().getEventPublisher()
            .onRetry(event -> recordRetryAttempt(event));
    }
    
    private void recordCircuitBreakerStateChange(CircuitBreaker.StateTransitionEvent event) {
        Counter.builder("accessweaver.circuitbreaker.state.transitions")
            .description("Circuit breaker state transitions")
            .tags(
                "name", event.getCircuitBreakerName(),
                "from_state", event.getStateTransition().getFromState().name(),
                "to_state", event.getStateTransition().getToState().name()
            )
            .register(meterRegistry)
            .increment();
    }
    
    private void recordRetryAttempt(Retry.Event event) {
        Counter.builder("accessweaver.retry.attempts")
            .description("Retry attempts")
            .tags(
                "name", event.getName(),
                "type", event.getEventType().name()
            )
            .register(meterRegistry)
            .increment();
    }
    
    public void recordBulkheadMetrics(String name, int availablePermits, int maxPermits) {
        Gauge.builder("accessweaver.bulkhead.available_permits")
            .description("Available bulkhead permits")
            .tags("name", name)
            .register(meterRegistry, availablePermits, Integer::doubleValue);
            
        Gauge.builder("accessweaver.bulkhead.usage_ratio")
            .description("Bulkhead usage ratio")
            .tags("name", name)
            .register(meterRegistry, () -> (double) (maxPermits - availablePermits) / maxPermits);
    }
}
```

### 10. Security Metrics (🚨 Critical)

```java
@Component
public class SecurityMetrics {
    
    private final MeterRegistry meterRegistry;
    
    public SecurityMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
    }
    
    public void recordAuthenticationAttempt(String tenantId, String clientId, String method, 
                                          boolean success, String failureReason) {
        
        Counter.builder("accessweaver.auth.attempts")
            .description("Authentication attempts")
            .tags(
                "tenant", tenantId,
                "client", clientId,
                "method", method, // jwt, api_key, oauth
                "result", success ? "success" : "failure",
                "failure_reason", failureReason != null ? failureReason : "none"
            )
            .register(meterRegistry)
            .increment();
    }
    
    public void recordSuspiciousActivity(String tenantId, String activityType, String source, 
                                       String severity) {
        
        Counter.builder("accessweaver.security.suspicious_activity")
            .description("Suspicious security activity")
            .tags(
                "tenant", tenantId,
                "activity_type", activityType, // brute_force, privilege_escalation, data_exfiltration
                "source", source, // ip, user_agent, api_key
                "severity", severity // low, medium, high, critical
            )
            .register(meterRegistry)
            .increment();
    }
    
    public void recordTokenOperation(String tenantId, String operation, String tokenType, 
                                   boolean success, Duration duration) {
        
        Timer.builder("accessweaver.tokens.operations")
            .description("Token operations duration")
            .tags(
                "tenant", tenantId,
                "operation", operation, // generate, validate, refresh, revoke
                "token_type", tokenType, // jwt, api_key, refresh
                "result", success ? "success" : "error"
            )
            .register(meterRegistry)
            .record(duration);
    }
}
```

---

## 📋 Configuration des Métriques

### Règles de Nommage et Tags

```yaml
# Convention de nommage AccessWeaver
metrics:
  naming_convention:
    # Format: accessweaver.{domain}.{metric_type}.{unit}
    pattern: "accessweaver.{domain}.{metric_type}[.{unit}]"
    
    domains:
      - authorization  # Métriques d'autorisation
      - http          # Métriques HTTP/API
      - cache         # Métriques de cache
      - db            # Métriques base de données
      - tenant        # Métriques business tenant
      - security      # Métriques sécurité
      - system        # Métriques système
      
    metric_types:
      - requests      # Compteurs de requêtes
      - duration      # Timers de durée
      - errors        # Compteurs d'erreurs
      - usage         # Gauges d'utilisation
      - rate          # Taux calculés
      
  required_tags:
    global:
      - environment   # dev, staging, prod
      - service       # aw-api-gateway, aw-pdp-service, etc.
      - version       # Version de l'application
      
    contextual:
      - tenant        # ID du tenant (si applicable)
      - user          # ID utilisateur (si applicable, anonymisé)
      - region        # Région AWS
```

### Configuration Micrometer Avancée

```java
@Configuration
public class MetricsConfiguration {
    
    @Bean
    @ConfigurationProperties("management.metrics.export.cloudwatch")
    public CloudWatchConfig cloudWatchConfig() {
        return new CloudWatchConfig() {
            @Override
            public String namespace() {
                return "AccessWeaver/" + environment;
            }
            
            @Override
            public Duration step() {
                return Duration.ofMinutes(1);
            }
            
            @Override
            public int batchSize() {
                return 20; // Optimisé pour éviter les limites AWS
            }
            
            @Override
            public boolean enabled() {
                return !environment.equals("local");
            }
            
            @Override
            public String get(String key) {
                return null;
            }
        };
    }
    
    @Bean
    public MeterFilter meterFilter() {
        return MeterFilter.denyNameStartsWith("jvm")
            .and(MeterFilter.denyNameStartsWith("system"))
            .and(MeterFilter.denyNameStartsWith("process"))
            .and(MeterFilter.maximumAllowableTags("accessweaver", "tenant", 100))
            .and(MeterFilter.maximumAllowableMetrics(1000));
    }
    
    @Bean
    public MeterRegistryCustomizer<CloudWatchMeterRegistry> cloudWatchMetricsCustomizer() {
        return registry -> {
            registry.config()
                .commonTags(
                    "service", applicationName,
                    "environment", environment,
                    "version", applicationVersion,
                    "region", awsRegion
                )
                .meterFilter(MeterFilter.deny(id -> {
                    String name = id.getName();
                    // Filtrer les métriques non essentielles pour réduire les coûts
                    return name.startsWith("http.server.requests") && 
                           id.getTag("uri") != null && 
                           id.getTag("uri").contains("actuator");
                }));
        };
    }
}
```

---

## 🎛 Dashboards et Alertes

### SLIs/SLOs pour AccessWeaver

```yaml
service_level_objectives:
  authorization_api:
    availability:
      target: 99.9%      # 43 minutes downtime/month
      measurement: "success_rate_5m"
      
    latency:
      target_p95: 100ms  # 95% des requêtes < 100ms
      target_p99: 500ms  # 99% des requêtes < 500ms
      measurement: "accessweaver.authorization.latency"
      
    error_rate:
      target: 0.1%       # < 0.1% d'erreurs
      measurement: "error_rate_5m"
      
  policy_management:
    availability:
      target: 99.5%      # 3.6 hours downtime/month
      measurement: "success_rate_5m"
      
    latency:
      target_p95: 500ms  # Moins critique que l'autorisation
      target_p99: 2s
      
  cache_performance:
    hit_ratio:
      target: 95%        # 95% de cache hits
      measurement: "accessweaver.cache.hit_ratio"
```

### Alertes Proactives

```java
@Component
public class ProactiveAlerting {
    
    private final MeterRegistry meterRegistry;
    private final AlertManager alertManager;
    
    @Scheduled(fixedDelay = 60000) // Chaque minute
    public void checkSLOCompliance() {
        
        // Vérifier latence P95 autorisation
        Timer authTimer = meterRegistry.find("accessweaver.authorization.latency").timer();
        if (authTimer != null) {
            double p95 = authTimer.takeSnapshot().percentileValue(0.95);
            if (p95 > 100) { // SLO violation
                alertManager.sendAlert(AlertLevel.WARNING, 
                    "Authorization P95 latency above SLO: " + p95 + "ms");
            }
        }
        
        // Vérifier taux d'erreur
        Counter errors = meterRegistry.find("accessweaver.authorization.denied").counter();
        Counter total = meterRegistry.find("accessweaver.authorization.requests.total").counter();
        
        if (errors != null && total != null) {
            double errorRate = errors.count() / total.count();
            if (errorRate > 0.05) { // > 5% d'erreurs
                alertManager.sendAlert(AlertLevel.CRITICAL,
                    "High authorization denial rate: " + (errorRate * 100) + "%");
            }
        }
        
        // Vérifier utilisation resources
        checkResourceUtilization();
    }
    
    private void checkResourceUtilization() {
        // Vérifier connexions DB
        Gauge dbConnections = meterRegistry.find("accessweaver.db.connections.active").gauge();
        if (dbConnections != null && dbConnections.value() > 80) {
            alertManager.sendAlert(AlertLevel.WARNING,
                "High database connection usage: " + dbConnections.value());
        }
        
        // Vérifier cache hit ratio
        Gauge cacheHitRatio = meterRegistry.find("accessweaver.cache.hit_ratio").gauge();
        if (cacheHitRatio != null && cacheHitRatio.value() < 0.90) {
            alertManager.sendAlert(AlertLevel.WARNING,
                "Low cache hit ratio: " + (cacheHitRatio.value() * 100) + "%");
        }
    }
}
```

---

## 📊 Métriques Business Avancées

### Revenue Impact Metrics

```java
@Component
public class RevenueMetrics {
    
    private final MeterRegistry meterRegistry;
    
    public void recordBillableEvent(String tenantId, String plan, String eventType, 
                                  double cost, double quantity) {
        
        // Volume facturable par tenant
        Counter.builder("accessweaver.revenue.billable_events")
            .description("Billable events for revenue tracking")
            .tags(
                "tenant", tenantId,
                "plan", plan, // free, pro, enterprise
                "event_type", eventType, // api_call, user_seat, policy_check
                "cost_tier", getCostTier(cost)
            )
            .register(meterRegistry)
            .increment(quantity);
            
        // Revenue potentiel
        Gauge.builder("accessweaver.revenue.potential")
            .description("Potential revenue by tenant")
            .tags("tenant", tenantId, "plan", plan)
            .register(meterRegistry, cost, Double::doubleValue);
    }
    
    public void recordUsageLimit(String tenantId, String limitType, 
                                double currentUsage, double limit) {
        
        // Ratio d'utilisation des limites
        Gauge.builder("accessweaver.usage.limit_ratio")
            .description("Usage limit ratio for upselling")
            .tags(
                "tenant", tenantId,
                "limit_type", limitType, // api_calls, policies, users
                "approaching_limit", currentUsage > (limit * 0.8) ? "true" : "false"
            )
            .register(meterRegistry, () -> currentUsage / limit);
    }
    
    private String getCostTier(double cost) {
        if (cost == 0) return "free";
        if (cost < 0.01) return "low";
        if (cost < 0.10) return "medium";
        return "high";
    }
}
```

### Customer Health Metrics

```java
@Component
public class CustomerHealthMetrics {
    
    private final MeterRegistry meterRegistry;
    
    public void recordCustomerEngagement(String tenantId, String engagementType, 
                                       double value, LocalDateTime timestamp) {
        
        // Métriques d'engagement client
        Counter.builder("accessweaver.customer.engagement")
            .description("Customer engagement tracking")
            .tags(
                "tenant", tenantId,
                "engagement_type", engagementType, // daily_active, feature_usage, support_ticket
                "trend", calculateTrend(tenantId, engagementType, value)
            )
            .register(meterRegistry)
            .increment(value);
    }
    
    public void recordFeatureAdoption(String tenantId, String feature, boolean adopted) {
        // Adoption des fonctionnalités
        Counter.builder("accessweaver.features.adoption")
            .description("Feature adoption tracking")
            .tags(
                "tenant", tenantId,
                "feature", feature, // rbac, abac, rebac, api_management, audit
                "adopted", adopted ? "true" : "false"
            )
            .register(meterRegistry)
            .increment();
    }
    
    private String calculateTrend(String tenantId, String engagementType, double currentValue) {
        // Calculer la tendance (increasing, stable, decreasing)
        return "stable"; // Implementation
    }
}
```

---

## 🧪 Testing des Métriques

### Tests Unitaires

```java
@ExtendWith(MockitoExtension.class)
class AuthorizationMetricsTest {
    
    @Mock
    private MeterRegistry meterRegistry;
    
    @Mock
    private Counter counter;
    
    @Mock
    private Timer timer;
    
    private AuthorizationMetrics authorizationMetrics;
    
    @BeforeEach
    void setUp() {
        when(meterRegistry.counter(any(String.class), any(Tags.class))).thenReturn(counter);
        when(meterRegistry.timer(any(String.class), any(Tags.class))).thenReturn(timer);
        
        authorizationMetrics = new AuthorizationMetrics(meterRegistry);
    }
    
    @Test
    void shouldRecordAuthorizationCheckMetrics() {
        // Given
        AuthorizationContext context = new AuthorizationContext("tenant1", "read", "document", "RBAC");
        Duration duration = Duration.ofMillis(50);
        
        // When
        authorizationMetrics.recordAuthorizationCheck(context, true, duration);
        
        // Then
        verify(counter, times(2)).increment(any(Tags.class)); // requests + allowed
        verify(timer).record(eq(duration), any(Tags.class));
    }
    
    @Test
    void shouldRecordDeniedAuthorizationWithCorrectTags() {
        // Given
        AuthorizationContext context = new AuthorizationContext("tenant1", "delete", "admin", "RBAC");
        Duration duration = Duration.ofMillis(25);
        
        // When
        authorizationMetrics.recordAuthorizationCheck(context, false, duration);
        
        // Then
        ArgumentCaptor<Tags> tagsCaptor = ArgumentCaptor.forClass(Tags.class);
        verify(counter, atLeastOnce()).increment(tagsCaptor.capture());
        
        Tags capturedTags = tagsCaptor.getValue();
        assertThat(capturedTags.getTag("result")).isEqualTo("denied");
        assertThat(capturedTags.getTag("tenant")).isEqualTo("tenant1");
        assertThat(capturedTags.getTag("action")).isEqualTo("delete");
    }
}
```

### Tests d'Intégration

```java
@SpringBootTest
@TestPropertySource(properties = {
    "management.metrics.export.simple.enabled=true",
    "management.metrics.export.cloudwatch.enabled=false"
})
class MetricsIntegrationTest {
    
    @Autowired
    private MeterRegistry meterRegistry;
    
    @Autowired
    private AuthorizationService authorizationService;
    
    @Test
    void shouldCollectMetricsForAuthorizationFlow() {
        // Given
        String tenantId = "test-tenant";
        AuthorizationRequest request = new AuthorizationRequest(tenantId, "user1", "read", "document1");
        
        // When
        authorizationService.checkAuthorization(request);
        
        // Then
        Timer authTimer = meterRegistry.find("accessweaver.authorization.latency")
            .tag("tenant", tenantId)
            .timer();
        
        assertThat(authTimer).isNotNull();
        assertThat(authTimer.count()).isEqualTo(1);
        
        Counter requestCounter = meterRegistry.find("accessweaver.authorization.requests.total")
            .tag("tenant", tenantId)
            .counter();
            
        assertThat(requestCounter).isNotNull();
        assertThat(requestCounter.count()).isEqualTo(1);
    }
}
```

---

## 💰 Optimisation des Coûts

### Stratégies de Réduction

```yaml
cost_optimization:
  sampling:
    # Réduire la cardinalité des métriques
    high_cardinality_tags:
      - user_id: sample_rate: 0.1
      - request_id: enabled: false
      - trace_id: enabled: false
      
  aggregation:
    # Pré-agrégation pour réduire le volume
    time_windows:
      - 1m: all_metrics
      - 5m: business_metrics_only
      - 15m: system_metrics_only
      
  retention:
    # Retention différenciée
    critical_metrics: 90d
    business_metrics: 60d
    debug_metrics: 30d
    development_metrics: 7d
    
  filtering:
    # Exclure métriques non essentielles
    exclude_patterns:
      - "jvm.*" # En dev uniquement
      - "*.health.*" # Métriques de santé détaillées
      - "*actuator*" # Endpoints actuator
```

### Budget Alert Configuration

```hcl
# Budget spécifique pour métriques
resource "aws_budgets_budget" "metrics_budget" {
  name         = "accessweaver-${var.environment}-metrics-budget"
  budget_type  = "COST"
  limit_amount = var.environment == "prod" ? "200" : "50"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  cost_filters {
    service = ["Amazon CloudWatch"]
  }
  
  cost_filters {
    tag = {
      "Component" = ["monitoring"]
    }
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.ops_email]
  }
}
```

---

## 📋 Checklist Métriques

### ✅ Implémentation
- [ ] Métriques d'autorisation (latence, succès/échec)
- [ ] Métriques HTTP (requêtes, codes status, latence)
- [ ] Métriques cache (hits/miss, latence)
- [ ] Métriques base de données (connexions, requêtes)
- [ ] Métriques business (tenants, policies, revenue)
- [ ] Métriques sécurité (auth, activité suspecte)
- [ ] Métriques infrastructure (JVM, système)

### ✅ Configuration
- [ ] Nommage cohérent des métriques
- [ ] Tags standardisés
- [ ] Filtres pour contrôler cardinalité
- [ ] Export CloudWatch configuré
- [ ] Retention optimisée

### ✅ Monitoring
- [ ] SLIs/SLOs définis
- [ ] Alertes proactives configurées
- [ ] Dashboards opérationnels
- [ ] Tests de métriques implémentés

---

**📊 Résumé des Métriques AccessWeaver :**
- **🚨 Critical** : 15 métriques (authorization, HTTP, errors)
- **🔶 Important** : 12 métriques (cache, DB, security)
- **📊 Useful** : 8 métriques (JVM, system, debug)
- **💼 Business** : 10 métriques (tenant, revenue, adoption)

**💰 Coût estimé :** $30-150/mois selon environnement et cardinalité