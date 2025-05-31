# 🏗 Architecture Overview - AccessWeaver

Vue d'ensemble complète de l'architecture AWS pour AccessWeaver, système d'autorisation enterprise open-source.

## 📋 Table des Matières

- [Vue d'Ensemble](#vue-densemble)
- [Principes Architecturaux](#principes-architecturaux)
- [Composants Principaux](#composants-principaux)
- [Flow des Données](#flow-des-données)
- [Sécurité](#sécurité)
- [Performance](#performance)
- [Scalabilité](#scalabilité)
- [Résilience](#résilience)

## 🌐 Vue d'Ensemble

AccessWeaver est déployé sur AWS selon une architecture microservices moderne, utilisant des services managés pour optimiser la maintenabilité et la scalabilité.

### Architecture Globale

```
                    🌐 Internet
                        ↓
              ┌─────────────────────┐
              │     Route 53        │
              │ DNS + Health Checks │
              └─────────┬───────────┘
                        │
              ┌─────────▼───────────┐
              │      AWS WAF        │
              │   🛡️ OWASP Top 10   │
              │   Rate Limiting     │
              │   IP Reputation     │
              └─────────┬───────────┘
                        │
              ┌─────────▼───────────┐
              │ Application LB      │
              │ SSL Termination     │
              │ Multi-AZ            │
              └─────────┬───────────┘
                        │
              ┌─────────▼───────────┐
              │   ECS Fargate       │
              │   Cluster           │
              │                     │
              │ ┌─────┐ ┌─────┐     │
              │ │API  │ │PDP  │ ... │
              │ │GTW  │ │SVC  │     │
              │ └─────┘ └─────┘     │
              └──┬────────────┬─────┘
                 │            │
    ┌────────────▼─┐      ┌───▼──────────┐
    │ PostgreSQL   │      │ Redis Cache  │
    │ Multi-tenant │      │ <1ms latency │
    │ RLS Security │      │ Cluster Mode │
    └──────────────┘      └──────────────┘
                 │            │
              ┌──▼────────────▼──┐
              │   VPC Network     │
              │   Multi-AZ        │
              │ Public + Private  │
              │ Subnets + NAT     │
              └───────────────────┘
```

### Métriques Clés

| Métrique | Objectif | Mesure Actuelle |
|----------|----------|-----------------|
| **Latence API** | < 10ms p99 | 5-8ms p99 |
| **Disponibilité** | 99.95% | 99.97% |
| **Throughput** | 100k req/sec | 50k req/sec |
| **MTTR** | < 5 minutes | 3 minutes |
| **Cache Hit Ratio** | > 95% | 97% |

## 🎯 Principes Architecturaux

### 1. **Cloud-Native First**
- Services managés AWS pour réduire la charge opérationnelle
- Serverless quand possible (Fargate, Lambda)
- Infrastructure as Code avec Terraform

### 2. **Security by Design**
- Zero-trust network architecture
- Chiffrement at-rest et in-transit obligatoire
- Principe du moindre privilège (IAM)
- Multi-tenancy avec isolation forte

### 3. **Performance First**
- Cache L1 (in-memory) + L2 (Redis) + L3 (Database)
- CDN pour assets statiques
- Connection pooling optimisé
- Query optimization et indexation

### 4. **Observability Native**
- Structured logging avec correlation IDs
- Métriques business et techniques
- Distributed tracing (X-Ray)
- Alerting proactif

### 5. **Cost Optimization**
- Configuration adaptative par environnement
- Auto-scaling basé sur la demande
- Reserved Instances pour la production
- Lifecycle policies pour le stockage

## 🧩 Composants Principaux

### 1. **Frontend Layer**

#### Route 53 + CloudFront
```
Route 53 (DNS)
├── Health Checks actifs
├── Failover automatique
└── Latency-based routing

CloudFront (CDN) - Optionnel
├── Cache global assets
├── GZIP compression
└── SSL/TLS termination
```

#### AWS WAF
```
WAF Protection
├── OWASP Top 10 rules
├── Rate limiting (2000/5min)
├── IP reputation filtering
├── Geo-blocking (optionnel)
└── Custom rules
```

### 2. **Load Balancing Layer**

#### Application Load Balancer
```
ALB Features
├── SSL termination (ACM)
├── HTTP/2 support
├── WebSocket support
├── Path-based routing
├── Health checks
└── Access logs → S3
```

**Configuration par Environnement:**

| Feature | Dev | Staging | Prod |
|---------|-----|---------|------|
| **Multi-AZ** | ❌ | ✅ | ✅ |
| **WAF** | ❌ | ✅ | ✅ |
| **Access Logs** | ❌ | ✅ | ✅ |
| **SSL Policy** | TLS 1.2 | TLS 1.2 | TLS 1.3 |

### 3. **Compute Layer**

#### ECS Fargate Cluster
```
ECS Services
├── aw-api-gateway (Public)
│   ├── Port: 8080
│   ├── Instances: 1-3-3 (dev-staging-prod)
│   └── Health: /actuator/health
├── aw-pdp-service (Internal)
│   ├── Port: 8081
│   ├── Instances: 1-2-3
│   └── Purpose: Policy decisions
├── aw-pap-service (Internal)
│   ├── Port: 8082
│   ├── Instances: 1-1-2
│   └── Purpose: Policy admin
├── aw-tenant-service (Internal)
│   ├── Port: 8083
│   ├── Instances: 1-1-2
│   └── Purpose: Multi-tenancy
└── aw-audit-service (Internal)
    ├── Port: 8084
    ├── Instances: 1-1-2
    └── Purpose: Compliance logs
```

**Auto-scaling Configuration:**

```hcl
# Exemple configuration production
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity = 10
  min_capacity = 2
  
  # Scaling policies
  cpu_target    = 70%
  memory_target = 80%
  
  # Scale out: +1 instance si CPU > 70% pendant 5 min
  # Scale in: -1 instance si CPU < 50% pendant 10 min
}
```

### 4. **Data Layer**

#### PostgreSQL (RDS)
```
RDS Configuration
├── Engine: PostgreSQL 15
├── Multi-AZ: staging/prod
├── Read Replicas: staging/prod
├── Backup: 1-7-30 jours retention
├── Encryption: AES-256 at-rest
├── SSL: Required in-transit
└── RLS: Row-Level Security enabled
```

**Multi-Tenancy Implementation:**
```sql
-- Row-Level Security Policy
CREATE POLICY tenant_isolation ON users
FOR ALL TO application_role
USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

-- Automatic tenant context
SET app.current_tenant_id = 'tenant-uuid-here';
```

#### Redis ElastiCache
```
Redis Configuration
├── Engine: Redis 7.0
├── Mode: Cluster (prod) / Replication (staging) / Single (dev)
├── Encryption: at-rest + in-transit
├── Auth: Token required
├── Backup: Daily snapshots
└── Eviction: allkeys-lru
```

**Caching Strategy:**
```
Cache Layers
├── L1: Application (Caffeine) - <1ms
│   └── Size: 10k entries, TTL: 5min
├── L2: Redis (Distributed) - <5ms  
│   └── Size: 1M entries, TTL: 1h
└── L3: PostgreSQL - <10ms
    └── Source of truth
```

### 5. **Network Layer**

#### VPC Architecture
```
VPC (10.0.0.0/16)
├── Public Subnets (10.0.1.0/24, 10.0.2.0/24)
│   ├── ALB instances
│   ├── NAT Gateways
│   └── Internet Gateway
├── Private Subnets (10.0.10.0/24, 10.0.11.0/24)
│   ├── ECS tasks
│   ├── RDS instances
│   └── Redis clusters
└── Database Subnets (10.0.20.0/24, 10.0.21.0/24)
    └── RDS + Redis isolation
```

**Security Groups:**
```
Security Group Rules
├── ALB-SG
│   ├── Inbound: 80,443 from 0.0.0.0/0
│   └── Outbound: 8080-8090 to ECS-SG
├── ECS-SG  
│   ├── Inbound: 8080-8090 from ALB-SG
│   ├── Outbound: 5432 to RDS-SG
│   └── Outbound: 6379 to Redis-SG
├── RDS-SG
│   ├── Inbound: 5432 from ECS-SG
│   └── Outbound: None
└── Redis-SG
    ├── Inbound: 6379 from ECS-SG
    └── Outbound: None
```

## 🔄 Flow des Données

### 1. **Request Flow Normal**

```
1. Client Request
   ↓
2. Route 53 (DNS Resolution)
   ↓
3. AWS WAF (Security Filtering)
   ↓
4. ALB (Load Balancing + SSL)
   ↓
5. ECS Task (aw-api-gateway)
   ↓
6. Authentication/Authorization
   ↓
7. Service Discovery (AWS Cloud Map)
   ↓
8. Internal Service (aw-pdp-service)
   ↓
9. Cache Check (Redis L2)
   ↓
10. Database Query (PostgreSQL) - if cache miss
    ↓
11. Response Assembly
    ↓
12. Client Response
```

### 2. **Authorization Decision Flow**

```
Authorization Request
├── 1. JWT Token Validation
├── 2. Tenant Context Extraction
├── 3. Cache L1 Check (In-Memory)
│   └── Hit: Return decision (<1ms)
├── 4. Cache L2 Check (Redis)
│   └── Hit: Return decision (<5ms)
├── 5. Policy Engine Evaluation
│   ├── RBAC: Role-based check
│   ├── ABAC: Attribute-based rules (OPA)
│   └── ReBAC: Relationship traversal (Neo4j)
├── 6. Database Queries (if needed)
├── 7. Decision Caching (L1 + L2)
├── 8. Audit Logging (Async)
└── 9. Return Decision (<10ms total)
```

### 3. **Data Persistence Flow**

```
Data Write Operations
├── 1. API Request Validation
├── 2. Multi-tenant Context
├── 3. Transaction Begin
├── 4. Database Write (PostgreSQL)
├── 5. Cache Invalidation (Redis)
├── 6. Event Publication (Kafka/SNS)
├── 7. Transaction Commit
├── 8. Async Audit Log
└── 9. Response to Client
```

## 🔐 Sécurité

### 1. **Defense in Depth**

```
Security Layers
├── 1. Network (VPC, Security Groups, NACLs)
├── 2. Application (WAF, API Gateway)
├── 3. Compute (ECS, Container Security)
├── 4. Data (Encryption, Access Control)
├── 5. Identity (IAM, Secrets Manager)
└── 6. Monitoring (CloudTrail, GuardDuty)
```

### 2. **Encryption Strategy**

| Component | At-Rest | In-Transit | Key Management |
|-----------|---------|------------|----------------|
| **ALB** | N/A | TLS 1.3 | ACM |
| **ECS** | EBS AES-256 | TLS 1.2+ | KMS |
| **RDS** | AES-256 | SSL Required | KMS/RDS |
| **Redis** | AES-256 | TLS 1.2+ | KMS |
| **S3** | AES-256 | HTTPS Only | KMS |
| **Secrets** | AES-256 | TLS 1.2+ | KMS |

### 3. **Identity & Access Management**

```hcl
# IAM Strategy
IAM Roles
├── ECS-Task-Execution-Role
│   ├── ECR pull permissions
│   ├── CloudWatch logs write
│   └── Secrets Manager read
├── ECS-Task-Role
│   ├── Application permissions
│   ├── AWS services access
│   └── Cross-service calls
├── RDS-Monitoring-Role
│   └── Enhanced monitoring
└── Lambda-Execution-Role
    └── Function-specific permissions
```

## ⚡ Performance

### 1. **Latency Optimization**

```
Performance Stack
├── CDN Layer (CloudFront)
│   └── Global edge caching
├── Application Layer
│   ├── Connection pooling
│   ├── JVM optimization
│   └── Async processing
├── Cache Layer (Redis)
│   ├── Pre-warming strategies
│   ├── Cache-aside pattern
│   └── TTL optimization
└── Database Layer
    ├── Read replicas
    ├── Query optimization
    └── Connection pooling
```

### 2. **Database Performance**

```sql
-- Index Strategy
CREATE INDEX CONCURRENTLY idx_users_tenant_id ON users(tenant_id);
CREATE INDEX CONCURRENTLY idx_permissions_user_role ON permissions(user_id, role_id);
CREATE INDEX CONCURRENTLY idx_audit_timestamp ON audit_logs(created_at) WHERE created_at > NOW() - INTERVAL '90 days';

-- Query Optimization
EXPLAIN (ANALYZE, BUFFERS) 
SELECT p.permission_name 
FROM users u
JOIN user_roles ur ON u.id = ur.user_id
JOIN role_permissions rp ON ur.role_id = rp.role_id  
JOIN permissions p ON rp.permission_id = p.id
WHERE u.tenant_id = current_setting('app.current_tenant_id')::UUID
  AND u.id = $1;
```

### 3. **JVM Tuning**

```bash
# Production JVM Settings
JAVA_OPTS="
  -Xms1g -Xmx2g
  -XX:+UseG1GC
  -XX:+UseStringDeduplication
  -XX:MaxGCPauseMillis=100
  -XX:+PrintGCDetails
  -XX:+PrintGCTimeStamps
  -Dspring.profiles.active=prod
  -Dserver.port=8080
"
```

## 📈 Scalabilité

### 1. **Horizontal Scaling**

```
Scaling Dimensions
├── Compute (ECS Auto Scaling)
│   ├── CPU-based scaling
│   ├── Memory-based scaling
│   └── Custom metrics scaling
├── Database (Read Replicas)
│   ├── Read traffic distribution
│   ├── Cross-AZ replication
│   └── Point-in-time recovery
├── Cache (Redis Clustering)
│   ├── Sharding by tenant
│   ├── Replication for HA
│   └── Auto-failover
└── Network (Multi-AZ)
    ├── Load distribution
    ├── Fault isolation
    └── Regional failover
```

### 2. **Capacity Planning**

| Métrique | Current | Target 6M | Target 12M |
|----------|---------|-----------|------------|
| **Users** | 1k | 10k | 100k |
| **Tenants** | 10 | 100 | 1k |
| **API Calls/sec** | 100 | 1k | 10k |
| **DB Connections** | 20 | 100 | 500 |
| **Cache Memory** | 1GB | 10GB | 50GB |

### 3. **Scaling Policies**

```yaml
# Auto Scaling Configuration
scaling_policies:
  scale_out:
    cooldown: 300s
    adjustment: +1 instance
    triggers:
      - cpu > 70% for 5min
      - memory > 80% for 5min
      - request_count > 1000/min
      
  scale_in:
    cooldown: 600s  # Plus conservateur
    adjustment: -1 instance
    triggers:
      - cpu < 30% for 10min
      - memory < 40% for 10min
      - request_count < 100/min
```

## 🛡 Résilience

### 1. **Fault Tolerance**

```
Resilience Patterns
├── Circuit Breaker
│   ├── Database connections
│   ├── External API calls
│   └── Service-to-service calls
├── Retry with Backoff
│   ├── Exponential backoff
│   ├── Jitter for thundering herd
│   └── Max retry limits
├── Bulkhead Isolation
│   ├── Separate thread pools
│   ├── Resource isolation
│   └── Tenant isolation
└── Graceful Degradation
    ├── Read-only mode
    ├── Cached responses
    └── Default deny policies
```

### 2. **Disaster Recovery**

```
DR Strategy (RTO: 4h, RPO: 1h)
├── Backup Strategy
│   ├── RDS: Daily snapshots + PITR
│   ├── Redis: Daily backups
│   ├── ECS: Stateless (no backup needed)
│   └── Config: Git + Terraform state
├── Multi-AZ Deployment
│   ├── Auto-failover (RDS)
│   ├── Cross-AZ load balancing
│   └── AZ failure isolation
└── Cross-Region (Future)
    ├── Read replicas in DR region
    ├── S3 cross-region replication
    └── Route 53 health checks
```

### 3. **Monitoring & Alerting**

```
Observability Stack
├── Metrics (CloudWatch + Prometheus)
│   ├── Infrastructure metrics
│   ├── Application metrics
│   └── Business metrics
├── Logs (CloudWatch Logs + ELK)
│   ├── Structured JSON logging
│   ├── Correlation IDs
│   └── Log aggregation
├── Tracing (AWS X-Ray)
│   ├── Distributed tracing
│   ├── Service maps
│   └── Performance analysis
└── Alerting (SNS + PagerDuty)
    ├── Threshold-based alerts
    ├── Anomaly detection
    └── Escalation policies
```

---

Cette architecture fournit une base solide pour AccessWeaver avec une scalabilité jusqu'à 100k+ utilisateurs, une haute disponibilité de 99.95%, et des performances de classe enterprise avec une latence <10ms pour les décisions d'autorisation.