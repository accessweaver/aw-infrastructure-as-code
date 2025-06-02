# 🛡️ Modélisation des Menaces - AccessWeaver Infrastructure

**Version :** 1.0  
**Date :** Juin 2025  
**Module :** security/threat-model  
**Responsable :** Équipe Sécurité AccessWeaver

---

## 🎯 Vue d'Ensemble

### Objectif de la Modélisation des Menaces

Ce document présente une analyse systématique des menaces de sécurité potentielles pour l'infrastructure et les applications AccessWeaver. L'objectif est d'identifier, d'évaluer et de prioriser les risques de sécurité afin de mettre en œuvre des contrôles appropriés pour les atténuer.

En tant que système d'autorisation enterprise critique, AccessWeaver doit présenter un modèle de sécurité robuste qui anticipe les diverses menaces potentielles et y répond de manière efficace.

### Méthodologie

AccessWeaver utilise une approche hybride combinant les méthodologies STRIDE, DREAD et les principes OWASP pour l'analyse des menaces :

| Méthodologie | Objectif | Application |
|--------------|----------|-------------|
| **STRIDE** | Identification des types de menaces | Catégorisation des menaces potentielles |
| **DREAD** | Évaluation quantitative des risques | Priorisation des menaces identifiées |
| **OWASP** | Bonnes pratiques spécifiques aux applications web | Implémentation des contrôles |

#### Framework STRIDE

Le modèle STRIDE identifie six catégories de menaces de sécurité :

| Catégorie | Description | Exemples pour AccessWeaver |
|-----------|-------------|---------------------------|
| **Spoofing** | Usurpation d'identité | Attaque par phishing, vol de credentials AWS |
| **Tampering** | Modification non autorisée | Altération des politiques d'autorisation |
| **Repudiation** | Déni d'avoir effectué une action | Modifications non tracées des politiques |
| **Information Disclosure** | Divulgation d'informations | Fuite de données sensibles ou de credentials |
| **Denial of Service** | Perturbation de service | Surcharge des APIs de décision |
| **Elevation of Privilege** | Élévation de privilèges | Contournement des contrôles d'accès |

#### Évaluation DREAD

Pour prioriser les menaces, nous utilisons le modèle DREAD qui évalue :

- **Damage potential** : Impact potentiel
- **Reproducibility** : Facilité de reproduction
- **Exploitability** : Niveau de compétence nécessaire pour l'exploiter
- **Affected users** : Nombre d'utilisateurs affectés
- **Discoverability** : Facilité de découverte de la vulnérabilité

Chaque facteur est noté de 1 (faible) à 10 (élevé), et la moyenne donne le score de risque global.

### Architecture Globale et Surface d'Attaque

```
┌──────────────────────────────────────────────────────────────────────┐
│                  Surface d'Attaque AccessWeaver                       │
│                                                                       │
│                   ┌─────────────────┐                                 │
│                   │  Internet       │                                 │
│                   └────────┬────────┘                                 │
│                            │                                          │
│          ┌─────────────────▼─────────────────┐                        │
│          │        AWS WAF & Shield           │◄───── Menace #1        │
│          └─────────────────┬─────────────────┘                        │
│                            │                                          │
│          ┌─────────────────▼─────────────────┐                        │
│          │     API Gateway / ALB             │◄───── Menace #2        │
│          └─────────────────┬─────────────────┘                        │
│                            │                                          │
│   ┌───────────┬────────────┴────────────┬───────────┐                 │
│   │           │                         │           │                 │
│   ▼           ▼                         ▼           ▼                 │
│┌─────────┐┌─────────┐             ┌─────────┐ ┌─────────┐             │
││Decision ││Admin    │             │Monitor  │ │Config   │             │
││APIs     ││APIs     │             │APIs     │ │APIs     │◄─── Menace #3│
│└────┬────┘└────┬────┘             └────┬────┘ └────┬────┘             │
│     │          │                       │          │                   │
│     └──────────┼───────────────────────┼──────────┘                   │
│                │                       │                              │
│         ┌──────▼───────────────────────▼──────┐                       │
│         │          Applications ECS           │◄───── Menace #4        │
│         └──────┬───────────────────────┬──────┘                       │
│                │                       │                              │
│        ┌───────▼────────┐     ┌───────▼────────┐                      │
│        │  Databases     │     │  Storage S3    │◄───── Menace #5       │
│        │  (RDS/DynamoDB)│     │                │                      │
│        └────────────────┘     └────────────────┘                      │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

## 🔍 Analyse des Menaces

### Principales Menaces Identifiées

#### 1. Attaques de la Couche Réseau et Application

| Menace | Catégorie STRIDE | Score DREAD | Description |
|--------|-----------------|-------------|-------------|
| **Attaques DDoS** | Denial of Service | 8 | Attaques volumétriques ou applicatives visant à surcharger les services AccessWeaver |
| **Injection SQL** | Tampering | 7 | Tentatives d'injection de code SQL malveillant dans les requêtes d'API |
| **XSS (Cross-Site Scripting)** | Information Disclosure | 6 | Injection de scripts côté client dans l'interface d'administration |
| **CSRF (Cross-Site Request Forgery)** | Spoofing | 5 | Forcer un utilisateur authentifié à exécuter des actions non désirées |

#### Mesures d'Atténuation

```hcl
# Configuration WAF pour protéger contre les attaques applicatives
resource "aws_wafv2_web_acl" "main" {
  name        = "accessweaver-${var.environment}-web-acl"
  description = "WAF pour la protection des APIs AccessWeaver"
  scope       = "REGIONAL"
  
  default_action {
    allow {}
  }
  
  # Règle anti-SQLi
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 10
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesSQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }
  
  # Règle anti-XSS
  rule {
    name     = "AWS-AWSManagedRulesXSSRuleSet"
    priority = 20
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesXSSRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesXSSRuleSet"
      sampled_requests_enabled   = true
    }
  }
  
  # Règle de limitation de débit
  rule {
    name     = "RateLimitRule"
    priority = 30
    
    action {
      block {}
    }
    
    statement {
      rate_based_statement {
        limit              = 3000
        aggregate_key_type = "IP"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }
  
  # Protection géographique
  rule {
    name     = "GeoBlockRule"
    priority = 40
    
    action {
      block {}
    }
    
    statement {
      geo_match_statement {
        country_codes = ["KP", "IR", "RU"]
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GeoBlockRule"
      sampled_requests_enabled   = true
    }
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-web-acl"
    Environment = var.environment
    Service     = "security"
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "accessweaver-${var.environment}-web-acl"
    sampled_requests_enabled   = true
  }
}

# Protection AWS Shield Advanced (pour environnements production)
resource "aws_shield_protection" "api_gateway" {
  count        = var.environment == "production" ? 1 : 0
  name         = "accessweaver-${var.environment}-api-protection"
  resource_arn = aws_apigatewayv2_api.main.arn
  
  tags = {
    Name        = "accessweaver-${var.environment}-api-protection"
    Environment = var.environment
    Service     = "security"
  }
}

# Protection AWS Shield Advanced pour ALB
resource "aws_shield_protection" "alb" {
  count        = var.environment == "production" ? 1 : 0
  name         = "accessweaver-${var.environment}-alb-protection"
  resource_arn = aws_lb.main.arn
  
  tags = {
    Name        = "accessweaver-${var.environment}-alb-protection"
    Environment = var.environment
    Service     = "security"
  }
}
```

#### Configuration Spring Security pour Prévention CSRF et XSS

```java
@Configuration
@EnableWebSecurity
public class WebSecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf
                .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
                .ignoringRequestMatchers("/api/public/**")
            )
            .headers(headers -> headers
                .contentSecurityPolicy("default-src 'self'; script-src 'self' https://trusted-cdn.com; object-src 'none';")
                .xssProtection(xss -> xss.block(true))
                .contentTypeOptions(contentTypeOptions -> {})
                .frameOptions(frameOptions -> frameOptions.deny())
                .referrerPolicy(referrerPolicy -> referrerPolicy.policy("same-origin"))
            )
            .authorizeHttpRequests(authorize -> authorize
                .requestMatchers("/api/public/**").permitAll()
                .anyRequest().authenticated()
            );
        
        return http.build();
    }
    
    @Bean
    public WebSecurityCustomizer webSecurityCustomizer() {
        return web -> web.ignoring().requestMatchers(
            "/css/**", "/js/**", "/images/**", "/favicon.ico"
        );
    }
}
```

#### 2. Compromission d'Identifiants et d'Accès

| Menace | Catégorie STRIDE | Score DREAD | Description |
|--------|-----------------|-------------|-------------|
| **Vol de credentials AWS** | Spoofing | 9 | Compromission des clés d'accès AWS IAM |
| **Usurpation d'API key** | Spoofing | 8 | Utilisation non autorisée des clés API de clients |
| **Session hijacking** | Spoofing | 7 | Détournement de session utilisateur actif |
| **Compromission de jeton JWT** | Spoofing | 7 | Falsification ou vol de jetons JWT |

#### Mesures d'Atténuation

```hcl
# Configuration de l'authentification API avec rotation automatique des clés
resource "aws_apigatewayv2_api_key" "clients" {
  for_each = var.api_clients
  
  name = "accessweaver-${var.environment}-${each.key}"
  
  tags = {
    Name        = "accessweaver-${var.environment}-${each.key}"
    Environment = var.environment
    Service     = "api-security"
    Client      = each.key
  }
}

# Lambda pour rotation automatique des clés API
resource "aws_lambda_function" "api_key_rotation" {
  function_name = "accessweaver-${var.environment}-api-key-rotation"
  role          = aws_iam_role.api_key_rotation.arn
  runtime       = "java21"
  handler       = "com.accessweaver.security.ApiKeyRotationHandler"
  timeout       = 300
  memory_size   = 512
  
  environment {
    variables = {
      ENVIRONMENT = var.environment
      DYNAMODB_TABLE = aws_dynamodb_table.api_keys.name
      NOTIFICATION_TOPIC = aws_sns_topic.api_notifications.arn
      ROTATION_DAYS = var.environment == "production" ? "60" : "90"
    }
  }
  
  filename         = "${path.module}/lambda/api-key-rotation.jar"
  source_code_hash = filebase64sha256("${path.module}/lambda/api-key-rotation.jar")
  
  tags = {
    Name        = "accessweaver-${var.environment}-api-key-rotation"
    Environment = var.environment
    Service     = "api-security"
  }
}

# EventBridge pour déclencher la rotation
resource "aws_cloudwatch_event_rule" "api_key_rotation" {
  name                = "accessweaver-${var.environment}-api-key-rotation"
  description         = "Déclenche la rotation des clés API"
  schedule_expression = "cron(0 0 1 * ? *)"  # Premier jour de chaque mois
  
  tags = {
    Name        = "accessweaver-${var.environment}-api-key-rotation"
    Environment = var.environment
    Service     = "api-security"
  }
}

resource "aws_cloudwatch_event_target" "api_key_rotation" {
  rule      = aws_cloudwatch_event_rule.api_key_rotation.name
  target_id = "accessweaver-${var.environment}-api-key-rotation"
  arn       = aws_lambda_function.api_key_rotation.arn
}

# AWS Cognito pour l'authentification utilisateur
resource "aws_cognito_user_pool" "main" {
  name = "accessweaver-${var.environment}-users"
  
  admin_create_user_config {
    allow_admin_create_user_only = true
    invite_message_template {
      email_message = "Votre nom d'utilisateur est {username} et votre mot de passe temporaire est {####}."
      email_subject = "Bienvenue sur AccessWeaver"
      sms_message   = "Votre nom d'utilisateur est {username} et votre mot de passe temporaire est {####}."
    }
  }
  
  auto_verified_attributes = ["email"]
  
  mfa_configuration = "OPTIONAL"
  
  software_token_mfa_configuration {
    enabled = true
  }
  
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 3
  }
  
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
  
  schema {
    name                = "email"
    attribute_data_type = "String"
    mutable             = true
    required            = true
  }
  
  device_configuration {
    challenge_required_on_new_device      = true
    device_only_remembered_on_user_prompt = true
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-users"
    Environment = var.environment
    Service     = "authentication"
  }
}

# Configuration de JWT Tokens sécurisés
resource "aws_cognito_user_pool_client" "web_client" {
  name                                 = "accessweaver-${var.environment}-web-client"
  user_pool_id                         = aws_cognito_user_pool.main.id
  generate_secret                      = true
  refresh_token_validity               = 30
  access_token_validity                = 1
  id_token_validity                    = 1
  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
  prevent_user_existence_errors        = "ENABLED"
  explicit_auth_flows                  = ["ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH"]
  
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  
  callback_urls                        = ["https://${var.domain_name}/callback", "https://${var.domain_name}/silent-refresh"]
  logout_urls                          = ["https://${var.domain_name}/logout"]
  
  read_attributes  = ["email", "email_verified", "preferred_username", "profile", "updated_at"]
  write_attributes = ["email", "preferred_username", "profile", "updated_at"]
}
```

#### Configuration de l'Authentification côté Application

```java
@Configuration
public class JwtSecurityConfig {

    @Bean
    public JwtDecoder jwtDecoder() {
        NimbusJwtDecoder jwtDecoder = JwtDecoders.fromOidcIssuerLocation(issuerUri);
        
        OAuth2TokenValidator<Jwt> withIssuer = JwtValidators.createDefaultWithIssuer(issuerUri);
        OAuth2TokenValidator<Jwt> withAudience = new DelegatingOAuth2TokenValidator<>(
            withIssuer,
            new JwtClaimValidator<List<String>>(JwtClaimNames.AUD, aud -> aud.contains(audience))
        );
        
        jwtDecoder.setJwtValidator(withAudience);
        
        return jwtDecoder;
    }
    
    @Bean
    public SessionRegistry sessionRegistry() {
        return new SessionRegistryImpl();
    }
    
    @Bean
    public HttpSessionEventPublisher httpSessionEventPublisher() {
        return new HttpSessionEventPublisher();
    }
    
    @Bean
    public HeaderWriter referrerPolicyHeaderWriter() {
        return new StaticHeadersWriter("Referrer-Policy", "strict-origin-when-cross-origin");
    }
}
```

#### Détection de Compromission de Credentials

```hcl
# Lambda pour détecter les utilisations anormales de credentials
resource "aws_lambda_function" "credential_anomaly_detector" {
  function_name = "accessweaver-${var.environment}-credential-anomaly-detector"
  role          = aws_iam_role.credential_anomaly_detector.arn
  runtime       = "java21"
  handler       = "com.accessweaver.security.CredentialAnomalyDetectorHandler"
  timeout       = 300
  memory_size   = 1024
  
  environment {
    variables = {
      CLOUDWATCH_NAMESPACE = "AccessWeaver/Security"
      SNS_TOPIC_ARN = aws_sns_topic.security_alerts.arn
      ENVIRONMENT = var.environment
      GEO_VELOCITY_THRESHOLD_KM_H = "800"  # Impossible de voyager plus vite que cela
      UNUSUAL_LOCATION_ENABLED = "true"
      UNUSUAL_TIME_ENABLED = "true"
      MAX_FAILED_ATTEMPTS = "5"
    }
  }
  
  filename         = "${path.module}/lambda/credential-anomaly-detector.jar"
  source_code_hash = filebase64sha256("${path.module}/lambda/credential-anomaly-detector.jar")
  
  tags = {
    Name        = "accessweaver-${var.environment}-credential-anomaly-detector"
    Environment = var.environment
    Service     = "security"
  }
}

# EventBridge pour analyser les événements CloudTrail
resource "aws_cloudwatch_event_rule" "credential_usage" {
  name        = "accessweaver-${var.environment}-credential-usage"
  description = "Détecte les utilisations de credentials API et console"
  
  event_pattern = jsonencode({
    source      = ["aws.signin", "aws.apigateway"],
    detail-type = ["AWS Console Sign In via CloudTrail", "AWS API Call via CloudTrail"],
    detail = {
      eventName = [
        "ConsoleLogin",
        "GetApiKey",
        "GetToken"
      ]
    }
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-credential-usage"
    Environment = var.environment
    Service     = "security"
  }
}

resource "aws_cloudwatch_event_target" "credential_usage" {
  rule      = aws_cloudwatch_event_rule.credential_usage.name
  target_id = "accessweaver-${var.environment}-credential-anomaly-detector"
  arn       = aws_lambda_function.credential_anomaly_detector.arn
}

# Alarme CloudWatch pour tentatives d'authentification échouées
resource "aws_cloudwatch_metric_alarm" "failed_auth_attempts" {
  alarm_name          = "accessweaver-${var.environment}-failed-auth-attempts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailedAuthenticationCount"
  namespace           = "AccessWeaver/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.environment == "production" ? "10" : "20"
  alarm_description   = "Cette alarme surveille les tentatives d'authentification échouées"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  
  tags = {
    Name        = "accessweaver-${var.environment}-failed-auth-attempts"
    Environment = var.environment
    Service     = "security"
  }
}
```
#### 3. Exposition de Données Sensibles

| Menace | Catégorie STRIDE | Score DREAD | Description |
|--------|-----------------|-------------|-------------|
| **Fuite de données clients** | Information Disclosure | 9 | Exposition accidentelle ou malveillante des données clients |
| **Exposition de configurations sensibles** | Information Disclosure | 8 | Divulgation de paramètres de configuration sécurisés |
| **Divulgation de secrets** | Information Disclosure | 9 | Exposition de secrets (clés, mots de passe) |
| **Exfiltration de logs** | Information Disclosure | 7 | Extraction non autorisée des journaux contenant des données sensibles |

#### Mesures d'Atténuation

```hcl
# Chiffrement des données sensibles dans DynamoDB
resource "aws_dynamodb_table" "policy_store" {
  name         = "accessweaver-${var.environment}-policy-store"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "TenantId"
  range_key    = "PolicyId"
  
  attribute {
    name = "TenantId"
    type = "S"
  }
  
  attribute {
    name = "PolicyId"
    type = "S"
  }
  
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }
  
  point_in_time_recovery {
    enabled = true
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-policy-store"
    Environment = var.environment
    Service     = "policy-management"
    DataClass   = "sensitive"
  }
}

# Isolation des secrets avec AWS Secrets Manager
resource "aws_secretsmanager_secret" "database_credentials" {
  name                    = "accessweaver/${var.environment}/database/credentials"
  description             = "Credentials pour la base de données AccessWeaver"
  kms_key_id              = aws_kms_key.secrets.id
  recovery_window_in_days = 30
  
  tags = {
    Name        = "accessweaver-${var.environment}-database-credentials"
    Environment = var.environment
    Service     = "database"
  }
}

# Prévention des fuites de données via S3
resource "aws_s3_bucket" "logs_bucket" {
  bucket = "accessweaver-${var.environment}-logs"
  
  tags = {
    Name        = "accessweaver-${var.environment}-logs"
    Environment = var.environment
    Service     = "logging"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs_encryption" {
  bucket = aws_s3_bucket.logs_bucket.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs_block_public" {
  bucket = aws_s3_bucket.logs_bucket.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs_lifecycle" {
  bucket = aws_s3_bucket.logs_bucket.id
  
  rule {
    id     = "log-expiration"
    status = "Enabled"
    
    expiration {
      days = var.environment == "production" ? 365 : 90
    }
  }
}

# AWS Macie pour la détection de données sensibles
resource "aws_macie2_account" "main" {
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                       = "ENABLED"
}

resource "aws_macie2_classification_job" "sensitive_data_discovery" {
  job_type = "SCHEDULED"
  name     = "accessweaver-${var.environment}-sensitive-data-discovery"
  
  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = [aws_s3_bucket.logs_bucket.bucket]
    }
  }
  
  schedule_frequency {
    daily_schedule = {}
  }
  
  custom_data_identifier_ids = [
    aws_macie2_custom_data_identifier.api_keys.id,
    aws_macie2_custom_data_identifier.tenant_ids.id
  ]
  
  tags = {
    Name        = "accessweaver-${var.environment}-sensitive-data-discovery"
    Environment = var.environment
    Service     = "security"
  }
}

resource "aws_macie2_custom_data_identifier" "api_keys" {
  name                   = "accessweaver-${var.environment}-api-keys"
  regex                  = "accessweaver[_|-][a-zA-Z0-9]{22}"
  description            = "Identifier pour les clés API AccessWeaver"
  maximum_match_distance = 100
  
  tags = {
    Name        = "accessweaver-${var.environment}-api-keys"
    Environment = var.environment
    Service     = "security"
  }
}

resource "aws_macie2_custom_data_identifier" "tenant_ids" {
  name                   = "accessweaver-${var.environment}-tenant-ids"
  regex                  = "tenant[_|-][a-zA-Z0-9]{16}"
  description            = "Identifier pour les IDs de tenants AccessWeaver"
  maximum_match_distance = 100
  
  tags = {
    Name        = "accessweaver-${var.environment}-tenant-ids"
    Environment = var.environment
    Service     = "security"
  }
}

# CloudWatch Logs avec filtres et masquage de données sensibles
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/accessweaver-${var.environment}-apis"
  retention_in_days = var.environment == "production" ? 365 : 90
  kms_key_id        = aws_kms_key.logs.arn
  
  tags = {
    Name        = "accessweaver-${var.environment}-api-logs"
    Environment = var.environment
    Service     = "api"
  }
}

# Lambda pour anonymiser les données sensibles dans les logs
resource "aws_lambda_function" "log_anonymizer" {
  function_name = "accessweaver-${var.environment}-log-anonymizer"
  role          = aws_iam_role.log_anonymizer.arn
  runtime       = "java21"
  handler       = "com.accessweaver.security.LogAnonymizerHandler"
  timeout       = 60
  memory_size   = 512
  
  environment {
    variables = {
      PATTERNS_TO_REDACT = "SSN,EMAIL,CREDIT_CARD,API_KEY,ACCESS_KEY"
      LOG_GROUP_NAME     = aws_cloudwatch_log_group.api_logs.name
      ENVIRONMENT        = var.environment
    }
  }
  
  filename         = "${path.module}/lambda/log-anonymizer.jar"
  source_code_hash = filebase64sha256("${path.module}/lambda/log-anonymizer.jar")
  
  tags = {
    Name        = "accessweaver-${var.environment}-log-anonymizer"
    Environment = var.environment
    Service     = "security"
  }
}

# Configuration CloudWatch Logs pour déclencher l'anonymiseur
resource "aws_cloudwatch_log_subscription_filter" "anonymizer_filter" {
  name            = "accessweaver-${var.environment}-anonymizer-filter"
  log_group_name  = aws_cloudwatch_log_group.api_logs.name
  filter_pattern  = "?ERROR ?WARN ?INFO ?DEBUG"
  destination_arn = aws_lambda_function.log_anonymizer.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_anonymizer.function_name
  principal     = "logs.${var.region}.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.api_logs.arn}:*"
}
```

#### 4. Contournement des Contrôles d'Autorisation

| Menace | Catégorie STRIDE | Score DREAD | Description |
|--------|-----------------|-------------|-------------|
| **Bypass du moteur de décision** | Elevation of Privilege | 10 | Contourner le moteur de décision d'accès pour exécuter des actions non autorisées |
| **Manipulation de politiques** | Tampering | 9 | Modification malveillante des politiques d'autorisation |
| **Horizontal privilege escalation** | Elevation of Privilege | 8 | Accès aux ressources d'autres tenants ou utilisateurs |
| **Défaut dans l'isolation multi-tenant** | Information Disclosure | 8 | Brèche dans l'isolation permettant d'accéder aux données d'autres tenants |

#### Mesures d'Atténuation

```hcl
# Isolation multi-tenant stricte pour DynamoDB
resource "aws_dynamodb_table" "tenant_policies" {
  name         = "accessweaver-${var.environment}-tenant-policies"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "TenantId"
  range_key    = "PolicyId"
  
  attribute {
    name = "TenantId"
    type = "S"
  }
  
  attribute {
    name = "PolicyId"
    type = "S"
  }
  
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }
  
  point_in_time_recovery {
    enabled = true
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-tenant-policies"
    Environment = var.environment
    Service     = "policy-management"
    DataClass   = "sensitive"
  }
}

# Validation stricte des entrées pour les APIs de décision
resource "aws_apigatewayv2_route" "decision_api" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /v1/decision"
  
  target = "integrations/${aws_apigatewayv2_integration.decision_api.id}"
  
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
  
  request_models = {
    "application/json" = aws_apigatewayv2_model.decision_request.name
  }
}

resource "aws_apigatewayv2_model" "decision_request" {
  api_id       = aws_apigatewayv2_api.main.id
  name         = "DecisionRequest"
  content_type = "application/json"
  
  schema = jsonencode({
    type = "object",
    required = ["tenant_id", "subject", "action", "resource"],
    properties = {
      tenant_id = {
        type = "string",
        pattern = "^[a-zA-Z0-9_-]{1,64}$"
      },
      subject = {
        type = "string",
        minLength = 1,
        maxLength = 256
      },
      action = {
        type = "string",
        minLength = 1,
        maxLength = 128
      },
      resource = {
        type = "string",
        minLength = 1,
        maxLength = 1024
      },
      context = {
        type = "object",
        additionalProperties = {
          type = "string"
        }
      }
    },
    additionalProperties = false
  })
}

# Validation de politiques avec AWS Lambda
resource "aws_lambda_function" "policy_validator" {
  function_name = "accessweaver-${var.environment}-policy-validator"
  role          = aws_iam_role.policy_validator.arn
  runtime       = "java21"
  handler       = "com.accessweaver.policy.PolicyValidatorHandler"
  timeout       = 30
  memory_size   = 512
  
  environment {
    variables = {
      MAX_POLICY_SIZE_KB = "128"
      ENVIRONMENT        = var.environment
      POLICY_SCHEMA_PATH = "s3://${aws_s3_bucket.config.bucket}/schemas/policy-schema.json"
    }
  }
  
  filename         = "${path.module}/lambda/policy-validator.jar"
  source_code_hash = filebase64sha256("${path.module}/lambda/policy-validator.jar")
  
  tags = {
    Name        = "accessweaver-${var.environment}-policy-validator"
    Environment = var.environment
    Service     = "policy-management"
  }
}

# Schéma JSON de validation des politiques
resource "aws_s3_object" "policy_schema" {
  bucket = aws_s3_bucket.config.id
  key    = "schemas/policy-schema.json"
  content = jsonencode({
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "required": ["version", "tenant_id", "policies"],
    "properties": {
      "version": {
        "type": "string",
        "enum": ["1.0", "1.1", "2.0"]
      },
      "tenant_id": {
        "type": "string",
        "pattern": "^[a-zA-Z0-9_-]{1,64}$"
      },
      "policies": {
        "type": "array",
        "items": {
          "type": "object",
          "required": ["id", "effect", "principals", "actions", "resources"],
          "properties": {
            "id": {
              "type": "string",
              "pattern": "^[a-zA-Z0-9_-]{1,128}$"
            },
            "effect": {
              "type": "string",
              "enum": ["allow", "deny"]
            },
            "principals": {
              "type": "array",
              "items": {
                "type": "string"
              },
              "minItems": 1
            },
            "actions": {
              "type": "array",
              "items": {
                "type": "string"
              },
              "minItems": 1
            },
            "resources": {
              "type": "array",
              "items": {
                "type": "string"
              },
              "minItems": 1
            },
            "conditions": {
              "type": "object"
            }
          }
        }
      }
    }
  })
  
  content_type = "application/json"
  
  tags = {
    Name        = "accessweaver-policy-schema"
    Environment = var.environment
    Service     = "policy-management"
  }
}

# Audit complet des modifications de politiques
resource "aws_cloudwatch_log_group" "policy_audit" {
  name              = "/aws/lambda/accessweaver-${var.environment}-policy-audit"
  retention_in_days = var.environment == "production" ? 365 : 90
  kms_key_id        = aws_kms_key.logs.arn
  
  tags = {
    Name        = "accessweaver-${var.environment}-policy-audit"
    Environment = var.environment
    Service     = "policy-management"
  }
}

resource "aws_lambda_function" "policy_audit" {
  function_name = "accessweaver-${var.environment}-policy-audit"
  role          = aws_iam_role.policy_audit.arn
  runtime       = "java21"
  handler       = "com.accessweaver.policy.PolicyAuditHandler"
  timeout       = 30
  memory_size   = 512
  
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.tenant_policies.name
      AUDIT_LOG_GROUP = aws_cloudwatch_log_group.policy_audit.name
      ENVIRONMENT     = var.environment
    }
  }
  
  filename         = "${path.module}/lambda/policy-audit.jar"
  source_code_hash = filebase64sha256("${path.module}/lambda/policy-audit.jar")
  
  tags = {
    Name        = "accessweaver-${var.environment}-policy-audit"
    Environment = var.environment
    Service     = "policy-management"
  }
}

# DynamoDB Stream pour déclencher l'audit
resource "aws_dynamodb_table" "tenant_policies_with_stream" {
  # Mise à jour de la table pour ajouter le stream
  name         = "accessweaver-${var.environment}-tenant-policies"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "TenantId"
  range_key    = "PolicyId"
  
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  
  # ... autres configurations comme ci-dessus
}

resource "aws_lambda_event_source_mapping" "policy_audit_trigger" {
  event_source_arn  = aws_dynamodb_table.tenant_policies_with_stream.stream_arn
  function_name     = aws_lambda_function.policy_audit.arn
  starting_position = "LATEST"
  
  # Ne traiter que les modifications (pas les lectures)
  filter_criteria {
    filter {
      pattern = jsonencode({
        eventName: ["INSERT", "MODIFY", "REMOVE"]
      })
    }
  }
}
```

#### Configuration de Vérification de Politiques dans Java

```java
@Service
public class PolicyValidationService {

    private final ObjectMapper objectMapper;
    private final JsonSchemaFactory schemaFactory;
    private final S3Client s3Client;
    private final String bucketName;
    private final String schemaPath;
    
    @Autowired
    public PolicyValidationService(
            ObjectMapper objectMapper,
            S3Client s3Client,
            @Value("${accessweaver.config.bucket}") String bucketName,
            @Value("${accessweaver.policy.schema-path}") String schemaPath) {
        this.objectMapper = objectMapper;
        this.schemaFactory = JsonSchemaFactory.getInstance(SpecVersion.VersionFlag.V7);
        this.s3Client = s3Client;
        this.bucketName = bucketName;
        this.schemaPath = schemaPath;
    }
    
    public ValidationResult validatePolicy(String policyJson, String tenantId) {
        try {
            // 1. Validation de base JSON Schema
            JsonNode policyNode = objectMapper.readTree(policyJson);
            JsonSchema schema = loadPolicySchema();
            Set<ValidationMessage> validationMessages = schema.validate(policyNode);
            
            if (!validationMessages.isEmpty()) {
                return new ValidationResult(false, validationMessages.stream()
                        .map(ValidationMessage::getMessage)
                        .collect(Collectors.toList()));
            }
            
            // 2. Validation de sécurité spécifique
            List<String> securityIssues = validatePolicySecurity(policyNode, tenantId);
            if (!securityIssues.isEmpty()) {
                return new ValidationResult(false, securityIssues);
            }
            
            return new ValidationResult(true, Collections.emptyList());
            
        } catch (Exception e) {
            return new ValidationResult(false, List.of("Erreur de validation: " + e.getMessage()));
        }
    }
    
    private JsonSchema loadPolicySchema() throws IOException {
        GetObjectRequest request = GetObjectRequest.builder()
                .bucket(bucketName)
                .key(schemaPath)
                .build();
                
        ResponseInputStream<GetObjectResponse> schemaStream = s3Client.getObject(request);
        String schemaJson = IOUtils.toString(schemaStream, StandardCharsets.UTF_8);
        JsonNode schemaNode = objectMapper.readTree(schemaJson);
        
        return schemaFactory.getSchema(schemaNode);
    }
    
    private List<String> validatePolicySecurity(JsonNode policyNode, String expectedTenantId) {
        List<String> issues = new ArrayList<>();
        
        // Vérification du tenant ID
        String tenantId = policyNode.get("tenant_id").asText();
        if (!tenantId.equals(expectedTenantId)) {
            issues.add("Tentative de manipulation cross-tenant détectée. Tenant ID attendu: " + 
                      expectedTenantId + ", trouvé: " + tenantId);
        }
        
        // Vérification des ressources wildcard
        JsonNode policiesNode = policyNode.get("policies");
        if (policiesNode.isArray()) {
            for (int i = 0; i < policiesNode.size(); i++) {
                JsonNode policy = policiesNode.get(i);
                JsonNode resources = policy.get("resources");
                JsonNode effect = policy.get("effect");
                
                // Vérifier les wildcard risqués dans les politiques d'autorisation
                if (effect.asText().equals("allow") && resources.isArray()) {
                    for (JsonNode resource : resources) {
                        if (resource.asText().equals("*")) {
                            issues.add("La politique " + policy.get("id").asText() + 
                                       " utilise une ressource wildcard (*) avec un effet allow");
                        }
                    }
                }
            }
        }
        
        // Vérifier les conditions complexes
        validateConditions(policyNode, issues);
        
        return issues;
    }
    
    private void validateConditions(JsonNode policyNode, List<String> issues) {
        JsonNode policiesNode = policyNode.get("policies");
        if (policiesNode.isArray()) {
            for (int i = 0; i < policiesNode.size(); i++) {
                JsonNode policy = policiesNode.get(i);
                JsonNode conditions = policy.get("conditions");
                
                if (conditions != null && conditions.size() > 10) {
                    issues.add("La politique " + policy.get("id").asText() + 
                               " contient plus de 10 conditions, ce qui peut indiquer une tentative d'exploitation");
                }
            }
        }
    }
}
```
#### 5. Menaces Liées à l'Infrastructure et aux Dépendances

| Menace | Catégorie STRIDE | Score DREAD | Description |
|--------|-----------------|-------------|-------------|
| **Vulnérabilités de dépendances** | Elevation of Privilege | 8 | Exploitation de vulnérabilités dans les bibliothèques tierces |
| **Attaques de la chaîne d'approvisionnement** | Tampering | 8 | Compromission des dépendances ou des images Docker |
| **Configuration incorrecte du cloud** | Information Disclosure | 7 | Erreurs de configuration exposant des ressources AWS |
| **Compromission des conteneurs** | Elevation of Privilege | 7 | Exploitation de conteneurs pour accéder à d'autres ressources |

#### Mesures d'Atténuation

```hcl
# Sécurisation des conteneurs et de la chaîne de déploiement
resource "aws_ecr_repository" "accessweaver" {
  name                 = "accessweaver/${var.environment}/api"
  image_tag_mutability = "IMMUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-api"
    Environment = var.environment
    Service     = "api"
  }
}

# Configuration du scan des vulnérabilités des images ECR
resource "aws_ecr_registry_scanning_configuration" "vulnerability_scanning" {
  scan_type = "ENHANCED"
  
  rule {
    scan_frequency = "CONTINUOUS_SCAN"
    repository_filter {
      filter      = "accessweaver/*"
      filter_type = "WILDCARD"
    }
  }
}

# AWS Security Hub pour la détection des mauvaises configurations
resource "aws_securityhub_account" "main" {}

resource "aws_securityhub_standards_subscription" "aws_foundational" {
  standards_arn = "arn:aws:securityhub:${var.region}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:${var.region}::standards/cis-aws-foundations-benchmark/v/1.2.0"
}

# Configuration du monitoring de Security Hub
resource "aws_cloudwatch_event_rule" "security_hub_findings" {
  name        = "accessweaver-${var.environment}-security-hub-findings"
  description = "Détecte les nouvelles découvertes Security Hub"
  
  event_pattern = jsonencode({
    source      = ["aws.securityhub"],
    detail-type = ["Security Hub Findings - Imported"],
    detail = {
      findings = {
        Severity = {
          Label = ["CRITICAL", "HIGH"]
        },
        ProductFields = {
          "aws/securityhub/ProductName" = ["Config", "GuardDuty", "IAM Access Analyzer", "Inspector", "Macie"]
        }
      }
    }
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-security-hub-findings"
    Environment = var.environment
    Service     = "security"
  }
}

resource "aws_cloudwatch_event_target" "security_findings_sns" {
  rule      = aws_cloudwatch_event_rule.security_hub_findings.name
  target_id = "SecurityHubToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}

# Vérifications proactives des mauvaises configurations via AWS Config
resource "aws_config_configuration_recorder" "main" {
  name     = "accessweaver-${var.environment}-config-recorder"
  role_arn = aws_iam_role.config_recorder.arn
  
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "accessweaver-${var.environment}-config-delivery"
  s3_bucket_name = aws_s3_bucket.config_logs.bucket
  s3_key_prefix  = "config"
  sns_topic_arn  = aws_sns_topic.config_notifications.arn
  
  snapshot_delivery_properties {
    delivery_frequency = "Six_Hours"
  }
  
  depends_on = [aws_config_configuration_recorder.main]
}

# Règles AWS Config pour la sécurité des conteneurs et des dépendances
resource "aws_config_config_rule" "ecr_scan_required" {
  name        = "accessweaver-${var.environment}-ecr-scan-required"
  description = "Vérifie que tous les référentiels ECR ont le scan à la poussée activé"
  
  source {
    owner             = "AWS"
    source_identifier = "ECR_PRIVATE_IMAGE_SCANNING_ENABLED"
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-ecr-scan-required"
    Environment = var.environment
    Service     = "security"
  }
}

resource "aws_config_config_rule" "ecs_task_definition_user" {
  name        = "accessweaver-${var.environment}-ecs-user-check"
  description = "Vérifie que les définitions de tâches ECS ne s'exécutent pas en tant que root"
  
  source {
    owner             = "AWS"
    source_identifier = "ECS_TASK_DEFINITION_USER_FOR_HOST_MODE_CHECK"
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-ecs-user-check"
    Environment = var.environment
    Service     = "security"
  }
}

# Alerte sur les images vulnérables
resource "aws_lambda_function" "ecr_vulnerability_processor" {
  function_name = "accessweaver-${var.environment}-ecr-vulnerability-processor"
  role          = aws_iam_role.ecr_vulnerability_processor.arn
  runtime       = "java21"
  handler       = "com.accessweaver.security.EcrVulnerabilityProcessorHandler"
  timeout       = 60
  memory_size   = 512
  
  environment {
    variables = {
      SNS_TOPIC_ARN        = aws_sns_topic.security_alerts.arn
      SEVERITY_THRESHOLD   = "HIGH"
      ENVIRONMENT          = var.environment
      NOTIFICATION_CHANNEL = var.slack_webhook_url
    }
  }
  
  filename         = "${path.module}/lambda/ecr-vulnerability-processor.jar"
  source_code_hash = filebase64sha256("${path.module}/lambda/ecr-vulnerability-processor.jar")
  
  tags = {
    Name        = "accessweaver-${var.environment}-ecr-vulnerability-processor"
    Environment = var.environment
    Service     = "security"
  }
}

resource "aws_cloudwatch_event_rule" "ecr_scan_finding" {
  name        = "accessweaver-${var.environment}-ecr-scan-finding"
  description = "Détecte les résultats de scan d'image ECR"
  
  event_pattern = jsonencode({
    source      = ["aws.ecr"],
    detail-type = ["ECR Image Scan"],
    detail = {
      "finding-severity-counts": {
        CRITICAL = [{ exists = true }],
        HIGH     = [{ exists = true }]
      },
      "repository-name": [{
        prefix = "accessweaver/"
      }]
    }
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-ecr-scan-finding"
    Environment = var.environment
    Service     = "security"
  }
}

resource "aws_cloudwatch_event_target" "ecr_scan_finding" {
  rule      = aws_cloudwatch_event_rule.ecr_scan_finding.name
  target_id = "accessweaver-${var.environment}-ecr-vulnerability-processor"
  arn       = aws_lambda_function.ecr_vulnerability_processor.arn
}
```

### Gestion des Dépendances dans l'Application

```java
// Exemple de configuration Maven avec plugin de vérification des dépendances
// pom.xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" 
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.accessweaver</groupId>
    <artifactId>decision-engine</artifactId>
    <version>1.0.0</version>
    
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
    </parent>
    
    <properties>
        <java.version>21</java.version>
        <maven.compiler.source>${java.version}</maven.compiler.source>
        <maven.compiler.target>${java.version}</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
    
    <dependencies>
        <!-- Spring Boot -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        
        <!-- AWS SDK -->
        <dependency>
            <groupId>software.amazon.awssdk</groupId>
            <artifactId>dynamodb-enhanced</artifactId>
            <version>2.20.156</version>
        </dependency>
        
        <!-- Tests -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
            
            <!-- Vérification des dépendances vulnérables -->
            <plugin>
                <groupId>org.owasp</groupId>
                <artifactId>dependency-check-maven</artifactId>
                <version>8.2.1</version>
                <configuration>
                    <failBuildOnCVSS>7</failBuildOnCVSS>
                    <formats>
                        <format>HTML</format>
                        <format>JSON</format>
                    </formats>
                </configuration>
                <executions>
                    <execution>
                        <goals>
                            <goal>check</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
            
            <!-- Application des mises à jour de sécurité -->
            <plugin>
                <groupId>com.github.ekryd.sortpom</groupId>
                <artifactId>sortpom-maven-plugin</artifactId>
                <version>3.0.0</version>
                <executions>
                    <execution>
                        <phase>verify</phase>
                        <goals>
                            <goal>sort</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
```

#### Dockerfile Sécurisé

```dockerfile
# Étape de construction
FROM maven:3.9-eclipse-temurin-21-alpine AS builder

WORKDIR /app
COPY pom.xml .
# Télécharger les dépendances en cache
RUN mvn dependency:go-offline -B

COPY src ./src
RUN mvn package -DskipTests

# Vérifier les vulnérabilités des dépendances
RUN mvn org.owasp:dependency-check-maven:check

# Étape d'exécution
FROM eclipse-temurin:21-jre-alpine

# Créer un utilisateur non-root
RUN addgroup -S accessweaver && adduser -S accessweaver -G accessweaver

# Variables d'environnement
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC -XX:+ExitOnOutOfMemoryError -Djava.security.egd=file:/dev/./urandom"
ENV SPRING_PROFILES_ACTIVE="production"

# Copier le jar depuis l'étape de construction
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar

# Définir les permissions
RUN chown -R accessweaver:accessweaver /app
USER accessweaver

# Vérification d'intégrité de l'application
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -q --spider http://localhost:8080/actuator/health || exit 1

# Exécuter l'application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
```

## 📊 Matrice de Risques et Priorisation

### Matrice d'Évaluation des Risques

La matrice suivante présente un résumé des menaces identifiées, triées par score DREAD :

| Menace | Type | Score DREAD | Contrôles Implémentés | Risque Résiduel |
|--------|------|-------------|------------------------|-----------------|
| Bypass du moteur de décision | Élévation de privilèges | 10 | Validation stricte des entrées, audit complet | Faible |
| Vol de credentials AWS | Usurpation | 9 | Rotation automatique, MFA, détection d'anomalies | Faible |
| Fuite de données clients | Divulgation d'information | 9 | Chiffrement, contrôles d'accès, Macie | Faible |
| Divulgation de secrets | Divulgation d'information | 9 | Secrets Manager, rotation automatique | Faible |
| Manipulation de politiques | Falsification | 9 | Validation, audit, journalisation | Faible |
| Attaques DDoS | Déni de service | 8 | AWS Shield, WAF, limitation de débit | Moyen |
| Usurpation d'API key | Usurpation | 8 | Rotation automatique, validation | Moyen |
| Horizontal privilege escalation | Élévation de privilèges | 8 | Isolation multi-tenant, validation | Faible |
| Défaut dans l'isolation multi-tenant | Divulgation d'information | 8 | Contrôles d'accès stricts, tests | Faible |
| Vulnérabilités de dépendances | Élévation de privilèges | 8 | Scans de sécurité, mise à jour auto | Moyen |
| Attaques de la chaîne d'approvisionnement | Falsification | 8 | Scans ECR, intégrité des builds | Moyen |
| Injection SQL | Falsification | 7 | WAF, paramètres préparés, ORM | Faible |
| Session hijacking | Usurpation | 7 | HTTPS, tokens JWT, invalidation | Faible |
| Compromission de jeton JWT | Usurpation | 7 | Validation, expiration courte | Faible |
| Exfiltration de logs | Divulgation d'information | 7 | Anonymisation, chiffrement | Faible |
| Configuration incorrecte du cloud | Divulgation d'information | 7 | AWS Config, Security Hub | Faible |
| Compromission des conteneurs | Élévation de privilèges | 7 | Utilisateurs non-root, isolation | Faible |
| XSS (Cross-Site Scripting) | Divulgation d'information | 6 | WAF, CSP, échappement | Faible |
| CSRF (Cross-Site Request Forgery) | Usurpation | 5 | Tokens CSRF, validation Origin | Faible |

### Heatmap des Risques

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           IMPACT POTENTIEL                               │
│         │                                                                │
│         │              Faible        Moyen         Élevé                 │
│         │                                                                │
│  Élevée │                            • Attaques DDoS                     │
│         │                            • Usurpation    • Bypass moteur     │
│PROBABILITÉ                           d'API key      • Vol credentials    │
│         │                            • Vulnérabilités• Fuite données     │
│         │                            de dépendances  • Divulgation secrets│
│         │                            • Attaques chaîne• Manipulation      │
│  Moyenne│                            d'appro.       politiques           │
│         │              • CSRF        • XSS          • Privilege          │
│         │                            • Injection SQL escalation          │
│         │                                          • Défaut isolation    │
│         │                                          • Session hijacking   │
│         │                                          • Compromission JWT   │
│  Faible │                            • Exfiltration • Mauvaise config.   │
│         │                            logs           • Compromission      │
│         │                                          conteneurs            │
└─────────────────────────────────────────────────────────────────────────┘
```

## 🔄 Processus de Revue et Mise à Jour

### Procédure de Revue

La modélisation des menaces d'AccessWeaver est un document vivant qui doit être régulièrement mis à jour en fonction de :

1. **Évolution de l'Architecture** : Tout changement majeur dans l'architecture du système.
2. **Nouvelles Vulnérabilités** : Découverte de nouvelles vulnérabilités affectant les technologies utilisées.
3. **Incidents de Sécurité** : Leçons tirées des incidents ou presque-incidents.
4. **Changements Réglementaires** : Nouvelles exigences de conformité.

Une revue complète de la modélisation des menaces est programmée :

- Trimestriellement pour une revue de routine
- Immédiatement après tout changement architectural majeur
- Après tout incident de sécurité
- Avant chaque déploiement en production d'une nouvelle fonctionnalité majeure

### Mise à Jour et Évolution des Contrôles

Le processus de mise à jour suit les étapes suivantes :

1. **Identification** : Détection de nouveaux risques ou évolution des risques existants.
2. **Évaluation** : Mise à jour du score DREAD et réévaluation de la matrice de risques.
3. **Conception** : Développement de nouveaux contrôles de sécurité.
4. **Implémentation** : Déploiement des contrôles via l'infrastructure as code.
5. **Validation** : Tests de pénétration et vérification de l'efficacité.
6. **Documentation** : Mise à jour de ce document.

## ✅ Checklist de Sécurité

### Pour les Développeurs

- [ ] Validation stricte de toutes les entrées utilisateur
- [ ] Aucune requête SQL dynamique sans paramètres préparés
- [ ] Échappement approprié de toutes les sorties pour prévenir les XSS
- [ ] Implémentation de tokens CSRF pour toutes les actions modifiant l'état
- [ ] Utilisation des dernières versions des bibliothèques et dépendances
- [ ] Validation des JWT avec les bons algorithmes et clés
- [ ] Pas de secrets hardcodés dans le code
- [ ] Journalisation appropriée sans données sensibles
- [ ] Tests de sécurité unitaires et d'intégration

### Pour les DevOps

- [ ] Images Docker sans utilisateur root
- [ ] Scan de vulnérabilités des images avant déploiement
- [ ] Tous les secrets stockés dans AWS Secrets Manager
- [ ] WAF configuré pour toutes les API publiques
- [ ] Rotation automatique des credentials configurée
- [ ] Protection DDoS activée pour les environnements de production
- [ ] Alertes configurées pour les événements de sécurité
- [ ] Chiffrement en transit et au repos pour toutes les données
- [ ] Sauvegardes chiffrées et testées régulièrement

### Pour les Architectes

- [ ] Principe du moindre privilège appliqué à tous les composants
- [ ] Isolation multi-tenant strictement testée
- [ ] Conception pour une défense en profondeur
- [ ] Plans de reprise après sinistre incluant les scénarios de sécurité
- [ ] Considération des exigences de conformité dans la conception
- [ ] Revue des flux de données pour minimiser l'exposition des données sensibles
- [ ] Ségrégation des environnements de développement, test et production

## 🏁 Conclusion

Cette modélisation des menaces présente une vision complète des risques de sécurité potentiels pour AccessWeaver et des contrôles mis en place pour les atténuer. L'approche systématique d'identification et d'évaluation des menaces, couplée à des contrôles robustes, permet de maintenir un niveau de sécurité élevé pour cette infrastructure critique.

La sécurité étant un processus continu, ce document sera régulièrement mis à jour pour refléter l'évolution du paysage des menaces et des contrôles de sécurité.

---

**Références**:
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [AWS Security Best Practices](https://aws.amazon.com/fr/architecture/security-identity-compliance/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [STRIDE Threat Model](https://docs.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats)
- [DREAD Risk Assessment Model](https://docs.microsoft.com/en-us/archive/msdn-magazine/2006/november/security-briefs-sustainable-threat-modeling)
