# 🏗 Architecture Microservices - AccessWeaver

Documentation détaillée de l'architecture microservices d'AccessWeaver avec patterns de communication, responsabilités et déploiement.

---

## 📋 Table des Matières

- [Vue d'Ensemble](#vue-densemble)
- [Services Core](#services-core)
- [Patterns de Communication](#patterns-de-communication)
- [Gestion des Données](#gestion-des-données)
- [Sécurité Inter-Services](#sécurité-inter-services)
- [Déploiement et Orchestration](#déploiement-et-orchestration)
- [Monitoring et Observabilité](#monitoring-et-observabilité)

---

## 🎯 Vue d'Ensemble

### **Architecture High-Level**

```
┌─────────────────────────────────────────────────────────────┐
│                      Internet/Users                         │
└─────────────────────┬───────────────────────────────────────┘
                      │ HTTPS
┌─────────────────────▼───────────────────────────────────────┐
│                 ALB + WAF + SSL                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                aw-api-gateway                               │
│              (Spring Cloud Gateway)                        │
│          • Authentication (JWT)                            │
│          • Rate Limiting                                   │
│          • Request Routing                                 │
│          • Multi-tenant Context                            │
└─────────────────────┬───────────────────────────────────────┘
                      │ Internal HTTP/gRPC
            ┌─────────┼─────────┼─────────┼─────────┐
            │         │         │         │         │
    ┌───────▼───┐ ┌──▼──┐ ┌────▼────┐ ┌──▼──┐ ┌───▼────┐
    │aw-pdp-    │ │aw-  │ │aw-tenant│ │aw-  │ │aw-audit│
    │service    │ │pap- │ │service  │ │admin│ │service │
    │(Decision) │ │svc  │ │(Multi-T)│ │ui   │ │(Logs)  │
    └───────────┘ └─────┘ └─────────┘ └─────┘ └────────┘
            │         │         │         │         │
            └─────────┼─────────┼─────────┼─────────┘
                      │         │         │
    ┌─────────────────▼─────────▼─────────▼─────────────────┐
    │              Shared Data Layer                       │
    │  ┌─────────────────┐  ┌──────────────────────────┐   │
    │  │   PostgreSQL    │  │      Redis Cache         │   │
    │  │   (RLS Multi-   │  │   (Sessions, Permissions,│   │
    │  │    Tenant)      │  │    Rate Limiting)        │   │
    │  └─────────────────┘  └──────────────────────────┘   │
    └─────────────────────────────────────────────────────┘
```

### **Philosophie Architecture**

| Principe | Description | Bénéfice |
|----------|-------------|----------|
| **Domain-Driven Design** | Chaque service correspond à un domaine métier | Cohésion forte, couplage faible |
| **API-First** | Contrats d'API définis avant implémentation | Intégration facilitée, tests efficaces |
| **Stateless Services** | Aucun état local, tout en base/cache | Scalabilité horizontale simple |
| **Event-Driven** | Communication asynchrone via événements | Résilience, découplage temporel |
| **Multi-Tenant Native** | Isolation au niveau service et données | Sécurité renforcée, conformité RGPD |

---

## 🏛 Services Core

### **1. aw-api-gateway**

#### **Responsabilités**
- **Point d'entrée unique** pour toutes les requêtes externes
- **Authentification JWT** et validation des tokens
- **Rate limiting** par tenant et par utilisateur
- **Routage intelligent** vers les services backend
- **Multi-tenant context** injection dans les headers

#### **Stack Technique**
```java
• Spring Cloud Gateway (reactive)
• Spring Security OAuth2 Resource Server
• Spring Data Redis (rate limiting)
• Resilience4j (circuit breaker)
• Micrometer (métriques)
```

#### **Patterns Implementés**
- **API Gateway Pattern** : Point d'entrée centralisé
- **Authentication Proxy** : Validation JWT centralisée
- **Rate Limiter** : Protection contre abus
- **Request/Response Transformation** : Normalisation des formats

#### **Configuration Exemple**
```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: pdp-service
          uri: http://aw-pdp-service:8081
          predicates:
            - Path=/api/v1/check/**
          filters:
            - AddRequestHeader=X-Tenant-ID, #{tenantId}
            - RateLimiter=#{tenantRateLimit}
```

### **2. aw-pdp-service (Policy Decision Point)**

#### **Responsabilités**
- **Évaluation des permissions** en temps réel (<10ms)
- **Moteur RBAC/ABAC/ReBAC** hybride
- **Cache L1/L2** pour performances optimales
- **Policy compilation** et optimisation

#### **Stack Technique**
```java
• Spring Boot (blocking I/O pour performance)
• Open Policy Agent (OPA) embedded
• Spring Data JPA (requêtes optimisées)
• Redis Template (cache distribué)
• Neo4j Driver (relations ReBAC)
```

#### **Architecture Interne**
```
┌─────────────────────────────────────────┐
│           PDP Service Core              │
├─────────────────────────────────────────┤
│  Decision Engine                        │
│  ├── RBAC Engine (fast path)            │
│  ├── ABAC Engine (OPA integration)      │
│  └── ReBAC Engine (graph traversal)     │
├─────────────────────────────────────────┤
│  Cache Layer                            │
│  ├── L1: Local Caffeine (1ms)           │
│  ├── L2: Redis Distributed (5ms)        │
│  └── L3: Database (10ms)                │
├─────────────────────────────────────────┤
│  Performance Optimization               │
│  ├── Permission Pre-computation         │
│  ├── Batch Decision API                 │
│  └── Query Plan Optimization            │
└─────────────────────────────────────────┘
```

#### **API Principale**
```java
@PostMapping("/api/v1/check")
public ResponseEntity<DecisionResponse> checkPermission(
    @Valid @RequestBody DecisionRequest request,
    @RequestHeader("X-Tenant-ID") String tenantId
) {
    // Validation + Cache lookup + Decision logic
    return ResponseEntity.ok(decisionService.evaluate(request, tenantId));
}
```

### **3. aw-pap-service (Policy Administration Point)**

#### **Responsabilités**
- **Gestion des policies** (CRUD + versioning)
- **Administration des rôles et permissions**
- **Validation et compilation** des règles
- **Migration et import/export** de configurations

#### **Stack Technique**
```java
• Spring Boot MVC
• Spring Data JPA (gestion transactionnelle)
• Flyway (migrations schéma)
• Jackson (sérialisation JSON/YAML)
• Validation API (JSR-303)
```

#### **Patterns Implementés**
- **CQRS Pattern** : Séparation lecture/écriture
- **Event Sourcing** : Historique des changements
- **Saga Pattern** : Transactions distribuées
- **Versioning** : Gestion des versions de policies

### **4. aw-tenant-service**

#### **Responsabilités**
- **Provisioning de tenants** automatisé
- **Configuration par tenant** (quotas, features)
- **Isolation des données** et validation
- **Onboarding** et lifecycle management

#### **Stack Technique**
```java
• Spring Boot
• Spring Data JPA (Row-Level Security)
• Spring Cloud Config (configuration tenant)
• PostgreSQL (isolation native)
• Redis (cache configuration)
```

#### **Multi-Tenancy Strategy**
```java
@Component
public class TenantContextFilter implements Filter {
    
    @Override
    public void doFilter(ServletRequest request, ServletResponse response, 
                        FilterChain chain) throws IOException, ServletException {
        
        String tenantId = extractTenantId(request);
        
        // Set PostgreSQL session variable for RLS
        jdbcTemplate.execute("SET app.current_tenant_id = '" + tenantId + "'");
        
        // Set thread-local context
        TenantContext.setCurrentTenant(tenantId);
        
        try {
            chain.doFilter(request, response);
        } finally {
            TenantContext.clear();
            jdbcTemplate.execute("RESET app.current_tenant_id");
        }
    }
}
```

### **5. aw-audit-service**

#### **Responsabilités**
- **Logging centralisé** de toutes les décisions
- **Audit trail** pour compliance (RGPD, SOC2)
- **Analytics** et reporting
- **Détection d'anomalies** de sécurité

#### **Stack Technique**
```java
• Spring Boot
• Spring Data Elasticsearch (logs search)
• Kafka/RabbitMQ (événements async)
• Spring Batch (rapports)
• Micrometer (métriques business)
```

---

## 🔗 Patterns de Communication

### **1. Communication Synchrone**

#### **HTTP REST**
```java
// Internal service-to-service calls
@FeignClient(name = "aw-pdp-service", url = "${services.pdp.url}")
public interface PdpServiceClient {
    
    @PostMapping("/internal/v1/bulk-check")
    List<DecisionResponse> bulkCheck(
        @RequestBody List<DecisionRequest> requests,
        @RequestHeader("X-Tenant-ID") String tenantId,
        @RequestHeader("X-Correlation-ID") String correlationId
    );
}
```

#### **gRPC (Performance Critical)**
```protobuf
// Pour les appels haute fréquence PDP
service PolicyDecisionService {
  rpc CheckPermission(DecisionRequest) returns (DecisionResponse);
  rpc BulkCheckPermissions(BulkDecisionRequest) returns (BulkDecisionResponse);
}
```

### **2. Communication Asynchrone**

#### **Event-Driven Architecture**
```java
// Policy changes propagation
@EventListener
@Async("eventExecutor")
public void handlePolicyUpdated(PolicyUpdatedEvent event) {
    // Invalidate caches across all PDP instances
    cacheInvalidationService.invalidatePolicy(
        event.getTenantId(), 
        event.getPolicyId()
    );
}
```

#### **Message Queue Integration**
```yaml
# Application events via Kafka/RabbitMQ
spring:
  kafka:
    topics:
      policy-updates: "accessweaver.policy.updated"
      cache-invalidation: "accessweaver.cache.invalidate"
      audit-events: "accessweaver.audit.decision"
```

### **3. Service Discovery**

#### **AWS ECS Service Discovery**
```java
// Automatic service registration
@Configuration
public class ServiceDiscoveryConfig {
    
    @Bean
    @LoadBalanced
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }
    
    // Usage: http://aw-pdp-service/api/v1/check
    // Automatically resolves to healthy instance
}
```

---

## 💾 Gestion des Données

### **1. Database per Service**

| Service | Database | Usage |
|---------|----------|-------|
| **aw-pdp-service** | PostgreSQL (read-heavy) | Policies, permissions cache |
| **aw-pap-service** | PostgreSQL (write-heavy) | Policy management, admin |
| **aw-tenant-service** | PostgreSQL (RLS) | Tenant data, configuration |
| **aw-audit-service** | PostgreSQL + Elasticsearch | Audit logs, analytics |

### **2. Shared Data Patterns**

#### **Read Replicas pour Performance**
```java
@Configuration
public class DatabaseConfig {
    
    @Primary
    @Bean
    public DataSource primaryDataSource() {
        // Write operations
        return DataSourceBuilder.create()
            .url("jdbc:postgresql://primary-db:5432/accessweaver")
            .build();
    }
    
    @Bean
    public DataSource replicaDataSource() {
        // Read operations (PDP queries)
        return DataSourceBuilder.create()
            .url("jdbc:postgresql://replica-db:5432/accessweaver")
            .build();
    }
}
```

#### **Cache Sharing Strategy**
```java
// Redis patterns pour data sharing
public class SharedCachePatterns {
    
    // Pattern 1: Permission cache (PDP)
    // Key: permissions:tenant:{tenantId}:user:{userId}:resource:{resourceId}
    
    // Pattern 2: Configuration cache (Tenant Service)
    // Key: config:tenant:{tenantId}:feature:{featureName}
    
    // Pattern 3: Rate limiting (API Gateway)
    // Key: ratelimit:tenant:{tenantId}:endpoint:{endpoint}:window:{timestamp}
}
```

### **3. Data Consistency**

#### **Eventual Consistency Model**
```java
// Saga pattern pour transactions distribuées
@Component
public class PolicyUpdateSaga {
    
    @SagaOrchestrationStart
    public void updatePolicy(PolicyUpdateCommand command) {
        // 1. Update in PAP service
        policyRepository.updatePolicy(command.getPolicy());
        
        // 2. Invalidate PDP caches (async)
        eventPublisher.publishEvent(new PolicyUpdatedEvent(command));
        
        // 3. Update audit logs (async)
        auditService.logPolicyChange(command);
    }
}
```

---

## 🔐 Sécurité Inter-Services

### **1. Service-to-Service Authentication**

#### **JWT Internal Tokens**
```java
@Component
public class InternalTokenProvider {
    
    public String generateServiceToken(String fromService, String toService) {
        return Jwts.builder()
            .setSubject(fromService)
            .setAudience(toService)
            .setExpiration(Date.from(Instant.now().plusSeconds(30)))
            .claim("scope", "internal")
            .signWith(servicePrivateKey)
            .compact();
    }
}
```

#### **mTLS pour Production**
```yaml
# Configuration Envoy/Istio pour mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: accessweaver-services
spec:
  mtls:
    mode: STRICT
```

### **2. Network Security**

#### **Security Groups AWS**
```hcl
# Terraform configuration
resource "aws_security_group" "ecs_internal" {
  name_prefix = "accessweaver-internal"
  
  # Only allow internal service communication
  ingress {
    from_port       = 8080
    to_port         = 8090
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_services.id]
  }
}
```

---

## 🚀 Déploiement et Orchestration

### **1. Container Strategy**

#### **Multi-Stage Docker Build**
```dockerfile
# Exemple pour aw-pdp-service
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY . .
RUN ./mvnw clean package -DskipTests

FROM eclipse-temurin:21-jre-alpine
COPY --from=builder /app/target/aw-pdp-service.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

#### **ECS Task Definitions**
```json
{
  "family": "accessweaver-pdp-service",
  "taskRoleArn": "arn:aws:iam::account:role/ecsTaskRole",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "containerDefinitions": [
    {
      "name": "aw-pdp-service",
      "image": "123456789012.dkr.ecr.region.amazonaws.com/aw-pdp-service:latest",
      "portMappings": [{"containerPort": 8081, "protocol": "tcp"}],
      "environment": [
        {"name": "SPRING_PROFILES_ACTIVE", "value": "prod"},
        {"name": "SPRING_DATASOURCE_URL", "value": "jdbc:postgresql://..."}
      ],
      "secrets": [
        {"name": "DB_PASSWORD", "valueFrom": "arn:aws:secretsmanager:..."}
      ]
    }
  ]
}
```

### **2. Auto-Scaling Configuration**

#### **Service-Specific Scaling**
```yaml
services:
  aw-pdp-service:
    min_capacity: 3      # Critique pour les décisions
    max_capacity: 15     # Scale important pour les pics
    target_cpu: 60       # Plus agressif
    target_memory: 70
    
  aw-pap-service:
    min_capacity: 2      # Administration moins critique
    max_capacity: 6
    target_cpu: 75
    target_memory: 80
```

---

## 📊 Monitoring et Observabilité

### **1. Métriques Business**

#### **Custom Metrics par Service**
```java
// PDP Service metrics
@Component
public class PdpMetrics {
    
    private final Counter decisionsTotal;
    private final Timer decisionLatency;
    private final Gauge cacheHitRatio;
    
    @EventListener
    public void onDecisionMade(DecisionEvent event) {
        decisionsTotal.increment(
            Tags.of(
                "tenant", event.getTenantId(),
                "decision", event.getDecision().toString(),
                "engine", event.getEngine() // RBAC/ABAC/ReBAC
            )
        );
    }
}
```

### **2. Distributed Tracing**

#### **Correlation ID Propagation**
```java
@Component
public class CorrelationInterceptor implements HandlerInterceptor {
    
    @Override
    public boolean preHandle(HttpServletRequest request, 
                           HttpServletResponse response, 
                           Object handler) {
        String correlationId = request.getHeader("X-Correlation-ID");
        if (correlationId == null) {
            correlationId = UUID.randomUUID().toString();
        }
        
        MDC.put("correlationId", correlationId);
        response.setHeader("X-Correlation-ID", correlationId);
        
        return true;
    }
}
```

### **3. Health Checks**

#### **Service Health Endpoints**
```java
@RestController
public class HealthController {
    
    @GetMapping("/actuator/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> health = new HashMap<>();
        
        // Database connectivity
        health.put("database", checkDatabase());
        
        // Redis connectivity  
        health.put("cache", checkRedis());
        
        // Service dependencies
        health.put("dependencies", checkDependencies());
        
        boolean isHealthy = health.values().stream()
            .allMatch(status -> "UP".equals(status));
            
        return ResponseEntity
            .status(isHealthy ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE)
            .body(health);
    }
}
```

---

## 🎯 Patterns de Résilience

### **1. Circuit Breaker**
```java
@Component
public class ServiceClients {
    
    @CircuitBreaker(name = "pdp-service", fallbackMethod = "fallbackDecision")
    @Retry(name = "pdp-service")
    @TimeLimiter(name = "pdp-service")
    public CompletableFuture<DecisionResponse> checkPermissionAsync(DecisionRequest request) {
        return CompletableFuture.supplyAsync(() -> 
            pdpServiceClient.checkPermission(request)
        );
    }
    
    public CompletableFuture<DecisionResponse> fallbackDecision(DecisionRequest request, Exception ex) {
        // Conservative fallback: deny by default
        return CompletableFuture.completedFuture(
            DecisionResponse.builder()
                .allowed(false)
                .reason("Service temporarily unavailable")
                .build()
        );
    }
}
```

### **2. Bulkhead Pattern**
```java
@Configuration
public class ThreadPoolConfig {
    
    @Bean("pdpExecutor")
    public Executor pdpExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(10);
        executor.setMaxPoolSize(20);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("pdp-");
        return executor;
    }
    
    @Bean("auditExecutor") 
    public Executor auditExecutor() {
        // Separate thread pool for audit operations
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(5);
        executor.setMaxPoolSize(10);
        return executor;
    }
}
```

---

**🎉 Architecture microservices AccessWeaver détaillée et prête pour l'implémentation enterprise !**

Cette architecture garantit **performance**, **sécurité**, **scalabilité** et **observabilité** pour un système d'autorisation moderne et robuste.