# 🔒 Chiffrement - AccessWeaver Infrastructure

**Version :** 1.0  
**Date :** Juin 2025  
**Module :** security/encryption  
**Responsable :** Équipe Platform AccessWeaver

---

## 🎯 Vue d'Ensemble

### Objectif Principal
Ce document détaille la **stratégie de chiffrement** implémentée dans l'infrastructure AWS d'AccessWeaver. Le chiffrement constitue une couche fondamentale de protection pour garantir la confidentialité et l'intégrité des données sensibles gérées par le système d'autorisation.

### Principes Fondamentaux

| Principe | Description | Implémentation |
|----------|-------------|----------------|
| **Defense-in-depth** | Chiffrement à plusieurs niveaux | Transport + Application + Stockage |
| **Zero-trust** | Aucune donnée sensible en clair | Chiffrement de bout-en-bout |
| **Key-rotation** | Rotation régulière des clés | Automatisée via AWS KMS |
| **Cryptographie moderne** | Algorithmes à jour et robustes | AES-256, RSA-4096, ECDSA P-384 |
| **Séparation des contextes** | Isolation des environnements | Clés distinctes par environnement et service |

### Types de Données Sensibles

AccessWeaver manipule plusieurs catégories de données sensibles nécessitant un chiffrement approprié :

| Catégorie | Exemples | Niveau de Sensibilité | Méthode de Chiffrement |
|-----------|----------|------------------------|------------------------|
| **Identifiants** | UUID utilisateurs, Identifiants entités | Moyen | Chiffrement transport |
| **Credentials** | API Keys, tokens d'accès, mots de passe | Élevé | Chiffrement application + stockage |
| **Politiques d'accès** | Règles d'autorisation, conditions | Moyen-Élevé | Chiffrement transport + stockage |
| **Métadonnées** | Contexte de décision, attributs | Moyen | Chiffrement transport |
| **Logs d'audit** | Historique décisions, changements | Élevé | Chiffrement transport + stockage |
| **Données client** | Contexte spécifique client | Variable | Chiffrement personnalisé selon sensibilité |

### Architecture de Chiffrement

```
┌──────────────────────────────────────────────────────────────────────┐
│                     Architecture de Chiffrement                      │
│                                                                      │
│  ┌────────────────────┐                                              │
│  │  Couche Transport  │ TLS 1.3, mTLS, Perfect Forward Secrecy       │
│  └────────────────────┘                                              │
│                                                                      │
│  ┌────────────────────┐    ┌─────────────────────┐                   │
│  │ Couche Application │    │    AWS KMS          │                   │
│  │                    │◄───┤    Gestion Clés     │                   │
│  │ - Chiffrement API  │    │    - CMKs           │                   │
│  │ - Tokenisation     │    │    - Rotation Auto  │                   │
│  │ - Client-side Enc. │    │    - IAM Contrôles  │                   │
│  └────────────────────┘    └─────────────────────┘                   │
│                                                                      │
│  ┌────────────────────┐    ┌─────────────────────┐                   │
│  │  Couche Stockage   │    │  AWS CloudHSM       │                   │
│  │                    │◄───┤                     │                   │
│  │ - RDS              │    │  - FIPS 140-2 Niv 3 │                   │
│  │ - S3               │    │  - Matériel dédié   │                   │
│  │ - DynamoDB         │    │  - Single-tenant    │                   │
│  │ - EBS              │    │                     │                   │
│  └────────────────────┘    └─────────────────────┘                   │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

## 🔐 Chiffrement en Transit

Le chiffrement des données en transit protège les informations pendant leur transmission entre les composants d'AccessWeaver et les systèmes externes.

### Configuration TLS

AccessWeaver implémente les meilleures pratiques TLS pour toutes les communications :

| Aspect | Configuration | Justification |
|--------|---------------|---------------|
| **Version** | TLS 1.3 minimum | Sécurité maximale, performance améliorée |
| **Cipher Suites** | Modern ciphers uniquement | Robustesse cryptographique |
| **Perfect Forward Secrecy** | Obligatoire | Protection des communications passées |
| **HSTS** | Activé (max-age=31536000) | Prévention downgrade attacks |
| **Certificate Pinning** | Implémenté côté client | Protection contre MITM |

#### Configuration AWS Load Balancer pour TLS Strict

```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.main.arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_lb_listener_rule" "hsts" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 1
  
  action {
    type = "fixed-response"
    
    fixed_response {
      content_type = "text/plain"
      message_body = "HTTPS Required"
      status_code  = "403"
    }
  }
  
  condition {
    http_header {
      http_header_name = "X-Forwarded-Proto"
      values           = ["http"]
    }
  }
}

# Redirection HTTP vers HTTPS
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type = "redirect"
    
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
```

### Mutual TLS (mTLS)

Pour les communications critiques entre services, AccessWeaver implémente l'authentification mutuelle TLS :

| Service | Utilisation mTLS | Implémentation |
|---------|-----------------|----------------|
| **API Décisions (Production)** | Obligatoire | NLB + Application gestion certificats |
| **Haute Disponibilité Inter-région** | Obligatoire | Certificats par région |
| **Interconnexion Partenaires** | Optionnel | Certificats client fournis |
| **Administration Système** | Obligatoire | Court TTL, rotation fréquente |

#### Configuration NLB avec TLS Mutuel

```hcl
resource "aws_lb" "mtls" {
  name               = "accessweaver-${var.environment}-mtls"
  internal           = true
  load_balancer_type = "network"
  
  subnet_mapping {
    subnet_id            = aws_subnet.private_api[0].id
    private_ipv4_address = var.mtls_lb_ip_addresses[0]
  }
  
  subnet_mapping {
    subnet_id            = aws_subnet.private_api[1].id
    private_ipv4_address = var.mtls_lb_ip_addresses[1]
  }
  
  subnet_mapping {
    subnet_id            = aws_subnet.private_api[2].id
    private_ipv4_address = var.mtls_lb_ip_addresses[2]
  }
  
  enable_deletion_protection = var.environment == "production" ? true : false
  
  tags = {
    Name        = "accessweaver-${var.environment}-mtls"
    Environment = var.environment
    Service     = "api-gateway"
  }
}

resource "aws_lb_listener" "mtls" {
  load_balancer_arn = aws_lb.mtls.arn
  port              = "8443"
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.server.arn
  alpn_policy       = "HTTP2Preferred"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mtls.arn
  }
}
```

### Configuration Spring Boot pour mTLS

```java
@Configuration
public class MTLSConfig {
    
    @Value("${ssl.trust-store}")
    private Resource trustStore;
    
    @Value("${ssl.trust-store-password}")
    private String trustStorePassword;
    
    @Value("${ssl.key-store}")
    private Resource keyStore;
    
    @Value("${ssl.key-store-password}")
    private String keyStorePassword;
    
    @Bean
    public WebServerFactoryCustomizer<TomcatServletWebServerFactory> tomcatSslConfigCustomizer() {
        return (factory) -> {
            Ssl ssl = new Ssl();
            ssl.setEnabled(true);
            ssl.setKeyStore(keyStore.getFilename());
            ssl.setKeyStorePassword(keyStorePassword);
            ssl.setKeyStoreType("PKCS12");
            ssl.setTrustStore(trustStore.getFilename());
            ssl.setTrustStorePassword(trustStorePassword);
            ssl.setTrustStoreType("PKCS12");
            ssl.setClientAuth(Ssl.ClientAuth.NEED); // Authentification client obligatoire
            
            factory.setSsl(ssl);
            factory.addConnectorCustomizers(connector -> {
                Http11NioProtocol protocol = (Http11NioProtocol) connector.getProtocolHandler();
                protocol.setMaxThreads(200);
                protocol.setSSLEnabled(true);
                protocol.setSecure(true);
                
                // Active le TLS 1.3
                protocol.setSslProtocol("TLSv1.3");
                
                // Cipher suites modernes avec PFS
                protocol.setCiphers("TLS_AES_256_GCM_SHA384,TLS_CHACHA20_POLY1305_SHA256,TLS_AES_128_GCM_SHA256");
            });
        };
    }
}
```
## 💻 Chiffrement au Niveau Applicatif

Le chiffrement au niveau applicatif d'AccessWeaver garantit la protection des données sensibles pendant leur traitement, avant même leur stockage persistant.

### Gestion des Clés avec AWS KMS

AccessWeaver utilise AWS KMS (Key Management Service) comme système central de gestion des clés de chiffrement :

| Aspect | Configuration | Environnements |
|--------|---------------|----------------|
| **Type de clés** | Customer Managed Keys (CMKs) | Tous |
| **Algorithme** | Symmetric (AES-256-GCM) | Tous |
| **Rotation automatique** | Activée (annuelle) | Tous |
| **Multi-région** | Activé | Production uniquement |
| **Contrôle d'accès** | IAM strict + Politique clé | Tous |
| **Surveillance** | CloudTrail + CloudWatch | Tous |

#### Configuration Terraform pour KMS

```hcl
resource "aws_kms_key" "application" {
  description             = "Clé de chiffrement pour les données applicatives AccessWeaver - ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region            = var.environment == "production" ? true : false
  
  # Politiques pour limiter l'accès aux services nécessaires uniquement
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow ECS services to use the key",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*",
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = var.aws_org_id
          }
        }
      },
      {
        Sid    = "Allow Lambda to use the key",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*"
        ],
        Resource = "*",
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = var.aws_org_id
          }
        }
      }
    ]
  })

  tags = {
    Name        = "accessweaver-${var.environment}-application"
    Environment = var.environment
    Service     = "encryption"
  }
}

resource "aws_kms_alias" "application" {
  name          = "alias/accessweaver-${var.environment}-application"
  target_key_id = aws_kms_key.application.key_id
}

# Clé spécifique pour les données sensibles
resource "aws_kms_key" "sensitive" {
  description             = "Clé de chiffrement pour les données sensibles AccessWeaver - ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region            = var.environment == "production" ? true : false
  
  # Politique plus restrictive pour les données sensibles
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow only specific roles to use the key",
        Effect = "Allow",
        Principal = {
          AWS = [
            "${aws_iam_role.encryption_service.arn}",
            "${aws_iam_role.audit_service.arn}"
          ]
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "accessweaver-${var.environment}-sensitive"
    Environment = var.environment
    Service     = "encryption"
  }
}

resource "aws_kms_alias" "sensitive" {
  name          = "alias/accessweaver-${var.environment}-sensitive"
  target_key_id = aws_kms_key.sensitive.key_id
}
```

### Chiffrement/Déchiffrement Applicatif

AccessWeaver implémente le chiffrement au niveau applicatif pour protéger les données sensibles avant leur stockage.

#### Service de Chiffrement Java

```java
@Service
public class EncryptionService {
    
    private final AWSKMS kmsClient;
    private final String applicationKeyId;
    private final String sensitiveDataKeyId;
    private final ObjectMapper objectMapper;
    
    public EncryptionService(
            @Value("${aws.kms.application-key-id}") String applicationKeyId,
            @Value("${aws.kms.sensitive-data-key-id}") String sensitiveDataKeyId,
            AWSKMS kmsClient,
            ObjectMapper objectMapper) {
        this.kmsClient = kmsClient;
        this.applicationKeyId = applicationKeyId;
        this.sensitiveDataKeyId = sensitiveDataKeyId;
        this.objectMapper = objectMapper;
    }
    
    /**
     * Chiffre des données standard avec la clé application
     */
    public String encrypt(String plaintext) throws EncryptionException {
        return encrypt(plaintext, applicationKeyId);
    }
    
    /**
     * Chiffre des données sensibles avec la clé spécifique
     */
    public String encryptSensitive(String plaintext) throws EncryptionException {
        return encrypt(plaintext, sensitiveDataKeyId);
    }
    
    /**
     * Méthode commune de chiffrement
     */
    private String encrypt(String plaintext, String keyId) throws EncryptionException {
        try {
            ByteBuffer plaintextBuffer = ByteBuffer.wrap(plaintext.getBytes(StandardCharsets.UTF_8));
            
            EncryptRequest request = new EncryptRequest()
                .withKeyId(keyId)
                .withPlaintext(plaintextBuffer);
            
            EncryptResult result = kmsClient.encrypt(request);
            byte[] ciphertext = result.getCiphertextBlob().array();
            
            // Encodage Base64 pour stockage/transmission sécurisée
            return Base64.getEncoder().encodeToString(ciphertext);
        } catch (Exception e) {
            throw new EncryptionException("Erreur lors du chiffrement des données", e);
        }
    }
    
    /**
     * Déchiffre des données en détectant automatiquement la clé utilisée
     */
    public String decrypt(String ciphertextBase64) throws EncryptionException {
        try {
            byte[] ciphertext = Base64.getDecoder().decode(ciphertextBase64);
            ByteBuffer ciphertextBuffer = ByteBuffer.wrap(ciphertext);
            
            DecryptRequest request = new DecryptRequest()
                .withCiphertextBlob(ciphertextBuffer);
            
            DecryptResult result = kmsClient.decrypt(request);
            
            return new String(result.getPlaintext().array(), StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new EncryptionException("Erreur lors du déchiffrement des données", e);
        }
    }
    
    /**
     * Chiffre un objet complet (conversion JSON puis chiffrement)
     */
    public <T> String encryptObject(T object) throws EncryptionException {
        try {
            String json = objectMapper.writeValueAsString(object);
            return encrypt(json);
        } catch (JsonProcessingException e) {
            throw new EncryptionException("Erreur de sérialisation JSON", e);
        }
    }
    
    /**
     * Déchiffre puis convertit en objet typé
     */
    public <T> T decryptObject(String ciphertextBase64, Class<T> valueType) throws EncryptionException {
        try {
            String json = decrypt(ciphertextBase64);
            return objectMapper.readValue(json, valueType);
        } catch (JsonProcessingException e) {
            throw new EncryptionException("Erreur de désérialisation JSON", e);
        }
    }
}
```

### Tokenisation des Données Sensibles

Pour les données particulièrement sensibles, AccessWeaver implémente une approche de tokenisation qui remplace les valeurs sensibles par des jetons non sensibles.

| Type de Donnée | Méthode de Tokenisation | Utilisation |
|----------------|------------------------|-------------|
| **Identifiants personnels** | Tokenisation par table | Audit logs, stockage long terme |
| **Clés d'API** | Hachage partiel (format: XXXX...XXXX) | Affichage UI, logs |
| **Contexte de décision** | Chiffrement de champs sélectifs | Conservation contexte décision |

#### Implémentation du Service de Tokenisation

```java
@Service
public class TokenizationService {
    
    private final EncryptionService encryptionService;
    private final TokenRepository tokenRepository;
    
    public TokenizationService(
            EncryptionService encryptionService,
            TokenRepository tokenRepository) {
        this.encryptionService = encryptionService;
        this.tokenRepository = tokenRepository;
    }
    
    /**
     * Tokenise une donnée sensible
     * @return Un jeton de référence
     */
    public String tokenize(String sensitiveData, TokenType tokenType) {
        // Génération d'un ID unique pour le jeton
        String tokenId = UUID.randomUUID().toString();
        
        // Chiffrement de la donnée sensible
        String encryptedData = encryptionService.encryptSensitive(sensitiveData);
        
        // Stockage de la relation token -> donnée chiffrée
        TokenEntity token = new TokenEntity();
        token.setTokenId(tokenId);
        token.setEncryptedData(encryptedData);
        token.setTokenType(tokenType);
        token.setCreatedAt(Instant.now());
        token.setExpiresAt(calculateExpiryDate(tokenType));
        
        tokenRepository.save(token);
        
        return tokenId;
    }
    
    /**
     * Récupère la donnée originale à partir du jeton
     */
    public String detokenize(String tokenId) {
        TokenEntity token = tokenRepository.findById(tokenId)
            .orElseThrow(() -> new TokenNotFoundException("Jeton non trouvé: " + tokenId));
            
        // Vérification de l'expiration
        if (token.getExpiresAt() != null && token.getExpiresAt().isBefore(Instant.now())) {
            throw new TokenExpiredException("Jeton expiré: " + tokenId);
        }
        
        // Déchiffrement de la donnée originale
        return encryptionService.decrypt(token.getEncryptedData());
    }
    
    /**
     * Calcule la date d'expiration selon le type de jeton
     */
    private Instant calculateExpiryDate(TokenType tokenType) {
        return switch (tokenType) {
            case PERSONAL_ID -> Instant.now().plus(30, ChronoUnit.DAYS);
            case API_KEY -> Instant.now().plus(1, ChronoUnit.YEARS);
            case SESSION -> Instant.now().plus(24, ChronoUnit.HOURS);
            case PERMANENT -> null; // Pas d'expiration
        };
    }
}
```

### Chiffrement Côté Client

Pour les données extrêmement sensibles, AccessWeaver propose un SDK client avec chiffrement côté client, garantissant que les données ne sont jamais exposées en clair, même au service AccessWeaver lui-même.

```java
public class AccessWeaverClientSdk {
    
    private final String apiEndpoint;
    private final String apiKey;
    private final SecretKey clientEncryptionKey;
    private final AccessWeaverApiClient apiClient;
    
    public AccessWeaverClientSdk(
            String apiEndpoint,
            String apiKey,
            String clientEncryptionKeyBase64) {
        this.apiEndpoint = apiEndpoint;
        this.apiKey = apiKey;
        this.clientEncryptionKey = decodeKey(clientEncryptionKeyBase64);
        this.apiClient = new AccessWeaverApiClient(apiEndpoint, apiKey);
    }
    
    /**
     * Vérifier une permission avec données sensibles chiffrées côté client
     */
    public DecisionResult checkPermissionWithClientSideEncryption(
            String subject,
            String action,
            String resource,
            Map<String, Object> sensitiveContext) throws Exception {
        
        // 1. Isolation des données sensibles
        Map<String, Object> normalContext = new HashMap<>();
        Map<String, Object> protectedContext = new HashMap<>();
        
        // Séparation selon la sensibilité
        for (Map.Entry<String, Object> entry : sensitiveContext.entrySet()) {
            if (isSensitiveField(entry.getKey())) {
                protectedContext.put(entry.getKey(), entry.getValue());
            } else {
                normalContext.put(entry.getKey(), entry.getValue());
            }
        }
        
        // 2. Chiffrement des données sensibles
        String encryptedContext = null;
        if (!protectedContext.isEmpty()) {
            encryptedContext = encryptClientData(objectMapper.writeValueAsString(protectedContext));
            
            // Ajouter le contexte chiffré dans un champ spécial
            normalContext.put("__protected", encryptedContext);
        }
        
        // 3. Appel API avec contexte modifié
        return apiClient.checkPermission(subject, action, resource, normalContext);
    }
    
    /**
     * Chiffrement symétrique côté client (AES-GCM)
     */
    private String encryptClientData(String plaintext) throws Exception {
        byte[] iv = new byte[12];
        SecureRandom random = new SecureRandom();
        random.nextBytes(iv);
        
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        GCMParameterSpec parameterSpec = new GCMParameterSpec(128, iv);
        cipher.init(Cipher.ENCRYPT_MODE, clientEncryptionKey, parameterSpec);
        
        byte[] ciphertext = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));
        
        // Format: IV + Ciphertext
        ByteBuffer byteBuffer = ByteBuffer.allocate(iv.length + ciphertext.length);
        byteBuffer.put(iv);
        byteBuffer.put(ciphertext);
        
        return Base64.getEncoder().encodeToString(byteBuffer.array());
    }
    
    private SecretKey decodeKey(String keyBase64) {
        byte[] decodedKey = Base64.getDecoder().decode(keyBase64);
        return new SecretKeySpec(decodedKey, 0, decodedKey.length, "AES");
    }
    
    private boolean isSensitiveField(String fieldName) {
        return sensitiveFieldPatterns.stream()
            .anyMatch(pattern -> pattern.matcher(fieldName).matches());
    }
}
```
## 💾 Chiffrement au Repos

AccessWeaver implémente un chiffrement complet des données au repos pour tous les services de stockage AWS utilisés par la plateforme.

### Principes Généraux

| Principe | Implémentation | Environnements |
|----------|----------------|----------------|
| **Chiffrement par défaut** | Activé pour tous les services | Tous |
| **Gestion des clés** | AWS KMS avec CMKs | Tous |
| **Contrôle d'accès** | IAM + Politiques KMS | Tous |
| **Auditabilité** | CloudTrail pour toutes les opérations KMS | Tous |

### Chiffrement Amazon RDS

La base de données principale d'AccessWeaver est protégée par chiffrement complet :

```hcl
resource "aws_db_instance" "main" {
  identifier           = "accessweaver-${var.environment}"
  engine               = "postgres"
  engine_version       = "13.7"
  instance_class       = var.environment == "production" ? "db.r6g.2xlarge" : "db.r6g.large"
  allocated_storage    = var.environment == "production" ? 200 : 50
  max_allocated_storage = var.environment == "production" ? 1000 : 200
  
  db_name              = "accessweaver"
  username             = "awadmin"
  password             = random_password.db_password.result
  
  multi_az             = var.environment == "production" ? true : false
  publicly_accessible  = false
  
  # Configuration de chiffrement
  storage_encrypted    = true
  kms_key_id           = aws_kms_key.database.arn
  
  backup_retention_period = var.environment == "production" ? 30 : 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:30-sun:05:30"
  
  deletion_protection = var.environment == "production" ? true : false
  
  # Paramètres de sécurité supplémentaires
  parameter_group_name = aws_db_parameter_group.postgres_secure.name
  
  # Configuration réseau
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  
  # Monitoring avancé
  monitoring_interval = 30
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn
  
  tags = {
    Name        = "accessweaver-${var.environment}"
    Environment = var.environment
    Service     = "database"
  }
}

# Clé KMS dédiée pour la base de données
resource "aws_kms_key" "database" {
  description             = "Clé de chiffrement pour la base de données AccessWeaver - ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow RDS to use the key",
        Effect = "Allow",
        Principal = {
          Service = "rds.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ],
        Resource = "*"
      }
    ]
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-database"
    Environment = var.environment
    Service     = "encryption"
  }
}

resource "aws_kms_alias" "database" {
  name          = "alias/accessweaver-${var.environment}-database"
  target_key_id = aws_kms_key.database.key_id
}

# Groupe de paramètres RDS sécurisés
resource "aws_db_parameter_group" "postgres_secure" {
  name   = "accessweaver-${var.environment}-postgres13-secure"
  family = "postgres13"
  
  parameter {
    name  = "log_statement"
    value = "ddl"  # Journalisation des commandes DDL uniquement
  }
  
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"  # Log des requêtes lentes (>1s)
  }
  
  parameter {
    name  = "ssl"
    value = "1"  # Activer SSL
  }
  
  parameter {
    name  = "rds.force_ssl"
    value = "1"  # Forcer SSL pour toutes les connexions
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-postgres13-secure"
    Environment = var.environment
    Service     = "database"
  }
}
```

### Chiffrement Amazon S3

Tous les buckets S3 utilisés par AccessWeaver sont chiffrés par défaut :

```hcl
resource "aws_s3_bucket" "logs" {
  bucket = "accessweaver-${var.environment}-logs-${data.aws_caller_identity.current.account_id}"
  
  tags = {
    Name        = "accessweaver-${var.environment}-logs"
    Environment = var.environment
    Service     = "logging"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3.arn
      sse_algorithm     = "aws:kms"
    }
    
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  
  rule {
    id     = "archive-and-delete"
    status = "Enabled"
    
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    expiration {
      days = var.environment == "production" ? 365 : 180
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Clé KMS pour S3
resource "aws_kms_key" "s3" {
  description             = "Clé de chiffrement pour les buckets S3 AccessWeaver - ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use the key",
        Effect = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      }
    ]
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-s3"
    Environment = var.environment
    Service     = "encryption"
  }
}

resource "aws_kms_alias" "s3" {
  name          = "alias/accessweaver-${var.environment}-s3"
  target_key_id = aws_kms_key.s3.key_id
}
```

### Chiffrement DynamoDB

Les tables DynamoDB d'AccessWeaver sont chiffrées avec des clés KMS dédiées :

```hcl
resource "aws_dynamodb_table" "tokens" {
  name         = "accessweaver-${var.environment}-tokens"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "TokenId"
  
  attribute {
    name = "TokenId"
    type = "S"
  }
  
  attribute {
    name = "ExpiresAt"
    type = "N"
  }
  
  attribute {
    name = "TokenType"
    type = "S"
  }
  
  global_secondary_index {
    name               = "TokenType-ExpiresAt-index"
    hash_key           = "TokenType"
    range_key          = "ExpiresAt"
    projection_type    = "ALL"
  }
  
  point_in_time_recovery {
    enabled = var.environment == "production" ? true : false
  }
  
  # Configuration du chiffrement
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }
  
  ttl {
    attribute_name = "TTL"
    enabled        = true
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-tokens"
    Environment = var.environment
    Service     = "tokenization"
  }
}

# Table pour les décisions d'autorisation mises en cache
resource "aws_dynamodb_table" "auth_decisions" {
  name         = "accessweaver-${var.environment}-auth-decisions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "DecisionId"
  
  attribute {
    name = "DecisionId"
    type = "S"
  }
  
  attribute {
    name = "Subject"
    type = "S"
  }
  
  attribute {
    name = "Resource"
    type = "S"
  }
  
  global_secondary_index {
    name               = "Subject-Resource-index"
    hash_key           = "Subject"
    range_key          = "Resource"
    projection_type    = "ALL"
  }
  
  # Configuration du chiffrement
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }
  
  ttl {
    attribute_name = "TTL"
    enabled        = true
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-auth-decisions"
    Environment = var.environment
    Service     = "decisions"
  }
}

# Clé KMS pour DynamoDB
resource "aws_kms_key" "dynamodb" {
  description             = "Clé de chiffrement pour DynamoDB AccessWeaver - ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow DynamoDB to use the key",
        Effect = "Allow",
        Principal = {
          Service = "dynamodb.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*",
        Condition = {
          StringEquals = {
            "aws:SourceAccount": "${data.aws_caller_identity.current.account_id}"
          }
        }
      }
    ]
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-dynamodb"
    Environment = var.environment
    Service     = "encryption"
  }
}

resource "aws_kms_alias" "dynamodb" {
  name          = "alias/accessweaver-${var.environment}-dynamodb"
  target_key_id = aws_kms_key.dynamodb.key_id
}
```

### Chiffrement EBS pour les Containers ECS

Les volumes EBS attachés aux instances EC2 et aux tâches ECS sont également chiffrés :

```hcl
resource "aws_kms_key" "ebs" {
  description             = "Clé de chiffrement pour les volumes EBS AccessWeaver - ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow EC2 to use the key",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ],
        Resource = "*",
        Condition = {
          StringEquals = {
            "aws:SourceAccount": "${data.aws_caller_identity.current.account_id}"
          }
        }
      }
    ]
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-ebs"
    Environment = var.environment
    Service     = "encryption"
  }
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/accessweaver-${var.environment}-ebs"
  target_key_id = aws_kms_key.ebs.key_id
}

# Configuration du chiffrement EBS par défaut
resource "aws_ebs_encryption_by_default" "enabled" {
  enabled = true
}

resource "aws_ebs_default_kms_key" "ebs_default" {
  key_arn = aws_kms_key.ebs.arn
}

# Configuration ECS avec volumes chiffrés
resource "aws_ecs_task_definition" "api" {
  family                   = "accessweaver-${var.environment}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.environment == "production" ? "1024" : "512"
  memory                   = var.environment == "production" ? "2048" : "1024"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  
  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${aws_ecr_repository.api.repository_url}:${var.image_tag}"
      essential = true
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "api"
        }
      }
      
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = var.environment
        },
        {
          name  = "KMS_APPLICATION_KEY_ID"
          value = aws_kms_key.application.id
        },
        {
          name  = "KMS_SENSITIVE_KEY_ID"
          value = aws_kms_key.sensitive.id
        }
      ]
      
      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = aws_secretsmanager_secret.db_password.arn
        }
      ]
    }
  ])
  
  # Configuration des volumes EFS avec chiffrement
  ephemeral_storage {
    size_in_gib = 20
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-api"
    Environment = var.environment
    Service     = "api"
  }
}
```

### Chiffrement des Secrets dans AWS Secrets Manager

AccessWeaver utilise AWS Secrets Manager pour stocker les credentials et les secrets de manière sécurisée :

```hcl
resource "aws_kms_key" "secrets" {
  description             = "Clé de chiffrement pour Secrets Manager AccessWeaver - ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow Secrets Manager to use the key",
        Effect = "Allow",
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      }
    ]
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-secrets"
    Environment = var.environment
    Service     = "encryption"
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/accessweaver-${var.environment}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# Secret pour le mot de passe base de données
resource "aws_secretsmanager_secret" "db_password" {
  name        = "accessweaver/${var.environment}/db/password"
  description = "Mot de passe de la base de données AccessWeaver"
  kms_key_id  = aws_kms_key.secrets.arn
  
  tags = {
    Name        = "accessweaver-${var.environment}-db-password"
    Environment = var.environment
    Service     = "database"
  }
}

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

# Secret pour les clés API
resource "aws_secretsmanager_secret" "api_keys" {
  name        = "accessweaver/${var.environment}/api/keys"
  description = "Clés API pour AccessWeaver"
  kms_key_id  = aws_kms_key.secrets.arn
  
  tags = {
    Name        = "accessweaver-${var.environment}-api-keys"
    Environment = var.environment
    Service     = "api"
  }
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id = aws_secretsmanager_secret.api_keys.id
  
  secret_string = jsonencode({
    admin_api_key      = random_password.admin_api_key.result,
    service_api_key    = random_password.service_api_key.result,
    monitoring_api_key = random_password.monitoring_api_key.result
  })
}

resource "random_password" "admin_api_key" {
  length  = 48
  special = false
}

resource "random_password" "service_api_key" {
  length  = 48
  special = false
}

resource "random_password" "monitoring_api_key" {
  length  = 48
  special = false
}

# Secret pour les certificats mTLS
resource "aws_secretsmanager_secret" "mtls_certificates" {
  name        = "accessweaver/${var.environment}/mtls/certificates"
  description = "Certificats mTLS pour AccessWeaver"
  kms_key_id  = aws_kms_key.secrets.arn
  
  tags = {
    Name        = "accessweaver-${var.environment}-mtls-certificates"
    Environment = var.environment
    Service     = "security"
  }
}
```
## 🔑 Gestion des Clés et Conformité

### Gestion du Cycle de Vie des Clés

AccessWeaver implémente une gestion rigoureuse du cycle de vie des clés cryptographiques.

#### Phases du Cycle de Vie

```
┌─────────────────────────────────────────────────────┐
│             Cycle de Vie des Clés                   │
│                                                     │
│  ┌──────────┐     ┌──────────┐     ┌──────────┐     │
│  │ Création │────►│ Activation│────►│Utilisation│    │
│  └──────────┘     └──────────┘     └─────┬────┘     │
│                                          │          │
│                                          ▼          │
│  ┌──────────┐     ┌──────────┐     ┌──────────┐     │
│  │   Purge  │◄────┤ Archivage │◄────┤ Rotation │     │
│  └──────────┘     └──────────┘     └──────────┘     │
│                                                     │
└─────────────────────────────────────────────────────┘
```

| Phase | Processus | Automatisation |
|-------|-----------|----------------|
| **Création** | Génération via AWS KMS | Terraform |
| **Activation** | Immédiate après création | Terraform |
| **Utilisation** | Référencée par services | AWS SDK |
| **Rotation** | Annuelle pour les CMKs | AWS KMS automatique |
| **Archivage** | Après période de rétention | Manuel avec approbation |
| **Purge** | Suppression définitive | Manuel avec validation multi-niveau |

#### AWS CloudHSM pour les Environnements Critiques

Pour la production et les clients avec exigences de sécurité élevées, AccessWeaver utilise AWS CloudHSM :

```hcl
resource "aws_cloudhsm_v2_cluster" "main" {
  count = var.environment == "production" ? 1 : 0
  
  hsm_type   = "hsm1.medium"
  subnet_ids = [aws_subnet.private_hsm[0].id]
  
  tags = {
    Name        = "accessweaver-${var.environment}-hsm-cluster"
    Environment = var.environment
    Service     = "encryption"
  }
}

resource "aws_cloudhsm_v2_hsm" "hsm1" {
  count = var.environment == "production" ? 1 : 0
  
  cluster_id = aws_cloudhsm_v2_cluster.main[0].cluster_id
  subnet_id  = aws_subnet.private_hsm[0].id
  
  availability_zone = "${var.region}a"
  
  depends_on = [aws_cloudhsm_v2_cluster.main]
}

resource "aws_cloudhsm_v2_hsm" "hsm2" {
  count = var.environment == "production" ? 1 : 0
  
  cluster_id = aws_cloudhsm_v2_cluster.main[0].cluster_id
  subnet_id  = aws_subnet.private_hsm[1].id
  
  availability_zone = "${var.region}b"
  
  depends_on = [aws_cloudhsm_v2_cluster.main]
}
```

#### Sécurisation de l'Accès aux Clés KMS

```hcl
# Rôle IAM restrictif pour l'accès aux clés KMS
resource "aws_iam_role" "kms_manager" {
  name = "accessweaver-${var.environment}-kms-manager"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/IAMSecurityAdmin"
        },
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/Team": "Security"
          },
          Bool = {
            "aws:MultiFactorAuthPresent": "true"
          }
        }
      }
    ]
  })
  
  tags = {
    Name        = "accessweaver-${var.environment}-kms-manager"
    Environment = var.environment
    Service     = "security"
  }
}

resource "aws_iam_policy" "kms_manager" {
  name        = "accessweaver-${var.environment}-kms-manager-policy"
  description = "Politique pour la gestion des clés KMS d'AccessWeaver"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:DescribeKey",
          "kms:ListKeys",
          "kms:ListAliases",
          "kms:ListResourceTags",
          "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "kms:EnableKeyRotation",
          "kms:TagResource",
          "kms:UntagResource"
        ],
        Resource = [
          aws_kms_key.application.arn,
          aws_kms_key.sensitive.arn,
          aws_kms_key.database.arn,
          aws_kms_key.s3.arn,
          aws_kms_key.dynamodb.arn,
          aws_kms_key.ebs.arn,
          aws_kms_key.secrets.arn
        ],
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent": "true"
          }
        }
      },
      {
        Effect = "Deny",
        Action = [
          "kms:ScheduleKeyDeletion",
          "kms:DisableKey",
          "kms:DeleteAlias"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "kms_manager" {
  role       = aws_iam_role.kms_manager.name
  policy_arn = aws_iam_policy.kms_manager.arn
}

# Surveillance des opérations KMS via CloudTrail
resource "aws_cloudtrail" "kms_audit" {
  name                          = "accessweaver-${var.environment}-kms-audit"
  s3_bucket_name                = aws_s3_bucket.audit_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.cloudtrail.arn
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true
    
    data_resource {
      type   = "AWS::KMS::Key"
      values = ["arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/*"]
    }
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-kms-audit"
    Environment = var.environment
    Service     = "security"
  }
}

# Alarme CloudWatch pour les opérations critiques KMS
resource "aws_cloudwatch_metric_alarm" "kms_critical_operations" {
  alarm_name          = "accessweaver-${var.environment}-kms-critical-operations"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "KMSCriticalOperationsCount"
  namespace           = "AccessWeaver/Security"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Cette alarme surveille les opérations critiques KMS (suppression, désactivation)"
  
  alarm_actions = [aws_sns_topic.security_alerts.arn]
  
  dimensions = {
    Environment = var.environment
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-kms-critical-operations"
    Environment = var.environment
    Service     = "security"
  }
}
```

### Conformité Réglementaire

AccessWeaver implémente les mesures de chiffrement nécessaires pour assurer la conformité avec plusieurs réglementations.

| Réglementation | Exigences | Mise en Œuvre AccessWeaver |
|----------------|-----------|----------------------------|
| **RGPD** | Chiffrement des données personnelles | Chiffrement au repos et en transit pour toutes les données |
| **PCI-DSS** | Chiffrement des données de cartes | Tokenisation, chiffrement complet, séparation des environnements |
| **HIPAA** | Protection des données de santé | Chiffrement, contrôle d'accès, audit, intégrité des données |
| **SOC 2** | Contrôles de sécurité, disponibilité | Chiffrement, surveillance, haute disponibilité, redondance |
| **ISO 27001** | Gestion de la sécurité de l'information | Framework complet de sécurité et de gestion des risques |

#### Implémentation des Contrôles SOC 2 Type 2

```hcl
# Contrôles SOC 2 liés au chiffrement
resource "aws_config_config_rule" "encrypted_volumes" {
  name = "accessweaver-${var.environment}-encrypted-volumes"
  
  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-encrypted-volumes"
    Environment = var.environment
    Service     = "compliance"
    Control     = "SOC2-C1.3"
  }
}

resource "aws_config_config_rule" "rds_storage_encrypted" {
  name = "accessweaver-${var.environment}-rds-storage-encrypted"
  
  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-rds-storage-encrypted"
    Environment = var.environment
    Service     = "compliance"
    Control     = "SOC2-C1.3"
  }
}

resource "aws_config_config_rule" "s3_bucket_server_side_encryption_enabled" {
  name = "accessweaver-${var.environment}-s3-encryption-enabled"
  
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-s3-encryption-enabled"
    Environment = var.environment
    Service     = "compliance"
    Control     = "SOC2-C1.3"
  }
}

resource "aws_config_config_rule" "dynamodb_table_encrypted_kms" {
  name = "accessweaver-${var.environment}-dynamodb-encrypted-kms"
  
  source {
    owner             = "AWS"
    source_identifier = "DYNAMODB_TABLE_ENCRYPTED_KMS"
  }
  
  tags = {
    Name        = "accessweaver-${var.environment}-dynamodb-encrypted-kms"
    Environment = var.environment
    Service     = "compliance"
    Control     = "SOC2-C1.3"
  }
}
```

## 📈 Implémentation par Environnement

La stratégie de chiffrement d'AccessWeaver varie légèrement selon les environnements pour équilibrer sécurité et coûts.

### Matrice de Chiffrement par Environnement

| Fonctionnalité | Development | Staging | Production |
|----------------|-------------|---------|------------|
| **Chiffrement Transport** | TLS 1.3 | TLS 1.3 | TLS 1.3 + mTLS |
| **Rotation des Clés KMS** | Annuelle (auto) | Annuelle (auto) | Semestrielle |
| **Multi-région KMS** | Non | Non | Oui |
| **AWS CloudHSM** | Non | Non | Oui (FIPS 140-2 L3) |
| **Tokenisation** | Basique | Complète | Complète + Validation |
| **Client-side Encryption** | Optionnel | Recommandé | Obligatoire (données sensibles) |

### Configuration Production

L'environnement de production implémente les mesures de chiffrement les plus strictes :

```hcl
# Configuration spécifique à la production
module "encryption_production" {
  source = "./modules/encryption"
  
  environment            = "production"
  region                 = var.region
  multi_region           = true
  use_cloudhsm           = true
  key_rotation_days      = 180
  enforce_client_encryption = true
  
  # Configurations SIEM et audit
  security_log_retention = 365
  audit_integration      = true
  
  # Paramètres CloudHSM
  hsm_cluster_size       = 2
  hsm_availability_zones = ["${var.region}a", "${var.region}b"]
  
  # Paramètres de monitoring
  advanced_monitoring    = true
  alert_thresholds = {
    key_usage_anomaly     = 3 # Écarts-types
    encryption_failures   = 5 # Nombre par minute
    decryption_failures   = 3 # Nombre par minute
    unauthorized_attempts = 1 # Nombre par minute
  }
  
  # Intégration avec service externe de gestion des clés
  external_key_management = {
    enabled  = true
    provider = "hashicorp-vault"
    endpoint = "https://vault.example.com:8200"
    role_id  = var.vault_role_id
  }
}
```

### Configuration Staging

L'environnement de staging équilibre sécurité et flexibilité :

```hcl
# Configuration spécifique au staging
module "encryption_staging" {
  source = "./modules/encryption"
  
  environment            = "staging"
  region                 = var.region
  multi_region           = false
  use_cloudhsm           = false
  key_rotation_days      = 365
  enforce_client_encryption = false
  
  # Configurations SIEM et audit
  security_log_retention = 180
  audit_integration      = true
  
  # Paramètres de monitoring
  advanced_monitoring    = true
  alert_thresholds = {
    key_usage_anomaly     = 4 # Plus permissif qu'en production
    encryption_failures   = 10
    decryption_failures   = 5
    unauthorized_attempts = 3
  }
  
  # Pas d'intégration avec service externe
  external_key_management = {
    enabled = false
  }
}
```

### Configuration Development

L'environnement de développement simplifie certains aspects du chiffrement tout en maintenant les bonnes pratiques fondamentales :

```hcl
# Configuration spécifique au développement
module "encryption_development" {
  source = "./modules/encryption"
  
  environment            = "development"
  region                 = var.region
  multi_region           = false
  use_cloudhsm           = false
  key_rotation_days      = 365
  enforce_client_encryption = false
  
  # Configurations SIEM et audit
  security_log_retention = 90
  audit_integration      = false
  
  # Paramètres de monitoring simplifiés
  advanced_monitoring    = false
  alert_thresholds = {
    key_usage_anomaly     = 5 # Très permissif
    encryption_failures   = 20
    decryption_failures   = 10
    unauthorized_attempts = 5
  }
  
  # Pas d'intégration avec service externe
  external_key_management = {
    enabled = false
  }
}
```

## 📝 Références

- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [NIST Cryptographic Standards and Guidelines](https://csrc.nist.gov/projects/cryptographic-standards-and-guidelines)
- [AWS CloudHSM User Guide](https://docs.aws.amazon.com/cloudhsm/latest/userguide/introduction.html)
- [OWASP Cryptographic Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html)
- [GDPR Article 32 - Security of Processing](https://gdpr-info.eu/art-32-gdpr/)
- [PCI DSS Requirements for Cryptography](https://www.pcisecuritystandards.org/documents/PCI_DSS_v3-2-1.pdf)
