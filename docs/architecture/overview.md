# 🏗 Architecture Overview - AccessWeaver

Vue d'ensemble technique de l'infrastructure AccessWeaver sur AWS - Système d'autorisation enterprise open-source.

---

## 🎯 Vue d'Ensemble

AccessWeaver est une plateforme d'autorisation moderne déployée sur AWS avec une architecture microservices serverless. Le système supporte nativement le multi-tenancy et offre des performances sub-10ms pour les décisions d'autorisation.

### **Stack Technique Principal**
- **Backend** : Java 21 + Spring Boot 3.x
- **Base de données** : PostgreSQL 15 avec Row-Level Security
- **Cache** : Redis ElastiCache avec clustering
- **Infrastructure** : AWS ECS Fargate + Terraform
- **API Gateway** : Application Load Balancer + WAF

---

## 🏗 Architecture Globale

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                 Route 53 + WAF                             │
│              accessweaver.com                              │
└─────────────────────┬───────────────────────────────────────┘
                      │ HTTPS + SSL Termination
┌─────────────────────▼───────────────────────────────────────┐
│              Application Load Balancer                      │
│                   Multi-AZ + HA                            │
└─────────────────────┬───────────────────────────────────────┘
                      │ Target Groups
         ┌────────────┼────────────┐
         │            │            │
┌────────▼───┐ ┌──────▼──┐ ┌───────▼────┐
│ECS Fargate │ │ECS Tasks│ │ECS Services│
│ Cluster    │ │Multi-AZ │ │Auto-Scaling│
└────────┬───┘ └──────┬──┘ └───────┬────┘
         │            │            │
         └────────────┼────────────┘
                      │ Service Discovery
┌─────────────────────▼───────────────────────────────────────┐
│                Microservices Layer                          │
│                                                             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │API Gateway  │ │PDP Service  │ │PAP Service  │           │
│  │Auth + JWT   │ │Decisions    │ │Policies     │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
│                                                             │
│  ┌─────────────┐ ┌─────────────┐                           │
│  │Tenant Svc   │ │Audit Service│                           │
│  │Multi-tenant │ │Compliance   │                           │
│  └─────────────┘ └─────────────┘                           │
└─────────────────────┬───────────────────────────────────────┘
                      │ Private Network
┌─────────────────────▼───────────────────────────────────────┐
│                  Data Layer                                 │
│                                                             │
│  ┌─────────────────┐        ┌─────────────────┐             │
│  │   PostgreSQL    │        │      Redis      │             │
│  │   Multi-AZ      │        │   ElastiCache   │             │
│  │   Row-Level     │        │   Cluster Mode  │             │
│  │   Security      │        │   Sub-1ms Cache │             │
│  └─────────────────┘        └─────────────────┘             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Composants Principaux

### **1. Point d'Entrée (Application Load Balancer)**
- **SSL/TLS Termination** avec certificats ACM
- **WAF Protection** contre OWASP Top 10
- **Multi-AZ** pour haute disponibilité
- **Health Checks** automatiques vers ECS

### **2. Couche Compute (ECS Fargate)**
- **Serverless containers** - pas de gestion d'EC2
- **Auto-scaling** basé sur CPU/mémoire
- **Service Discovery** avec AWS Cloud Map
- **Multi-AZ deployment** automatique

### **3. Microservices AccessWeaver**

| Service | Responsabilité | Port | Public |
|---------|----------------|------|--------|
| **API Gateway** | Point d'entrée + Auth JWT | 8080 | ✅ |
| **PDP Service** | Policy Decision Point | 8081 | ❌ |
| **PAP Service** | Policy Administration | 8082 | ❌ |
| **Tenant Service** | Multi-tenancy Management | 8083 | ❌ |
| **Audit Service** | Logging & Compliance | 8084 | ❌ |

### **4. Couche Data**
- **PostgreSQL** : Données principales avec RLS
- **Redis** : Cache L2 pour performances sub-ms
- **S3** : Logs, backups, artifacts

---

## 🌍 Déploiement Multi-Environnements

### **Configuration Adaptive**

| Aspect | Development | Staging | Production |
|--------|-------------|---------|------------|
| **🏗 Compute** | Single AZ, micro | Multi-AZ, small | Multi-AZ, optimized |
| **💾 Database** | t3.micro, 20GB | t3.small, 50GB | r6g.xlarge, 200GB |
| **⚡ Cache** | Single node | 2 nodes HA | Cluster 3 shards |
| **🔐 Security** | HTTP autorisé | HTTPS redirect | HTTPS only + WAF |
| **📊 Monitoring** | Basique | Complet | Enhanced + alerts |
| **💰 Coût/mois** | ~$95 | ~$300 | ~$900 |

### **Isolation et Sécurité**
- **VPC séparés** par environnement (10.0.x.x, 10.1.x.x, 10.2.x.x)
- **Subnets privés** pour toutes les workloads
- **Security Groups** restrictifs par service
- **Secrets Manager** pour credentials sensibles

---

## 🔄 Flux de Données

### **1. Requête d'Autorisation Typique**
```
Client → ALB → API Gateway → PDP Service → Redis Cache
                     ↓              ↓           ↓
              JWT Validation   Policy Engine   Cache Miss
                     ↓              ↓           ↓
                Response ← Policy Decision ← PostgreSQL
```

### **2. Gestion Multi-Tenant**
```
Requête avec X-Tenant-ID
        ↓
API Gateway (validation tenant)
        ↓
Tenant Context propagé
        ↓
Services (RLS automatique)
        ↓
PostgreSQL (filtrage tenant_id)
```

### **3. Cache Strategy**
- **L1 Cache** : Application (Caffeine)
- **L2 Cache** : Redis (permissions, rôles)
- **TTL Adaptatif** : 5min permissions, 30min policies
- **Invalidation** : Pub/Sub cross-services

---

## 📊 Performance & Scalabilité

### **Métriques Cibles**
- **Latence API** : < 10ms p99
- **Throughput** : 10k+ requêtes/sec
- **Disponibilité** : 99.95% SLA
- **Cache Hit Ratio** : > 90%

### **Scaling Strategy**
- **Horizontal** : Auto-scaling ECS services
- **Vertical** : Database read replicas
- **Cache** : Redis cluster sharding
- **Global** : Multi-region (roadmap)

### **Optimisations Performance**
```java
// Exemple : Cache intelligent des permissions
@Cacheable(value = "permissions", key = "#tenantId + ':' + #userId")
public Set<Permission> getUserPermissions(String tenantId, String userId) {
    return permissionRepository.findByTenantAndUser(tenantId, userId);
}

// Batch processing pour les décisions multiples
public Map<String, Boolean> checkPermissions(String tenantId, 
                                           List<PermissionCheck> checks) {
    return checks.parallelStream()
                 .collect(toMap(
                     check -> check.getKey(),
                     check -> hasPermission(tenantId, check)
                 ));
}
```

---

## 🛡 Sécurité & Compliance

### **Defense in Depth**
1. **Périmètre** : WAF + Security Groups
2. **Transport** : TLS 1.3 + Certificate Pinning
3. **Application** : JWT + RBAC/ABAC
4. **Données** : RLS + Encryption at-rest
5. **Audit** : Comprehensive logging

### **Multi-Tenant Security**
```sql
-- Row-Level Security automatique
CREATE POLICY tenant_isolation ON permissions
FOR ALL TO application_user
USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

-- Audit automatique
CREATE TRIGGER audit_trigger
BEFORE INSERT OR UPDATE OR DELETE ON permissions
FOR EACH ROW EXECUTE FUNCTION audit_changes();
```

### **Standards Compliance**
- **RGPD** : Data privacy + Right to be forgotten
- **SOC2 Type II** : Security controls + audit trail
- **ISO27001** : Information security management

---

## 🔧 Outils & Intégrations

### **Développement**
- **IDE** : IntelliJ IDEA + Spring Boot Tools
- **Local** : Docker Compose + Testcontainers
- **Tests** : JUnit 5 + Mockito + TestNG

### **CI/CD**
- **GitHub Actions** : Build + Test + Deploy
- **Docker** : Multi-stage builds optimisés
- **Terraform** : Infrastructure as Code

### **Observabilité**
- **Logs** : CloudWatch + Structured JSON
- **Metrics** : Micrometer + CloudWatch
- **Tracing** : X-Ray distribué
- **Dashboards** : Grafana + CloudWatch

---

## 🚀 Points Forts Architecture

### **✅ Avantages Techniques**
- **Serverless** : Zero infrastructure management
- **Auto-scaling** : Performance élastique
- **Multi-tenant** : Isolation native des données
- **High Performance** : Cache distribué intelligent
- **Open Source** : Pas de vendor lock-in

### **✅ Avantages Business**
- **Time-to-Market** : Déploiement en 30 minutes
- **Cost-Effective** : Pay-per-use granulaire
- **Enterprise-Ready** : Compliance et sécurité
- **Developer-Friendly** : SDK et documentation

### **⚠️ Considérations**
- **Cold Starts** : Fargate ~2s (mitigé par min capacity)
- **Vendor Lock** : AWS-specific (multi-cloud roadmap)
- **Complexity** : Microservices overhead
- **Cost** : Fargate premium vs EC2 (justifié par productivité)

---

## 📈 Roadmap Architecture

### **Version Actuelle (v1.0)**
- ✅ Microservices core sur ECS Fargate
- ✅ Multi-tenant avec PostgreSQL RLS
- ✅ Cache Redis haute performance
- ✅ Infrastructure as Code complète

### **Prochaines Versions**
- **v1.5** : Multi-region deployment
- **v2.0** : Event-driven architecture (EventBridge)
- **v2.5** : Machine Learning pour policy suggestions
- **v3.0** : Edge computing support

---

Cette architecture position AccessWeaver comme une alternative moderne et scalable aux solutions propriétaires du marché, tout en maintenant l'ouverture et la flexibilité de l'open source.