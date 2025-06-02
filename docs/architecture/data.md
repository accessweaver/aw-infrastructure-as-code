# 💾 Architecture Données - AccessWeaver

Documentation complète du modèle de données, stratégies de persistance et optimisations pour AccessWeaver.

---

## 📋 Table des Matières

- [Vue d'Ensemble](#vue-densemble)
- [Modèle de Données Core](#modèle-de-données-core)
- [Multi-Tenancy Strategy](#multi-tenancy-strategy)
- [Stratégies de Cache](#stratégies-de-cache)
- [Performance et Optimisation](#performance-et-optimisation)
- [Sécurité des Données](#sécurité-des-données)
- [Backup et Recovery](#backup-et-recovery)

---

## 🎯 Vue d'Ensemble

### **Stack de Persistance**

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                        │
├─────────────────────────────────────────────────────────────┤
│                    Cache Layer                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ Redis L2    │  │ Caffeine L1 │  │ Application │         │
│  │ (Distributed│  │ (In-Memory) │  │ Cache       │         │
│  │  5ms)       │  │   <1ms      │  │             │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
├─────────────────────────────────────────────────────────────┤
│                 Persistence Layer                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ PostgreSQL  │  │   Neo4j     │  │Elasticsearch│         │
│  │ (RBAC/ABAC) │  │  (ReBAC)    │  │  (Audit)    │         │
│  │   ACID      │  │   Graph     │  │   Search    │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

### **Répartition des Données par Usage**

| Type de Données | Storage | Performance | Consistency | Usage |
|------------------|---------|-------------|-------------|-------|
| **Policies & Permissions** | PostgreSQL | 10ms | Strong | RBAC/ABAC rules |
| **User Relations** | Neo4j | 50ms | Eventual | ReBAC graph traversal |
| **Cache Permissions** | Redis | 1ms | Eventual | Hot path optimization |
| **Audit Logs** | Elasticsearch | 100ms | Eventual | Compliance & analytics |
| **Configuration** | PostgreSQL | 10ms | Strong | Tenant settings |
| **Sessions** | Redis | 1ms | Eventual | JWT cache & rate limit |

---

## 🏛 Modèle de Données Core

### **1. Entités Principales**

#### **Tenant (Multi-Tenancy)**
```sql
-- Table principale pour isolation
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    subdomain VARCHAR(100) UNIQUE,
    plan_type VARCHAR(50) DEFAULT 'FREE',
    status VARCHAR(20) DEFAULT 'ACTIVE',
    
    -- Configuration par tenant
    max_users INTEGER DEFAULT 100,
    max_roles INTEGER DEFAULT 50,
    max_policies INTEGER DEFAULT 100,
    
    -- Features enablement
    features JSONB DEFAULT '{}',
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- RGPD compliance
    data_residency VARCHAR(10) DEFAULT 'EU',
    retention_policy_days INTEGER DEFAULT 2555 -- 7 years
);

-- Index pour performance
CREATE INDEX idx_tenants_subdomain ON tenants(subdomain);
CREATE INDEX idx_tenants_status ON tenants(status) WHERE status = 'ACTIVE';
```

#### **Users & Identity**
```sql
-- Utilisateurs avec support multi-tenant
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    
    -- Identity
    email VARCHAR(320) NOT NULL, -- RFC 5321 max length
    external_id VARCHAR(255), -- SSO integration
    auth_provider VARCHAR(50) DEFAULT 'LOCAL',
    
    -- Profile
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    display_name VARCHAR(200),
    
    -- Status
    status VARCHAR(20) DEFAULT 'ACTIVE',
    email_verified BOOLEAN DEFAULT FALSE,
    last_login_at TIMESTAMP,
    
    -- Audit
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    
    UNIQUE(tenant_id, email)
);

-- RLS Policy pour isolation
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON users 
FOR ALL 
USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

-- Indexes optimisés
CREATE INDEX idx_users_tenant_email ON users(tenant_id, email);
CREATE INDEX idx_users_external_id ON users(external_id) WHERE external_id IS NOT NULL;
CREATE INDEX idx_users_status ON users(tenant_id, status) WHERE status = 'ACTIVE';
```

#### **Roles & Permissions (RBAC)**
```sql
-- Rôles avec hiérarchie
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    
    -- Definition
    name VARCHAR(100) NOT NULL,
    description TEXT,
    parent_role_id UUID REFERENCES roles(id), -- Hiérarchie
    
    -- Metadata
    is_system_role BOOLEAN DEFAULT FALSE,
    is_default_role BOOLEAN DEFAULT FALSE,
    
    -- Audit
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    
    UNIQUE(tenant_id, name)
);

-- Permissions granulaires
CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    
    -- Permission definition
    resource VARCHAR(100) NOT NULL, -- ex: 'document', 'user', 'policy'
    action VARCHAR(100) NOT NULL,   -- ex: 'read', 'write', 'delete', '*'
    
    -- Optional conditions (ABAC)
    conditions JSONB DEFAULT '{}',
    
    -- Metadata
    description TEXT,
    is_system_permission BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(tenant_id, resource, action)
);

-- Association rôles <-> permissions
CREATE TABLE role_permissions (
    role_id UUID REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID REFERENCES permissions(id) ON DELETE CASCADE,
    
    -- Grant metadata
    granted_at TIMESTAMP DEFAULT NOW(),
    granted_by UUID REFERENCES users(id),
    
    -- Conditional grants
    conditions JSONB DEFAULT '{}',
    expires_at TIMESTAMP,
    
    PRIMARY KEY (role_id, permission_id)
);

-- Association users <-> roles
CREATE TABLE user_roles (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID REFERENCES roles(id) ON DELETE CASCADE,
    
    -- Assignment metadata
    assigned_at TIMESTAMP DEFAULT NOW(),
    assigned_by UUID REFERENCES users(id),
    expires_at TIMESTAMP,
    
    -- Context-based assignment (ABAC)
    context JSONB DEFAULT '{}',
    
    PRIMARY KEY (user_id, role_id)
);
```

### **2. Policies Avancées (ABAC)**

#### **Policy Engine**
```sql
-- Policies pour ABAC complex rules
CREATE TABLE policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    
    -- Policy definition
    name VARCHAR(200) NOT NULL,
    description TEXT,
    version VARCHAR(20) DEFAULT '1.0',
    
    -- Rule definition
    rule_type VARCHAR(20) DEFAULT 'ABAC', -- RBAC, ABAC, ReBAC
    rule_content JSONB NOT NULL, -- OPA Rego or JSON rules
    
    -- Status
    status VARCHAR(20) DEFAULT 'DRAFT', -- DRAFT, ACTIVE, DEPRECATED
    priority INTEGER DEFAULT 100,
    
    -- Audit
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    
    UNIQUE(tenant_id, name, version)
);

-- Policy bindings (qui utilise quoi)
CREATE TABLE policy_bindings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    
    policy_id UUID REFERENCES policies(id) ON DELETE CASCADE,
    
    -- Binding target
    subject_type VARCHAR(20) NOT NULL, -- 'user', 'role', 'group'
    subject_id UUID NOT NULL,
    
    -- Resource scope
    resource_type VARCHAR(100),
    resource_id UUID,
    resource_pattern VARCHAR(200), -- ex: 'project:*/documents'
    
    -- Conditions
    conditions JSONB DEFAULT '{}',
    
    created_at TIMESTAMP DEFAULT NOW(),
    created_by UUID REFERENCES users(id)
);
```

### **3. Relations Graphe (ReBAC)**

#### **Neo4j Schema pour Relations**
```cypher
// Nodes principaux
CREATE CONSTRAINT tenant_id FOR (t:Tenant) REQUIRE t.id IS UNIQUE;
CREATE CONSTRAINT user_id FOR (u:User) REQUIRE u.id IS UNIQUE;
CREATE CONSTRAINT resource_id FOR (r:Resource) REQUIRE r.id IS UNIQUE;
CREATE CONSTRAINT group_id FOR (g:Group) REQUIRE g.id IS UNIQUE;

// Relations de base
(:User)-[:MEMBER_OF]->(:Group)
(:User)-[:OWNS]->(:Resource)
(:Group)-[:HAS_PERMISSION]->(:Resource)
(:Resource)-[:PARENT_OF]->(:Resource) // Hiérarchie
(:User)-[:MANAGES]->(:User) // Relations managériales

// Relations ReBAC complexes
(:User)-[:CAN_ACCESS {conditions: {...}}]->(:Resource)
(:Group)-[:INHERITS_FROM]->(:Group)
(:Resource)-[:LOCATED_IN]->(:Resource) // ex: doc in folder

// Exemple de requête ReBAC
MATCH (u:User {id: $userId, tenant_id: $tenantId})
-[:MEMBER_OF*0..3]->(g:Group)
-[:HAS_PERMISSION]->(r:Resource {id: $resourceId})
WHERE u.tenant_id = $tenantId
RETURN count(r) > 0 as hasAccess
```

---

## 🏢 Multi-Tenancy Strategy

### **1. Row-Level Security (RLS)**

#### **Configuration PostgreSQL**
```sql
-- Enable RLS sur toutes les tables tenant-aware
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE policies ENABLE ROW LEVEL SECURITY;

-- Policy universelle d'isolation
CREATE OR REPLACE FUNCTION current_tenant_id() 
RETURNS UUID AS $$
BEGIN
    RETURN current_setting('app.current_tenant_id', true)::UUID;
END;
$$ LANGUAGE plpgsql STABLE;

-- Template de policy RLS
CREATE POLICY tenant_isolation ON {table_name}
FOR ALL 
TO application_role
USING (tenant_id = current_tenant_id());
```

#### **Spring Boot Configuration**
```java
@Component
public class TenantDataSourceConfig {
    
    @EventListener
    public void handleTenantSet(TenantContextEvent event) {
        // Set PostgreSQL session variable
        jdbcTemplate.execute(
            "SET app.current_tenant_id = '" + event.getTenantId() + "'"
        );
    }
    
    @PreDestroy
    public void cleanup() {
        jdbcTemplate.execute("RESET app.current_tenant_id");
    }
}
```

### **2. Validation Multi-Tenant**

#### **Entity Validation**
```java
@Entity
@Table(name = "users")
public class User {
    
    @Id
    private UUID id;
    
    @Column(name = "tenant_id", nullable = false)
    private UUID tenantId;
    
    // Validation automatique tenant
    @PrePersist
    @PreUpdate
    public void validateTenant() {
        UUID currentTenant = TenantContext.getCurrentTenantId();
        if (!Objects.equals(this.tenantId, currentTenant)) {
            throw new SecurityException("Tenant isolation violation");
        }
    }
}
```

---

## ⚡ Stratégies de Cache

### **1. Cache Hiérarchique (L1/L2/L3)**

#### **Configuration Multi-Level**
```java
@Configuration
public class CacheConfig {
    
    // L1: Local in-memory (Caffeine)
    @Bean
    public CacheManager l1CacheManager() {
        CaffeineCacheManager manager = new CaffeineCacheManager();
        manager.setCaffeine(Caffeine.newBuilder()
            .maximumSize(10_000)
            .expireAfterWrite(5, TimeUnit.MINUTES)
            .recordStats());
        return manager;
    }
    
    // L2: Distributed (Redis)
    @Bean
    public CacheManager l2CacheManager() {
        RedisCacheManager.Builder builder = RedisCacheManager
            .RedisCacheManagerBuilder
            .fromConnectionFactory(redisConnectionFactory())
            .cacheDefaults(cacheConfiguration());
        return builder.build();
    }
}
```

#### **Cache Patterns par Type de Données**
```java
public class CachePatterns {
    
    // Pattern 1: Permission cache (hot path)
    // TTL: 5 minutes, Size: élevé
    @Cacheable(value = "permissions", key = "#tenantId + ':' + #userId + ':' + #resource")
    public Set<String> getUserPermissions(String tenantId, String userId, String resource) {
        return permissionService.loadFromDatabase(tenantId, userId, resource);
    }
    
    // Pattern 2: Policy cache (warm path)  
    // TTL: 30 minutes, Size: moyen
    @Cacheable(value = "policies", key = "#tenantId + ':' + #policyId")
    public Policy getPolicy(String tenantId, String policyId) {
        return policyRepository.findByTenantAndId(tenantId, policyId);
    }
    
    // Pattern 3: User profile cache (cold path)
    // TTL: 1 heure, Size: faible
    @Cacheable(value = "users", key = "#tenantId + ':' + #userId")
    public User getUser(String tenantId, String userId) {
        return userRepository.findByTenantAndId(tenantId, userId);
    }
}
```

### **2. Cache Invalidation Strategy**

#### **Event-Based Invalidation**
```java
@Component
public class CacheInvalidationService {
    
    @EventListener
    @Async
    public void handlePolicyUpdate(PolicyUpdatedEvent event) {
        // Invalidate L1 cache
        l1CacheManager.getCache("policies").evict(
            event.getTenantId() + ":" + event.getPolicyId()
        );
        
        // Broadcast L2 cache invalidation via Redis Pub/Sub
        redisTemplate.convertAndSend(
            "cache:invalidation", 
            new CacheInvalidationMessage(
                "policies", 
                event.getTenantId() + ":" + event.getPolicyId()
            )
        );
        
        // Invalidate related permission caches
        invalidateRelatedPermissions(event.getTenantId(), event.getPolicyId());
    }
}
```

### **3. Cache Pre-warming**

#### **Startup Cache Loading**
```java
@Component
public class CacheWarmupService {
    
    @EventListener(ApplicationReadyEvent.class)
    public void warmupCache() {
        // Load hot tenants data
        List<String> activeTenants = tenantService.getActiveTenantIds();
        
        activeTenants.parallelStream()
            .limit(100) // Top 100 active tenants
            .forEach(this::warmupTenantData);
    }
    
    private void warmupTenantData(String tenantId) {
        // Pre-load common permissions
        List<String> commonUsers = userService.getMostActiveUsers(tenantId, 50);
        commonUsers.forEach(userId -> 
            permissionService.getUserPermissions(tenantId, userId, "*")
        );
        
        // Pre-load active policies
        policyService.getActivePolicies(tenantId);
    }
}
```

---

## ⚡ Performance et Optimisation

### **1. Database Optimization**

#### **Indexes Stratégiques**
```sql
-- Composite indexes pour queries fréquentes
CREATE INDEX CONCURRENTLY idx_user_roles_lookup 
ON user_roles(user_id, role_id) 
WHERE expires_at IS NULL OR expires_at > NOW();

CREATE INDEX CONCURRENTLY idx_role_permissions_active 
ON role_permissions(role_id, permission_id)
WHERE expires_at IS NULL OR expires_at > NOW();

-- Partial indexes pour status actifs
CREATE INDEX CONCURRENTLY idx_users_active 
ON users(tenant_id, id) 
WHERE status = 'ACTIVE';

-- Index pour queries temporelles
CREATE INDEX CONCURRENTLY idx_audit_logs_time_tenant 
ON audit_logs(tenant_id, created_at DESC);

-- Index GIN pour JSONB
CREATE INDEX CONCURRENTLY idx_policies_rule_content 
ON policies USING GIN(rule_content);
```

#### **Query Optimization**
```java
// Repository optimisé avec batch loading
@Repository
public interface UserPermissionRepository extends JpaRepository<UserPermission, UUID> {
    
    // Batch query pour éviter N+1 problem
    @Query("""
        SELECT ur.user.id, p.resource, p.action
        FROM UserRole ur 
        JOIN ur.role.permissions rp 
        JOIN rp.permission p
        WHERE ur.user.id IN :userIds 
        AND ur.user.tenantId = :tenantId
        AND (ur.expiresAt IS NULL OR ur.expiresAt > :now)
        """)
    List<UserPermissionProjection> findPermissionsByUsersAndTenant(
        @Param("userIds") List<UUID> userIds,
        @Param("tenantId") UUID tenantId,
        @Param("now") Instant now
    );
    
    // Query avec pagination pour gros datasets
    @Query("""
        SELECT u FROM User u 
        WHERE u.tenantId = :tenantId 
        AND u.status = 'ACTIVE'
        ORDER BY u.lastLoginAt DESC
        """)
    Page<User> findActiveUsersByTenant(
        @Param("tenantId") UUID tenantId,
        Pageable pageable
    );
}
```

### **2. Connection Pooling**

#### **HikariCP Configuration**
```yaml
spring:
  datasource:
    primary:
      hikari:
        maximum-pool-size: 20
        minimum-idle: 5
        connection-timeout: 30000
        idle-timeout: 300000
        max-lifetime: 1800000
        pool-name: "AccessWeaver-Primary"
        
    replica:
      hikari:
        maximum-pool-size: 15
        minimum-idle: 3
        read-only: true
        pool-name: "AccessWeaver-Replica"
```

---

## 🔐 Sécurité des Données

### **1. Encryption Strategy**

#### **At-Rest Encryption**
```sql
-- Encryption pour colonnes sensibles
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Fonction d'encryption déterministe pour search
CREATE OR REPLACE FUNCTION encrypt_email(email TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN encode(hmac(email, current_setting('app.encryption_key'), 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Table avec données chiffrées
CREATE TABLE user_pii (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    tenant_id UUID NOT NULL,
    
    -- Données chiffrées
    email_encrypted BYTEA NOT NULL,
    email_hash TEXT NOT NULL, -- Pour recherche
    phone_encrypted BYTEA,
    
    -- Données RGPD
    consent_given BOOLEAN DEFAULT FALSE,
    data_retention_until DATE,
    
    created_at TIMESTAMP DEFAULT NOW()
);
```

#### **Application-Level Encryption**
```java
@Component
public class DataEncryptionService {
    
    private final AESUtil aesUtil;
    
    @Value("${app.encryption.key}")
    private String encryptionKey;
    
    public String encryptSensitiveData(String data, String tenantId) {
        // Use tenant-specific salt
        String salt = generateTenantSalt(tenantId);
        return aesUtil.encrypt(data, encryptionKey + salt);
    }
    
    public String decryptSensitiveData(String encryptedData, String tenantId) {
        String salt = generateTenantSalt(tenantId);
        return aesUtil.decrypt(encryptedData, encryptionKey + salt);
    }
}
```

### **2. RGPD Compliance**

#### **Data Retention & Right to be Forgotten**
```java
@Service
public class GdprComplianceService {
    
    @Scheduled(cron = "0 2 * * * *") // Daily at 2 AM
    public void processDataRetention() {
        List<UUID> expiredUsers = userRepository.findUsersWithExpiredRetention();
        
        expiredUsers.forEach(this::anonymizeUserData);
    }
    
    private void anonymizeUserData(UUID userId) {
        // 1. Anonymize user profile
        User user = userRepository.findById(userId);
        user.setEmail("anonymized-" + userId + "@deleted.local");
        user.setFirstName("DELETED");
        user.setLastName("USER");
        user.setStatus("ANONYMIZED");
        
        // 2. Remove PII data
        userPiiRepository.deleteByUserId(userId);
        
        // 3. Keep audit trail but anonymize
        auditLogRepository.anonymizeUserLogs(userId);
        
        // 4. Remove from external systems
        externalSystemService.removeUser(userId);
    }
}
```

---

## 💾 Backup et Recovery

### **1. Backup Strategy**

#### **PostgreSQL Automated Backups**
```bash
#!/bin/bash
# Automated backup script

TENANT_ID=$1
BACKUP_TYPE=${2:-incremental} # full|incremental

# Full backup
if [ "$BACKUP_TYPE" = "full" ]; then
    pg_dump \
        --host=$DB_HOST \
        --port=5432 \
        --username=$DB_USER \
        --format=custom \
        --compress=9 \
        --file="backup-$(date +%Y%m%d-%H%M)-full.dump" \
        $DB_NAME
fi

# Incremental backup via WAL archiving
if [ "$BACKUP_TYPE" = "incremental" ]; then
    # Archive WAL files to S3
    aws s3 sync /var/lib/postgresql/archive/ s3://accessweaver-backups/wal/
fi
```

#### **Point-in-Time Recovery**
```sql
-- Enable continuous archiving
ALTER SYSTEM SET wal_level = 'replica';
ALTER SYSTEM SET archive_mode = 'on';
ALTER SYSTEM SET archive_command = 'aws s3 cp %p s3://accessweaver-backups/wal/%f';
SELECT pg_reload_conf();

-- Create base backup
SELECT pg_start_backup('base-backup-' || now()::text);
-- Copy data directory to backup location
SELECT pg_stop_backup();
```

### **2. Disaster Recovery**

#### **Multi-Region Replication**
```yaml
# RDS Cross-Region Read Replica
aws rds create-db-instance-read-replica \
  --db-instance-identifier accessweaver-replica-eu-central-1 \
  --source-db-instance-identifier accessweaver-primary-eu-west-1 \
  --db-instance-class db.r6g.large
```

### **3. Data Migration Tools**

#### **Tenant Data Export/Import**
```java
@Service
public class TenantMigrationService {
    
    public void exportTenantData(UUID tenantId, OutputStream output) {
        try (JsonGenerator json = jsonFactory.createGenerator(output)) {
            json.writeStartObject();
            
            // Export tenant config
            json.writeObjectField("tenant", tenantRepository.findById(tenantId));
            
            // Export users
            json.writeArrayFieldStart("users");
            userRepository.findByTenantId(tenantId).forEach(user -> {
                writeJson(json, user);
            });
            json.writeEndArray();
            
            // Export roles & permissions
            exportRolesAndPermissions(json, tenantId);
            
            // Export policies
            exportPolicies(json, tenantId);
            
            json.writeEndObject();
        }
    }
    
    @Transactional
    public void importTenantData(UUID newTenantId, InputStream input) {
        JsonNode data = objectMapper.readTree(input);
        
        // Import in correct order due to foreign keys
        importTenant(newTenantId, data.get("tenant"));
        importUsers(newTenantId, data.get("users"));
        importRolesAndPermissions(newTenantId, data);
        importPolicies(newTenantId, data.get("policies"));
    }
}
```

---

## 📊 Monitoring des Données

### **1. Database Health Metrics**
```java
@Component
public class DatabaseMetrics {
    
    private final MeterRegistry meterRegistry;
    private final JdbcTemplate jdbcTemplate;
    
    @Scheduled(fixedDelay = 60000) // Every minute
    public void collectDatabaseMetrics() {
        // Connection pool metrics
        Gauge.builder("database.connections.active")
            .register(meterRegistry, this::getActiveConnections);
            
        // Query performance
        Timer.Sample sample = Timer.start(meterRegistry);
        long slowQueries = jdbcTemplate.queryForObject(
            "SELECT count(*) FROM pg_stat_statements WHERE mean_time > 1000", 
            Long.class
        );
        sample.stop(Timer.builder("database.slow_queries").register(meterRegistry));
        
        // Tenant-specific metrics
        List<TenantStats> stats = getTenantStats();
        stats.forEach(stat -> {
            Gauge.builder("tenant.users.count")
                .tag("tenant_id", stat.getTenantId())
                .register(meterRegistry, () -> stat.getUserCount());
        });
    }
}
```

---

**🎯 Architecture données AccessWeaver complète !**

Cette architecture garantit **performance**, **sécurité**, **conformité RGPD** et **scalabilité** pour gérer efficacement les autorisations dans un environnement multi-tenant enterprise.