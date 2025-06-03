# 🔐 Module Secrets Manager - AccessWeaver

Module Terraform pour la gestion centralisée et sécurisée des secrets AccessWeaver avec AWS Secrets Manager.

## 🎯 Objectifs

### ✅ Gestion Centralisée des Secrets
- **Stockage sécurisé** avec chiffrement KMS
- **Rotation automatique** des secrets critiques
- **Versioning** et historique des modifications
- **Recovery window** pour éviter les suppressions accidentelles

### ✅ Intégration Native Spring Boot
- **Configuration automatique** via Spring Cloud AWS
- **Variables d'environnement** pour ECS/Fargate
- **IAM policies** granulaires par service
- **Support multi-tenant** avec secrets isolés

### ✅ Types de Secrets Gérés
- **Database** : Credentials PostgreSQL RDS
- **Redis** : Auth token et configuration
- **JWT** : Signing secret avec rotation
- **API Keys** : Services externes (OAuth, webhooks)
- **Tenant Encryption** : Clés de chiffrement par tenant

### ✅ Sécurité Enterprise
- **Chiffrement at-rest** avec AWS KMS
- **Audit trail** complet via CloudTrail
- **Least privilege** access policies
- **Rotation automatique** en production

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────┐
│                 Applications ECS                     │
│         (Spring Boot avec AWS SDK intégré)          │
└─────────────────────┬───────────────────────────────┘
                      │ GetSecretValue API
                      │ (IAM Role + Policy)
┌─────────────────────▼───────────────────────────────┐
│            AWS Secrets Manager                      │
│                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐│
│  │  Database   │  │    Redis    │  │     JWT     ││
│  │ Credentials │  │ Auth Token  │  │   Secret    ││
│  └─────────────┘  └─────────────┘  └─────────────┘│
│                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐│
│  │  API Keys   │  │    OAuth    │  │   Tenant    ││
│  │  External   │  │   Clients   │  │ Encryption  ││
│  └─────────────┘  └─────────────┘  └─────────────┘│
│                                                     │
│  Features:                                          │
│  ✅ Encryption with KMS                             │
│  ✅ Automatic rotation (prod)                       │
│  ✅ Version history                                 │
│  ✅ Recovery window                                 │
└─────────────────────────────────────────────────────┘
                      │
                      │ KMS Encryption
                      │
┌─────────────────────▼───────────────────────────────┐
│                  AWS KMS                            │
│         (Customer Managed or AWS Managed)           │
└─────────────────────────────────────────────────────┘
```

## 🚀 Utilisation

### Configuration de base

```hcl
module "secrets" {
  source = "../../modules/secrets"
  
  # Configuration obligatoire
  project_name = "accessweaver"
  environment  = "dev"
  
  # Database secrets
  database_endpoint = module.rds.db_instance_endpoint
  database_port     = module.rds.db_instance_port
  database_name     = "accessweaver"
  database_username = "postgres"
  database_password = var.db_master_password
  
  # Redis secrets
  redis_endpoint   = module.redis.primary_endpoint
  redis_port       = module.redis.port
  redis_auth_token = var.redis_auth_token
  
  # API Keys (optionnel)
  api_keys = {
    stripe_key     = var.stripe_api_key
    sendgrid_key   = var.sendgrid_api_key
    datadog_api_key = var.datadog_api_key
  }
}
```

### Configuration avancée (Production)

```hcl
module "secrets" {
  source = "../../modules/secrets"
  
  project_name = "accessweaver"
  environment  = "prod"
  
  # Database configuration
  database_endpoint = module.rds.db_instance_endpoint
  database_port     = module.rds.db_instance_port
  database_name     = "accessweaver"
  database_username = "postgres"
  database_password = var.db_master_password
  
  # Redis configuration
  redis_endpoint    = module.redis.primary_endpoint
  redis_port        = module.redis.port
  redis_auth_token  = var.redis_auth_token
  redis_ssl_enabled = true
  
  # JWT configuration
  jwt_expiration_seconds = 3600  # 1 hour
  
  # OAuth providers
  oauth_providers = {
    google = {
      client_id     = var.google_client_id
      client_secret = var.google_client_secret
      issuer        = "https://accounts.google.com"
      scopes        = ["openid", "email", "profile"]
    }
    github = {
      client_id     = var.github_client_id
      client_secret = var.github_client_secret
      issuer        = "https://github.com"
      scopes        = ["user:email", "read:org"]
    }
  }
  
  # Secret management
  recovery_window_days = 30    # 30 days before deletion
  enable_rotation     = true   # Auto-rotation enabled
  kms_key_id         = aws_kms_key.secrets.id
  
  # Tags
  additional_tags = {
    CostCenter  = "Engineering"
    Compliance  = "GDPR"
    Criticality = "High"
  }
}
```

## 🔌 Intégration Spring Boot

### Configuration application.yml

```yaml
# Configuration AWS Secrets Manager
spring:
  config:
    import: aws-secretsmanager:accessweaver/prod/database,accessweaver/prod/redis,accessweaver/prod/jwt
  
  cloud:
    aws:
      secretsmanager:
        enabled: true
        region: eu-west-1
        
# Les secrets sont automatiquement injectés comme properties
# Exemple: ${database.password}, ${redis.auth_token}, ${jwt.secret}
```

### Configuration Java

```java
@Configuration
@EnableConfigurationProperties
public class SecretsConfig {
    
    @Value("${database.password}")
    private String databasePassword;
    
    @Value("${redis.auth_token}")
    private String redisAuthToken;
    
    @Value("${jwt.secret}")
    private String jwtSecret;
    
    @Bean
    public DataSource dataSource() {
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl("jdbc:postgresql://...");
        config.setUsername("postgres");
        config.setPassword(databasePassword); // From Secrets Manager
        return new HikariDataSource(config);
    }
    
    @Bean
    public LettuceConnectionFactory redisConnectionFactory() {
        RedisStandaloneConfiguration config = new RedisStandaloneConfiguration();
        config.setPassword(redisAuthToken); // From Secrets Manager
        return new LettuceConnectionFactory(config);
    }
}
```

### Task Definition ECS

```json
{
  "family": "accessweaver-api-gateway",
  "taskRoleArn": "arn:aws:iam::123456789012:role/accessweaver-prod-task-role",
  "executionRoleArn": "arn:aws:iam::123456789012:role/accessweaver-prod-execution-role",
  "containerDefinitions": [
    {
      "name": "aw-api-gateway",
      "image": "123456789012.dkr.ecr.eu-west-1.amazonaws.com/aw-api-gateway:latest",
      "secrets": [
        {
          "name": "DATABASE_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:eu-west-1:123456789012:secret:accessweaver/prod/database:password::"
        },
        {
          "name": "REDIS_AUTH_TOKEN",
          "valueFrom": "arn:aws:secretsmanager:eu-west-1:123456789012:secret:accessweaver/prod/redis:auth_token::"
        },
        {
          "name": "JWT_SECRET",
          "valueFrom": "arn:aws:secretsmanager:eu-west-1:123456789012:secret:accessweaver/prod/jwt:secret::"
        }
      ]
    }
  ]
}
```

## 🔄 Rotation Automatique

### Configuration Lambda de Rotation

```hcl
# Active la rotation automatique en production
enable_rotation = true

# Rotation schedule:
# - Database: tous les 30 jours
# - JWT: tous les 90 jours
# - API Keys: manuel uniquement
```

### Processus de Rotation

1. **Version AWSPENDING** créée avec nouveau secret
2. **Test** du nouveau secret
3. **Finalisation** et marquage comme AWSCURRENT
4. **Ancienne version** conservée comme AWSPREVIOUS

## 🛡 Sécurité et Conformité

### IAM Policy Exemple

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:eu-west-1:123456789012:secret:accessweaver/prod/*"
      ],
      "Condition": {
        "StringEquals": {
          "secretsmanager:ResourceTag/Environment": "prod",
          "secretsmanager:ResourceTag/Service": "accessweaver"
        }
      }
    }
  ]
}
```

### Audit et Monitoring

```bash
# Voir l'historique des accès aux secrets
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=GetSecretValue \
  --start-time 2024-01-01T00:00:00Z

# Monitoring des échecs d'accès
aws cloudwatch put-metric-alarm \
  --alarm-name "SecretAccessFailures" \
  --alarm-description "Alert on secret access failures" \
  --metric-name "UserErrors" \
  --namespace "AWS/SecretsManager" \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold
```

## 💰 Coûts

| Composant | Coût | Description |
|-----------|------|-------------|
| **Stockage** | $0.40/secret/mois | Par secret stocké |
| **API Calls** | $0.05/10k calls | GetSecretValue calls |
| **Rotation** | Lambda costs | Si rotation automatique |
| **KMS** | $1/mois + $0.03/10k ops | Si KMS custom key |

**Estimation mensuelle :**
- Dev: ~$3-5/mois (5-8 secrets)
- Staging: ~$5-8/mois (8-10 secrets)
- Prod: ~$10-15/mois (10-15 secrets + rotation)

## 🔧 Variables du Module

| Variable | Type | Défaut | Description |
|----------|------|--------|-------------|
| `project_name` | string | - | Nom du projet |
| `environment` | string | - | Environnement (dev/staging/prod) |
| `database_*` | various | - | Configuration database |
| `redis_*` | various | - | Configuration Redis |
| `jwt_secret` | string | null | JWT secret (généré si null) |
| `enable_rotation` | bool | false | Active la rotation auto |
| `recovery_window_days` | number | 7 | Délai avant suppression |

## 📤 Outputs du Module

| Output | Description |
|--------|-------------|
| `*_secret_arn` | ARNs des secrets créés |
| `*_secret_name` | Noms des secrets créés |
| `secrets_read_policy_arn` | Policy IAM pour lecture |
| `spring_boot_config` | Configuration Spring Boot |
| `environment_variables` | Variables pour ECS tasks |

## 🚨 Troubleshooting

### Secret non accessible

```bash
# Vérifier les permissions IAM
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/ecs-task-role \
  --action-names secretsmanager:GetSecretValue \
  --resource-arns arn:aws:secretsmanager:eu-west-1:123456789012:secret:accessweaver/prod/database

# Tester l'accès direct
aws secretsmanager get-secret-value \
  --secret-id accessweaver/prod/database \
  --query SecretString \
  --output text | jq .
```

### Rotation échouée

```bash
# Voir les logs Lambda
aws logs tail /aws/lambda/SecretsManagerRotation --follow

# Forcer une rotation manuelle
aws secretsmanager rotate-secret \
  --secret-id accessweaver/prod/database \
  --rotation-lambda-arn arn:aws:lambda:...
```

---

**⚠️ Note importante :** Ne jamais commiter de secrets en clair dans le code. Utilisez toujours Secrets Manager ou des variables d'environnement sécurisées.