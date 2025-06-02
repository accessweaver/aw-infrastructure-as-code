# 🔌 Sécurité API - AccessWeaver Infrastructure

**Version :** 1.0  
**Date :** Juin 2025  
**Module :** security/api  
**Responsable :** Équipe Platform AccessWeaver

---

## 🎯 Vue d'Ensemble

### Objectif Principal
Ce document détaille la **stratégie de sécurité des API** implémentée dans l'infrastructure AWS d'AccessWeaver. En tant que système d'autorisation enterprise, la sécurité et l'intégrité des API d'AccessWeaver sont absolument critiques pour garantir que seules les entités autorisées peuvent demander et recevoir des décisions d'autorisation.

### Principes Fondamentaux

| Principe | Description | Implémentation |
|----------|-------------|----------------|
| **Défense en profondeur** | Multiples couches de sécurité pour la protection des API | WAF + Auth + Rate Limiting + Validations |
| **Authentification forte** | Vérification rigoureuse de l'identité des appelants | JWT, mTLS, API Keys, IAM, OAuth 2.0 |
| **Autorisation granulaire** | Contrôle précis des actions autorisées | RBAC, ABAC, Policy-based access |
| **Validations d'entrée** | Filtrage et sanitisation de toutes les entrées API | Schema validation, input sanitization |
| **Monitoring continu** | Détection d'anomalies et réponse rapide | Logging, tracing, alerting |

### Types d'API AccessWeaver

```
┌─────────────────────────────────────────────────────────────────┐
│                      APIs AccessWeaver                           │
│                                                                  │
│  ┌───────────────────┐   ┌───────────────────┐                   │
│  │ APIs Décisions    │   │ APIs Management   │                   │
│  │ d'Autorisation    │   │                   │                   │
│  └───────────────────┘   └───────────────────┘                   │
│         │                           │                            │
│         ▼                           ▼                            │
│  ┌───────────────────┐   ┌───────────────────┐                   │
│  │ - Haute           │   │ - Configuration   │                   │
│  │   Performance     │   │   des Politiques  │                   │
│  │ - Latence Critique│   │ - Administration  │                   │
│  │ - Volume Élevé    │   │ - Faible Volume   │                   │
│  └───────────────────┘   └───────────────────┘                   │
│                                                                  │
│  ┌───────────────────┐   ┌───────────────────┐                   │
│  │ APIs Monitoring   │   │ APIs Integration  │                   │
│  │                   │   │                   │                   │
│  └───────────────────┘   └───────────────────┘                   │
│         │                           │                            │
│         ▼                           ▼                            │
│  ┌───────────────────┐   ┌───────────────────┐                   │
│  │ - Télémétrie      │   │ - Webhooks        │                   │
│  │ - Alertes         │   │ - Event Streaming │                   │
│  │ - Diagnostics     │   │ - Synchronisation │                   │
│  │ - Audit Logs      │   │ - Batch Processing│                   │
│  └───────────────────┘   └───────────────────┘                   │
└─────────────────────────────────────────────────────────────────┘
```

### Modèle de Sécurité Multi-niveaux

La sécurité des API d'AccessWeaver est implémentée en couches multiples :

1. **Couche Réseau** : Sécurité au niveau infrastructure (VPC, Security Groups, NACLs)
2. **Couche Transport** : TLS 1.3+, HTTPS strict, mTLS pour communications critiques
3. **Couche Application** : WAF, authentification, autorisation, validation
4. **Couche Données** : Chiffrement, masquage des données sensibles, isolation

Cette approche garantit que la compromission d'une couche ne compromet pas l'ensemble du système.
## 🔐 Authentification et Autorisation API

AccessWeaver implémente plusieurs mécanismes d'authentification et d'autorisation pour sécuriser l'accès aux APIs.

### Méthodes d'Authentification

| Méthode | Description | Utilisation | Environnements |
|---------|-------------|-------------|----------------|
| **API Keys** | Clés statiques pour l'authentification simple | APIs intégration, faible risque | Tous |
| **JWT (RS256)** | Tokens signés avec clé asymétrique | APIs décision standard | Tous |
| **mTLS** | Authentification mutuelle TLS | Communications critiques, client-to-server | Production |
| **OAuth 2.0 / OIDC** | Délégation d'authentification | APIs management, console admin | Tous |
| **IAM SigV4** | Signature cryptographique des requêtes | Intégration avec services AWS | Tous |
| **STS Tokens** | Tokens temporaires à courte durée | Accès programmatique aux APIs | Tous |

### Cycle de Vie des Credentials

```
┌────────────────────────────────────────────────┐
│          Cycle de Vie des Credentials          │
│                                                │
│  ┌──────────┐                                  │
│  │ Création │                                  │
│  └────┬─────┘                                  │
│       │                                        │
│       ▼                                        │
│  ┌────────────┐     ┌────────────┐             │
│  │ Validation │────►│Distribution│             │
│  └────────────┘     └─────┬──────┘             │
│                           │                    │
│                           ▼                    │
│  ┌──────────┐      ┌────────────┐              │
│  │ Rotation │◄─────│ Utilisation│              │
│  └────┬─────┘      └─────┬──────┘              │
│       │                  │                     │
│       ▼                  ▼                     │
│  ┌──────────┐      ┌──────────────┐            │
│  │ Révocation│◄────┤  Monitoring  │            │
│  └────┬─────┘      └──────────────┘            │
│       │                                        │
│       ▼                                        │
│  ┌──────────┐                                  │
│  │Destruction│                                 │
│  └──────────┘                                  │
└────────────────────────────────────────────────┘
```

### Stratégie d'Autorisation des API

AccessWeaver utilise un modèle d'autorisation à plusieurs niveaux pour ses propres APIs :

#### 1. Autorisations Basées sur les Rôles (RBAC)

| Rôle | Description | APIs Accessibles | Permissions |
|------|-------------|-----------------|-------------|
| **Admin** | Administration complète | Toutes | Lecture/Écriture |
| **Operator** | Opérations et monitoring | Management, Monitoring | Lecture/Écriture limitée |
| **Auditor** | Audit et conformité | Monitoring, Audit | Lecture seule |
| **Integration** | Accès services externes | Décisions, Integration | Appel API spécifique |
| **ReadOnly** | Consultation seule | Management (GET) | Lecture seule |

#### 2. Autorisations Basées sur les Attributs (ABAC)

AccessWeaver enrichit le RBAC avec des conditions dynamiques basées sur les attributs :

```json
{
  "Version": "2023-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "api:GetDecision",
        "api:BatchGetDecisions"
      ],
      "Resource": "arn:accessweaver:api:${region}:${account}:decision/*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": [
            "192.0.2.0/24",
            "198.51.100.0/24"
          ]
        },
        "DateGreaterThan": {
          "aws:CurrentTime": "2025-01-01T00:00:00Z"
        },
        "DateLessThan": {
          "aws:CurrentTime": "2026-01-01T00:00:00Z"
        },
        "StringEquals": {
          "api:ServiceName": "${service_name}"
        }
      }
    }
  ]
}
```

#### 3. Policies Préconfigurées

AccessWeaver fournit des politiques d'accès préconfigurées pour des cas d'utilisation courants :

| Politique | Description | Cas d'Utilisation |
|-----------|-------------|------------------|
| **ReadOnlyAccess** | Lecture seule sur toutes les ressources | Observabilité, audit |
| **DecisionAPIAccess** | Accès aux API de décisions uniquement | Microservices clients |
| **EmergencyAccess** | Accès élevé temporaire | Situations d'urgence |
| **AdminConsoleAccess** | Accès à la console d'administration | Gestion des politiques |
| **MonitoringAccess** | Accès aux métriques et logs | Équipes DevOps |

#### 4. Permissions Temporelles

Les accès API peuvent être limités dans le temps pour réduire les risques :

```hcl
resource "aws_iam_role" "emergency_access" {
  name = "accessweaver-${var.environment}-emergency-access"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:role/EmergencyUser"
        }
        Condition = {
          DateGreaterThan = {
            "aws:CurrentTime" = "2025-01-01T00:00:00Z"
          }
          DateLessThan = {
            "aws:CurrentTime" = "2025-01-01T04:00:00Z"
          }
        }
      }
    ]
  })
}
```
## 🔍 Protection et Validation des API

AccessWeaver implémente plusieurs couches de protection pour sécuriser ses APIs contre diverses menaces.

### Validation des Entrées

Toutes les entrées API sont strictement validées selon plusieurs mécanismes :

#### 1. Validation de Schéma (OpenAPI)

```hcl
resource "aws_apigatewayv2_api" "main" {
  name          = "accessweaver-${var.environment}-api"
  protocol_type = "HTTP"
  
  body = templatefile("${path.module}/openapi/api-spec.yaml", {
    lambda_uri      = aws_lambda_function.api_handler.invoke_arn,
    cognito_issuer  = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
    allowed_origins = jsonencode(var.cors_allowed_origins)
  })
  
  # La validation est activée via le schema OpenAPI
  disable_execute_api_endpoint = var.environment == "production" ? true : false
  
  tags = {
    Name        = "accessweaver-${var.environment}-api"
    Environment = var.environment
    Service     = "api-gateway"
  }
}
```

Extrait du fichier OpenAPI pour validation:

```yaml
paths:
  /api/v1/permissions/check:
    post:
      summary: Vérifie si une permission est accordée
      operationId: checkPermission
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - subject
                - action
                - resource
              properties:
                subject:
                  type: string
                  format: uuid
                  maxLength: 36
                  pattern: '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                action:
                  type: string
                  maxLength: 64
                  pattern: '^[a-zA-Z0-9_:]+$'
                resource:
                  type: string
                  maxLength: 256
                  pattern: '^[a-zA-Z0-9_:/.-]+$'
                context:
                  type: object
                  additionalProperties: true
      responses:
        '200':
          description: Résultat de la vérification
          content:
            application/json:
              schema:
                type: object
                properties:
                  allowed:
                    type: boolean
                  reason:
                    type: string
```

#### 2. Validations Applicatives

Implémentation au niveau du code des validations :

```java
@Service
public class RequestValidator {
    
    public void validateDecisionRequest(PermissionRequest request) {
        // Validation structurelle
        if (request == null) {
            throw new ValidationException("La requête ne peut pas être nulle");
        }
        
        // Validation de la présence des champs obligatoires
        if (StringUtils.isBlank(request.getSubject())) {
            throw new ValidationException("Le sujet est obligatoire");
        }
        
        if (StringUtils.isBlank(request.getAction())) {
            throw new ValidationException("L'action est obligatoire");
        }
        
        if (StringUtils.isBlank(request.getResource())) {
            throw new ValidationException("La ressource est obligatoire");
        }
        
        // Validation du format des champs
        if (!isValidUUID(request.getSubject())) {
            throw new ValidationException("Le sujet doit être un UUID valide");
        }
        
        // Validation des patterns spécifiques
        if (!request.getAction().matches("^[a-zA-Z0-9_:]+$")) {
            throw new ValidationException("L'action contient des caractères non autorisés");
        }
        
        if (!request.getResource().matches("^[a-zA-Z0-9_:/.-]+$")) {
            throw new ValidationException("La ressource contient des caractères non autorisés");
        }
        
        // Validation métier spécifique
        validateBusinessRules(request);
    }
    
    private boolean isValidUUID(String uuid) {
        try {
            UUID.fromString(uuid);
            return true;
        } catch (IllegalArgumentException e) {
            return false;
        }
    }
    
    private void validateBusinessRules(PermissionRequest request) {
        // Règles métier spécifiques à AccessWeaver
        // ...
    }
}
```

### Protection Contre les Attaques Communes

| Type d'Attaque | Mécanisme de Protection | Implémentation |
|----------------|------------------------|----------------|
| **Injection (SQL, NoSQL)** | Paramètres préparés, ORM | Hibernate avec paramètres nommés |
| **XSS** | Échappement, CSP, validations | Content-Security-Policy, escapeHTML() |
| **CSRF** | Tokens anti-CSRF | SameSite cookies, CSRF tokens |
| **Broken Authentication** | Auth robuste, gestion de session | Timeout session, verrouillage compte |
| **Exposition de données sensibles** | Chiffrement, hachage | Voir document encryption.md |
| **XXE** | Désactivation entités externes | Parsers XML sécurisés |
| **Broken Access Control** | Vérifications côté serveur | RBAC/ABAC + validation middleware |
| **SSRF** | Liste blanche URL, validation | Validation domaines, IP blocklist |
| **Mass Assignment** | DTO spécifiques | Modèles Request/Response séparés |

### Contrôle de Taux (Rate Limiting)

AccessWeaver implémente plusieurs niveaux de rate limiting pour protéger ses API contre les abus :

#### 1. Rate Limiting au Niveau WAF

Voir le document waf.md pour les détails d'implémentation.

#### 2. Rate Limiting au Niveau API Gateway

```hcl
resource "aws_api_gateway_usage_plan" "standard" {
  name         = "accessweaver-${var.environment}-standard-usage-plan"
  description  = "Usage plan standard pour AccessWeaver API"
  
  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }
  
  # Limites de débit - différentes selon l'environnement
  quota_settings {
    limit  = var.environment == "production" ? 1000000 : 100000
    period = "DAY"
  }
  
  throttle_settings {
    burst_limit = var.environment == "production" ? 100 : 50
    rate_limit  = var.environment == "production" ? 50 : 20
  }
}

resource "aws_api_gateway_usage_plan_key" "standard" {
  key_id        = aws_api_gateway_api_key.standard.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.standard.id
}

# Usage plan premium avec limites plus élevées
resource "aws_api_gateway_usage_plan" "premium" {
  name         = "accessweaver-${var.environment}-premium-usage-plan"
  description  = "Usage plan premium pour AccessWeaver API"
  
  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }
  
  quota_settings {
    limit  = var.environment == "production" ? 10000000 : 1000000
    period = "DAY"
  }
  
  throttle_settings {
    burst_limit = var.environment == "production" ? 500 : 200
    rate_limit  = var.environment == "production" ? 200 : 100
  }
}
```

#### 3. Rate Limiting au Niveau Application

```java
@Configuration
public class RateLimitingConfig {
    
    @Bean
    public KeyResolver userKeyResolver() {
        return exchange -> {
            // Obtenir l'identifiant client pour le rate limiting
            String clientId = exchange.getRequest().getHeaders()
                .getFirst("X-Client-ID");
            
            if (clientId == null) {
                // Fallback sur l'IP si pas d'identifiant client
                clientId = exchange.getRequest().getRemoteAddress().getAddress().getHostAddress();
            }
            
            return Mono.just(clientId);
        };
    }
    
    @Bean
    public RateLimiter apiRateLimiter(Environment env) {
        // Limites différentes selon l'environnement
        int capacity = "production".equals(env.getProperty("app.environment")) ? 100 : 50;
        int refillRate = "production".equals(env.getProperty("app.environment")) ? 20 : 10;
        
        return new RedisRateLimiter(capacity, refillRate);
    }
}
## 🌐 Implémentation par Type d'API

AccessWeaver applique des stratégies de sécurité spécifiques selon le type d'API et leur niveau de criticité.

### APIs de Décision d'Autorisation

Ces APIs constituent le cœur fonctionnel d'AccessWeaver, avec des exigences élevées en matière de performance et de sécurité.

#### Caractéristiques de Sécurité

| Aspect | Implémentation | Justification |
|--------|----------------|---------------|
| **Authentification** | JWT (RS256), mTLS | Haute sécurité, validation cryptographique |
| **Performance** | Cache distribué, timeout court | Latence critique pour décisions d'autorisation |
| **Résilience** | Circuit breaker, fallback | Continuité de service critique |
| **Validation** | Schéma strict, validation avant traitement | Prévention des attaques d'injection |
| **Journalisation** | Détaillée mais configurable | Auditabilité vs performance |

#### Exemple d'Implémentation (Spring Security)

```java
@Configuration
@EnableWebSecurity
public class DecisionApiSecurityConfig {

    @Autowired
    private JwtAuthenticationProvider jwtAuthProvider;
    
    @Autowired
    private X509AuthenticationProvider mtlsAuthProvider;
    
    @Bean
    public SecurityFilterChain decisionApiFilterChain(HttpSecurity http) throws Exception {
        http
            .securityMatcher("/api/v1/decisions/**")
            .authorizeHttpRequests(authorize -> authorize
                .requestMatchers("/api/v1/decisions/check").hasAuthority("PERMISSION_CHECK")
                .requestMatchers("/api/v1/decisions/batch").hasAuthority("PERMISSION_BATCH_CHECK")
                .anyRequest().authenticated()
            )
            .csrf(csrf -> csrf.disable()) // Les API sont stateless
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            )
            .addFilterBefore(
                new JwtAuthenticationFilter(jwtAuthProvider),
                UsernamePasswordAuthenticationFilter.class
            )
            .x509(x509 -> x509
                .x509AuthenticationFilter(new X509AuthenticationFilter(mtlsAuthProvider))
            );
            
        return http.build();
    }
    
    @Bean
    public RateLimitInterceptor decisionApiRateLimiter() {
        return new RateLimitInterceptor(
            100,  // Requêtes par seconde
            1000, // Burst
            "decision-api"
        );
    }
}
```

### APIs de Management

Ces APIs gèrent la configuration et l'administration d'AccessWeaver, avec accès à des fonctionnalités sensibles.

#### Caractéristiques de Sécurité

| Aspect | Implémentation | Justification |
|--------|----------------|---------------|
| **Authentification** | OAuth 2.0 / OIDC, MFA | Authentification forte pour accès admin |
| **Autorisation** | RBAC strict, validation ABAC | Contrôle granulaire des actions admin |
| **Session** | Timeout court, jeton refresh | Réduction risque de vol de session |
| **Audit** | Log détaillé de toutes les actions | Traçabilité complète |
| **Validation** | Schéma strict + validations métier | Protection contre configurations dangereuses |

#### Configuration Cognito pour Management API

```hcl
resource "aws_cognito_user_pool" "admin" {
  name = "accessweaver-${var.environment}-admin"
  
  admin_create_user_config {
    allow_admin_create_user_only = true
  }
  
  # MFA obligatoire en production
  mfa_configuration = var.environment == "production" ? "ON" : "OPTIONAL"
  
  software_token_mfa_configuration {
    enabled = true
  }
  
  # Politique de mot de passe forte
  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
    temporary_password_validity_days = 3
  }
  
  # Configuration avancée de sécurité
  advanced_security_mode = "ENFORCED"
}

resource "aws_cognito_user_pool_client" "admin_api" {
  name = "accessweaver-${var.environment}-admin-api"
  
  user_pool_id = aws_cognito_user_pool.admin.id
  
  # OAuth2 configuration
  allowed_oauth_flows = ["code", "implicit"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes = ["openid", "email", "profile"]
  
  callback_urls = var.admin_callback_urls
  logout_urls   = var.admin_logout_urls
  
  # Token validity
  id_token_validity = 1 # 1 heure
  refresh_token_validity = 1 # 1 jour
  
  token_validity_units {
    id_token      = "hours"
    refresh_token = "days"
  }
  
  prevent_user_existence_errors = "ENABLED"
  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]
}

# Protection de l'API Management avec Cognito
resource "aws_api_gateway_authorizer" "cognito" {
  name          = "accessweaver-${var.environment}-cognito-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.management.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.admin.arn]
}
```

### APIs de Monitoring

Ces APIs fournissent des métriques et des logs pour la surveillance et le diagnostic d'AccessWeaver.

#### Caractéristiques de Sécurité

| Aspect | Implémentation | Justification |
|--------|----------------|---------------|
| **Authentification** | API Keys, JWT | Authentification adaptée à l'usage |
| **Autorisation** | RBAC avec rôle dédié | Isoler les permissions de monitoring |
| **Données** | Masquage, agrégation | Protection données sensibles |
| **Rate Limiting** | Limites élevées | Flexibilité pour scraping et dashboards |

#### Configuration Terraform pour API Monitoring

```hcl
resource "aws_api_gateway_resource" "monitoring" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "monitoring"
}

resource "aws_api_gateway_method" "monitoring_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.monitoring.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.monitoring.id
  
  request_parameters = {
    "method.request.querystring.start" = true
    "method.request.querystring.end"   = true
    "method.request.querystring.step"  = false
  }
}

# Usage plan spécifique pour monitoring (limites plus élevées)
resource "aws_api_gateway_usage_plan" "monitoring" {
  name         = "accessweaver-${var.environment}-monitoring-usage-plan"
  description  = "Usage plan pour APIs de monitoring"
  
  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }
  
  quota_settings {
    limit  = 1000000
    period = "DAY"
  }
  
  throttle_settings {
    burst_limit = 300
    rate_limit  = 100
  }
}
```

### APIs d'Intégration

Ces APIs permettent l'intégration avec des systèmes externes via webhooks et événements.

#### Caractéristiques de Sécurité

| Aspect | Implémentation | Justification |
|--------|----------------|---------------|
| **Authentification** | Signature HMAC, JWT | Vérification cryptographique des requêtes |
| **Payload** | Validation stricte, taille limitée | Protection contre les injections |
| **Idempotence** | Token idempotence, déduplication | Prévention des actions en double |
| **Retry** | Stratégie de retry avec backoff | Fiabilité sans surcharge |

#### Implémentation d'un Webhook avec Signature HMAC

```java
@RestController
@RequestMapping("/api/v1/webhooks")
public class WebhookController {

    @Autowired
    private WebhookService webhookService;
    
    @Autowired
    private SignatureValidator signatureValidator;
    
    @PostMapping("/{webhookId}")
    public ResponseEntity<WebhookResult> processWebhook(
            @PathVariable String webhookId,
            @RequestHeader("X-AccessWeaver-Signature") String signature,
            @RequestHeader("X-AccessWeaver-Timestamp") String timestamp,
            @RequestBody String payload) {
        
        // Vérification de la signature HMAC
        if (!signatureValidator.isValidSignature(webhookId, signature, timestamp, payload)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        
        // Vérification de la fraîcheur du timestamp (prévention replay attack)
        if (!signatureValidator.isTimestampValid(timestamp, 300)) { // 5 minutes
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(new WebhookResult(false, "Timestamp expired"));
        }
        
        // Validation du payload JSON
        if (!webhookService.validatePayload(webhookId, payload)) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(new WebhookResult(false, "Invalid payload format"));
        }
        
        // Traitement idempotent avec token de déduplication
        String dedupeId = extractDedupeId(payload);
        if (webhookService.isDuplicate(dedupeId)) {
            return ResponseEntity.ok(new WebhookResult(true, "Already processed"));
        }
        
        // Traitement du webhook
        WebhookResult result = webhookService.processWebhook(webhookId, payload);
        return ResponseEntity.ok(result);
    }
}
## 📊 Monitoring et Audit

AccessWeaver implémente un système complet de monitoring et d'audit pour détecter, alerter et investiguer les anomalies de sécurité liées aux APIs.

### Journalisation Détaillée

Toutes les requêtes API sont journalisées avec des informations pertinentes pour l'audit et la détection d'anomalies.

#### Structure des Logs d'API

```json
{
  "timestamp": "2025-06-02T17:42:31.456Z",
  "level": "INFO",
  "traceId": "4fa1d845c93a45b2a18ec0d0e7b3f972",
  "spanId": "9f34e791bc864d31",
  "service": "api-gateway",
  "environment": "production",
  "requestId": "c0a2381a-5d7f-4cd9-9d9a-03d2dd90b942",
  "method": "POST",
  "path": "/api/v1/decisions/check",
  "clientIp": "192.168.1.100",
  "clientId": "partner-service-01",
  "userId": "system",
  "userAgent": "AccessWeaver-Client/2.3.1",
  "statusCode": 200,
  "responseTime": 13.45,
  "requestSize": 428,
  "responseSize": 136,
  "authenticationMethod": "jwt",
  "authenticationSuccess": true,
  "authorizationSuccess": true,
  "validationSuccess": true,
  "rateLimited": false,
  "sensitiveData": {
    "subject": "[MASKED]",
    "resource": "[MASKED]",
    "action": "read"
  },
  "tags": ["decision-api", "core-service"]
}
```

#### Configuration Elasticsearch pour Analyse des Logs

```hcl
resource "aws_elasticsearch_domain" "api_logs" {
  domain_name           = "accessweaver-${var.environment}-api-logs"
  elasticsearch_version = "7.10"
  
  cluster_config {
    instance_type            = var.environment == "production" ? "m5.large.elasticsearch" : "t3.small.elasticsearch"
    instance_count           = var.environment == "production" ? 3 : 1
    zone_awareness_enabled   = var.environment == "production" ? true : false
    
    zone_awareness_config {
      availability_zone_count = var.environment == "production" ? 3 : 1
    }
  }
  
  ebs_options {
    ebs_enabled = true
    volume_size = var.environment == "production" ? 100 : 20
    volume_type = "gp2"
  }
  
  encrypt_at_rest {
    enabled = true
  }
  
  node_to_node_encryption {
    enabled = true
  }
  
  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }
  
  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = "admin"
      master_user_password = aws_secretsmanager_secret_version.es_master_password.secret_string
    }
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-api-logs"
    Environment = var.environment
    Service     = "monitoring"
  }
}
```

### Métriques et Alertes

AccessWeaver surveille activement un ensemble de métriques liées à la sécurité des API.

| Métrique | Description | Seuil d'Alerte | Environnements |
|----------|-------------|----------------|----------------|
| **AuthFailureRate** | Taux d'échecs d'authentification | >5% en 5min | Tous |
| **403ForbiddenRate** | Taux de réponses 403 | >10% en 5min | Tous |
| **APILatencyP99** | Latence du 99ème percentile | >500ms | Production, Staging |
| **RateLimitedRequests** | Requêtes limitées par débit | >100 en 1min | Tous |
| **InvalidPayloadRate** | Taux de payloads invalides | >10% en 5min | Tous |
| **APIAvailability** | Disponibilité de l'API | <99.9% | Production |
| **UnusualAPIPattern** | Motifs d'appel inhabituels | Détection d'anomalies | Production |
| **HighErrorRate** | Taux d'erreurs 5xx | >1% en 5min | Tous |

#### Configuration des Alertes CloudWatch

```hcl
resource "aws_cloudwatch_metric_alarm" "api_auth_failure" {
  alarm_name          = "accessweaver-${var.environment}-api-auth-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "AuthFailureCount"
  namespace           = "AccessWeaver/API"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Ce seuil indique un potentiel problème d'authentification ou une tentative d'attaque"
  
  alarm_actions = [aws_sns_topic.security_alerts.arn]
  ok_actions    = [aws_sns_topic.security_alerts.arn]
  
  dimensions = {
    Environment = var.environment
    ApiType     = "all"
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-api-auth-failure"
    Environment = var.environment
    Service     = "monitoring"
  }
}

resource "aws_cloudwatch_dashboard" "api_security" {
  dashboard_name = "accessweaver-${var.environment}-api-security"
  
  dashboard_body = templatefile("${path.module}/templates/api-security-dashboard.json", {
    environment = var.environment,
    region      = var.region,
    account_id  = data.aws_caller_identity.current.account_id
  })
}
```

### Détection d'Anomalies

AccessWeaver utilise des techniques avancées pour détecter les comportements anormaux au niveau des API.

#### Types d'Anomalies Surveillées

| Type d'Anomalie | Description | Technique de Détection |
|-----------------|-------------|------------------------|
| **Pics de Trafic** | Augmentation soudaine du volume | Détection statistique d'anomalies |
| **Balayage d'API** | Tentatives d'accès à de multiples endpoints | Pattern matching séquentiel |
| **Tests d'Identifiants** | Multiples échecs d'authentification | Seuils et agrégation par client |
| **Exfiltration de Données** | Volume inhabituel de données sortantes | Détection basée sur les percentiles |
| **Attaques par Force Brute** | Tentatives répétées sur un même endpoint | Rate limiting avec fenêtre glissante |
| **Reconnaissance** | Tentatives de découverte d'API | Détection de motifs OWASP |

#### Configuration CloudWatch Anomaly Detection

```hcl
resource "aws_cloudwatch_metric_alarm" "api_traffic_anomaly" {
  alarm_name          = "accessweaver-${var.environment}-api-traffic-anomaly"
  comparison_operator = "GreaterThanUpperThreshold"
  evaluation_periods  = "2"
  threshold_metric_id = "e1"
  alarm_description   = "Détection d'anomalies dans le trafic API"
  
  alarm_actions = [aws_sns_topic.security_alerts.arn]
  ok_actions    = [aws_sns_topic.security_alerts.arn]
  
  metric_query {
    id          = "e1"
    expression  = "ANOMALY_DETECTION_BAND(m1, 3)"
    label       = "RequestCount (Expected)"
    return_data = "true"
  }
  
  metric_query {
    id          = "m1"
    return_data = "true"
    metric {
      metric_name = "Count"
      namespace   = "AWS/ApiGateway"
      period      = "300"
      stat        = "Sum"
      dimensions = {
        ApiName = aws_api_gateway_rest_api.main.name
        Stage   = aws_api_gateway_stage.main.stage_name
      }
    }
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-api-traffic-anomaly"
    Environment = var.environment
    Service     = "monitoring"
  }
}
```

### Réponse aux Incidents

AccessWeaver définit des procédures claires pour répondre aux incidents de sécurité API.

#### Workflow de Réponse

```
┌────────────────────────────────────────────────────────┐
│           Workflow de Réponse aux Incidents            │
│                                                        │
│  ┌─────────┐      ┌─────────┐      ┌─────────┐         │
│  │Détection│─────►│Évaluation│─────►│Isolation│        │
│  └─────────┘      └─────────┘      └────┬────┘         │
│                                         │              │
│                                         ▼              │
│  ┌─────────┐      ┌─────────┐       ┌──────────┐       │
│  │Rapports │◄─────┤ Post-    │◄─────┤Correction│       │
│  └─────────┘      │ Mortem   │      └────┬─────┘       │
│                   └─────────┘           │              │
│                        ▲                │              │
│                        │                ▼              │
│                        │           ┌────────────┐      │
│                        └───────────┤Validation  │      │
│                                    └────────────┘      │
└────────────────────────────────────────────────────────┘
```

#### Actions Automatisées en Cas d'Incident

| Type d'Incident | Actions Automatiques | Actions Manuelles |
|-----------------|---------------------|-------------------|
| **Attaque DDoS** | Activation Shield, ajustement WAF | Analyse post-attaque, optimisation règles |
| **Scan d'API** | Blocage temporaire d'IP, alertes | Investigation des sources, ajustement protection |
| **Injection** | Blocage de requête, alerte | Correction vulnérabilité, audit de code |
| **Fuite de Données** | Révocation tokens, rate limiting | Investigation, notification parties concernées |
| **Vol d'Identifiants** | Verrouillage compte, rotation clés | Réinitialisation credentials, analyse forensique |

#### AWS Lambda pour Réponse Automatique

```hcl
resource "aws_lambda_function" "api_security_response" {
  function_name    = "accessweaver-${var.environment}-api-security-response"
  role             = aws_iam_role.api_security_response.arn
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  timeout          = 60
  memory_size      = 256
  
  environment {
    variables = {
      ENVIRONMENT = var.environment
      WAF_WEB_ACL_ARN = aws_wafv2_web_acl.main.arn
      SNS_TOPIC_ARN = aws_sns_topic.security_alerts.arn
      DYNAMODB_TABLE = aws_dynamodb_table.security_events.name
    }
  }
  
  code_signing_config_arn = var.environment == "production" ? aws_lambda_code_signing_config.security_functions.arn : null
  
  tracing_config {
    mode = "Active"
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-api-security-response"
    Environment = var.environment
    Service     = "security"
  }
}

resource "aws_cloudwatch_event_rule" "api_security_alert" {
  name        = "accessweaver-${var.environment}-api-security-alert"
  description = "Capture les alertes de sécurité API et déclenche une réponse automatique"
  
  event_pattern = jsonencode({
    source = ["aws.cloudwatch"],
    detail-type = ["CloudWatch Alarm State Change"],
    detail = {
      alarmName = [
        aws_cloudwatch_metric_alarm.api_auth_failure.alarm_name,
        aws_cloudwatch_metric_alarm.api_traffic_anomaly.alarm_name
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "api_security_response" {
  rule      = aws_cloudwatch_event_rule.api_security_alert.name
  target_id = "ApiSecurityResponse"
  arn       = aws_lambda_function.api_security_response.arn
}
```

## 📝 Références

- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)
- [AWS API Gateway Security Best Practices](https://docs.aws.amazon.com/apigateway/latest/developerguide/security.html)
- [JWT Best Practices](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-jwt-bcp-07)
- [NIST API Security Guidelines](https://csrc.nist.gov/publications/detail/sp/800-204a/final)
- [Spring Security Documentation](https://docs.spring.io/spring-security/reference/index.html)
- [OAuth 2.0 Security Best Practices](https://oauth.net/2/oauth-best-practice/)
- [Amazon Cognito Security Documentation](https://docs.aws.amazon.com/cognito/latest/developerguide/security.html)
