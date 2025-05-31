# 🗄️ Module RDS PostgreSQL - AccessWeaver

Module Terraform optimisé pour déployer PostgreSQL 15 sur AWS RDS avec support multi-tenancy via Row-Level Security (RLS).

## 🎯 Fonctionnalités

### ✅ Multi-Tenancy Natif
- **Row-Level Security (RLS)** activé par défaut
- **Isolation hermétique** des données par tenant
- **Parameter group optimisé** pour les performances multi-tenant

### ✅ Haute Disponibilité
- **Multi-AZ** automatique en staging/prod
- **Read Replicas** pour la scalabilité des lectures
- **Backups automatiques** avec rétention configurable
- **Point-in-time recovery** jusqu'à 35 jours

### ✅ Sécurité Enterprise
- **Chiffrement at-rest** avec KMS
- **Chiffrement in-transit** obligatoire (SSL/TLS)
- **Security Groups** restrictifs
- **Déploiement dans subnets privés** uniquement

### ✅ Monitoring Proactif
- **CloudWatch Alarms** pour CPU et connexions
- **Enhanced Monitoring** en production
- **Performance Insights** activé en production
- **Slow query logging** configuré

### ✅ Configuration Adaptive
- **Ressources** adaptées selon l'environnement (dev/staging/prod)
- **Paramètres PostgreSQL** optimisés par environnement
- **Coûts maîtrisés** avec auto-scaling du storage

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Applications                         │
│              (ECS Services)                             │
└─────────────────────┬───────────────────────────────────┘
                      │ Port 5432 (SSL only)
┌─────────────────────┴───────────────────────────────────┐
│                Security Group                           │
│            (Accès ECS uniquement)                       │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                 RDS PostgreSQL 15                       │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │   Primary   │  │ Read Replica│  │   Backups   │      │
│  │   (Multi-AZ)│  │ (Staging+)  │  │ (Point-in-  │      │
│  │             │  │             │  │    time)    │      │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
└─────────────────────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│              Private Subnets                            │
│             (Multi-AZ deployment)                       │
└─────────────────────────────────────────────────────────┘
```

## 🚀 Utilisation

### Configuration de base

```hcl
module "rds" {
  source = "../../modules/rds"
  
  # Configuration obligatoire
  project_name           = "accessweaver"
  environment           = "dev"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  allowed_security_groups = [module.ecs.security_group_id]
  
  # Configuration optionnelle
  database_name         = "accessweaver"
  master_username       = "postgres"
  sns_topic_arn        = aws_sns_topic.alerts.arn
}
```

### Configuration avancée

```hcl
module "rds" {
  source = "../../modules/rds"
  
  project_name           = "accessweaver"
  environment           = "prod"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  allowed_security_groups = [module.ecs.security_group_id]
  
  # Customisation pour production
  instance_class_override = "db.r6g.xlarge"
  allocated_storage_override = 200
  backup_retention_period_override = 30
  
  # Paramètres PostgreSQL additionnels
  custom_parameter_group_parameters = [
    {
      name  = "max_connections"
      value = "500"
    },
    {
      name  = "shared_preload_libraries"
      value = "pg_stat_statements,auto_explain,pg_hint_plan"
    }
  ]
  
  # Tags additionnels
  additional_tags = {
    CostCenter = "Engineering"
    Owner      = "Platform Team"
  }
}
```

## 📊 Configurations par Environnement

| Paramètre | Dev | Staging | Production |
|-----------|-----|---------|------------|
| **Instance** | db.t3.micro | db.t3.small | db.r6g.large |
| **Storage** | 20 GB | 50 GB | 100 GB |
| **Multi-AZ** | ❌ | ✅ | ✅ |
| **Read Replica** | ❌ | ✅ | ✅ |
| **Backup Retention** | 1 jour | 7 jours | 30 jours |
| **Enhanced Monitoring** | ❌ | ❌ | ✅ |
| **Performance Insights** | ❌ | ❌ | ✅ |
| **Deletion Protection** | ❌ | ❌ | ✅ |
| **Coût estimé/mois** | ~$25 | ~$100 | ~$250 |

## 🔌 Intégration Spring Boot

### Configuration application.yml

Le module génère automatiquement la configuration Spring Boot :

```yaml
# Récupérer via : terraform output application_yml_config
spring:
  datasource:
    primary:
      url: jdbc:postgresql://accessweaver-prod-postgres.xyz.eu-west-1.rds.amazonaws.com:5432/accessweaver
      username: postgres
      password: ${DB_PASSWORD}
      driver-class-name: org.postgresql.Driver
      hikari:
        maximum-pool-size: 20
        connection-timeout: 30000
    replica:
      url: jdbc:postgresql://accessweaver-prod-postgres-replica.xyz.eu-west-1.rds.amazonaws.com:5432/accessweaver
      username: postgres
      password: ${DB_PASSWORD}
```

### Configuration Multi-DataSource

```java
@Configuration
@EnableJpaRepositories
public class DatabaseConfig {
    
    @Primary
    @Bean(name = "primaryDataSource")
    @ConfigurationProperties("spring.datasource.primary")
    public DataSource primaryDataSource() {
        return DataSourceBuilder.create().build();
    }
    
    @Bean(name = "replicaDataSource")
    @ConfigurationProperties("spring.datasource.replica")
    public DataSource replicaDataSource() {
        return DataSourceBuilder.create().build();
    }
}
```

## 🛡 Sécurité Multi-Tenant

### Row-Level Security (RLS)

Le module active automatiquement RLS avec la configuration optimale :

```sql
-- Configuration automatique via parameter group
SET row_security = on;

-- Exemple de policy RLS (à implémenter dans votre application)
CREATE POLICY tenant_isolation ON users
FOR ALL TO application_role
USING (tenant_id = current_setting('app.current_tenant_id')::UUID);
```

### Best Practices intégrées

```java
// Configuration automatique du tenant context
@Component
public class TenantFilter implements Filter {
    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain) {
        String tenantId = extractTenantId(request);
        
        // Set PostgreSQL session variable
        jdbcTemplate.execute("SET app.current_tenant_id = '" + tenantId + "'");
        
        try {
            chain.doFilter(request, response);
        } finally {
            // Cleanup
            jdbcTemplate.execute("RESET app.current_tenant_id");
        }
    }
}
```

## 📈 Monitoring & Alertes

### CloudWatch Alarms incluses

1. **CPU Utilization** > 80% (2 périodes de 2 min)
2. **Database Connections** > seuil adapté à l'environnement
3. **Free Storage Space** < 20% (à venir)
4. **Read/Write Latency** > seuils optimaux (à venir)

### Métriques personnalisées

```sql
-- Monitoring des tenants via extensions PostgreSQL
SELECT 
    current_setting('app.current_tenant_id') as tenant_id,
    count(*) as active_connections,
    pg_database_size(current_database()) as db_size
FROM pg_stat_activity 
WHERE state = 'active';
```

## 💰 Optimisation des Coûts

### Auto-scaling du Storage
- **Croissance automatique** jusqu'à la limite configurée
- **Pas de downtime** lors de l'extension
- **Monitoring** de l'utilisation

### Stratégies par environnement
- **Dev** : Instance micro, single-AZ, backups minimaux
- **Staging** : Instance small, multi-AZ, backups courts
- **Prod** : Instance optimisée, toutes les features

### Reserved Instances (recommandé)
- **Savings jusqu'à 60%** pour les environnements stables
- **Flexible** avec la famille d'instances
- **ROI** dès 6-12 mois d'utilisation

## 🚨 Disaster Recovery

### Backups automatiques
- **Snapshots quotidiens** pendant la fenêtre définie
- **Transaction logs** pour point-in-time recovery
- **Cross-region backups** (optionnel, à configurer)

### Stratégie de restauration
```bash
# Restore point-in-time via AWS CLI
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier accessweaver-prod-postgres \
  --target-db-instance-identifier accessweaver-restore-$(date +%s) \
  --restore-time $(date -d '1 hour ago' --iso-8601)
```

## 🔧 Variables

### Variables obligatoires

| Variable | Type | Description |
|----------|------|-------------|
| `project_name` | string | Nom du projet |
| `environment` | string | Environnement (dev/staging/prod) |
| `vpc_id` | string | ID du VPC |
| `private_subnet_ids` | list(string) | IDs des subnets privés |
| `allowed_security_groups` | list(string) | Security groups autorisés |

### Variables optionnelles importantes

| Variable | Type | Défaut | Description |
|----------|------|--------|-------------|
| `master_password` | string | null (généré) | Mot de passe admin |
| `sns_topic_arn` | string | null | Topic SNS pour alertes |
| `instance_class_override` | string | null | Override type d'instance |
| `backup_retention_period_override` | number | null | Override rétention backup |

## 📤 Outputs

### Outputs principaux

| Output | Description |
|--------|-------------|
| `db_instance_endpoint` | Endpoint de connexion principal |
| `read_replica_endpoint` | Endpoint du read replica |
| `connection_string` | Chaîne JDBC complète |
| `spring_datasource_config` | Config Spring Boot |
| `application_yml_config` | Config YAML prête à copier |

### Monitoring outputs

| Output | Description |
|--------|-------------|
| `cloudwatch_alarms` | ARNs des alarmes créées |
| `estimated_monthly_cost` | Estimation des coûts |
| `performance_insights_enabled` | Status Performance Insights |

## 🛠 Dépannage

### Problèmes courants

#### 1. Connexion refusée
```bash
# Vérifier les security groups
aws ec2 describe-security-groups --group-ids sg-xxx

# Tester la connectivité depuis ECS
telnet your-db-endpoint.amazonaws.com 5432
```

#### 2. Performance dégradée
```sql
-- Vérifier les connexions actives
SELECT count(*) FROM pg_stat_activity WHERE state = 'active';

-- Top requêtes lentes
SELECT query, mean_time, calls 
FROM pg_stat_statements 
ORDER BY mean_time DESC LIMIT 10;
```

#### 3. Problèmes RLS
```sql
-- Vérifier les policies actives
SELECT * FROM pg_policies WHERE tablename = 'your_table';

-- Debug tenant context
SELECT current_setting('app.current_tenant_id', true);
```

## 🔄 Migration depuis une autre DB

### Dump & Restore
```bash
# Export depuis source
pg_dump -h source-host -U username -d dbname --schema-only > schema.sql
pg_dump -h source-host -U username -d dbname --data-only > data.sql

# Import vers RDS
psql -h your-rds-endpoint -U postgres -d accessweaver < schema.sql
psql -h your-rds-endpoint -U postgres -d accessweaver < data.sql
```

### AWS DMS (pour migrations complexes)
- **Schema Conversion Tool** pour les migrations cross-engine
- **Database Migration Service** pour les migrations avec minimal downtime
- **CDC replication** pour sync continue

## 📚 Ressources

- [PostgreSQL 15 Documentation](https://www.postgresql.org/docs/15/)
- [AWS RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [Row Level Security Guide](https://www.postgresql.org/docs/15/ddl-rowsecurity.html)
- [AccessWeaver Architecture Guide](../../docs/architecture.md)

---

**⚠️ Note importante :** Ce module crée des ressources AWS facturées. Consultez la section coûts avant déploiement.