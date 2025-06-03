
## 📊 Migration des Données

### Stratégies de Migration de Données

#### 1. Extract, Transform, Load (ETL)

```java
@Service
@Slf4j
public class DataMigrationService {
    
    private final UserMigrationRepository userRepo;
    private final AccessWeaverApiClient apiClient;
    private final DataTransformationService transformer;
    
    @Transactional
    public MigrationResult migrateUsers(MigrationConfig config) {
        log.info("Starting user migration with config: {}", config);
        
        MigrationResult result = new MigrationResult();
        
        try {
            // 1. Extract: Récupérer les données du système source
            List<LegacyUser> legacyUsers = extractUsers(config);
            log.info("Extracted {} users from legacy system", legacyUsers.size());
            
            // 2. Transform: Convertir au format AccessWeaver
            List<AccessWeaverUser> transformedUsers = transformUsers(legacyUsers, config);
            log.info("Transformed {} users", transformedUsers.size());
            
            // 3. Load: Importer dans AccessWeaver
            result = loadUsers(transformedUsers, config);
            log.info("Migration completed: {}", result);
            
        } catch (Exception e) {
            log.error("Migration failed", e);
            result.setStatus(MigrationStatus.FAILED);
            result.setError(e.getMessage());
            
            if (config.isRollbackOnError()) {
                rollbackMigration(result);
            }
        }
        
        return result;
    }
    
    private List<LegacyUser> extractUsers(MigrationConfig config) {
        switch (config.getSourceType()) {
            case LDAP:
                return ldapExtractor.extractUsers(config.getLdapConfig());
            case DATABASE:
                return databaseExtractor.extractUsers(config.getDatabaseConfig());
            case CSV:
                return csvExtractor.extractUsers(config.getCsvConfig());
            default:
                throw new UnsupportedOperationException("Source type not supported: " 
                                                       + config.getSourceType());
        }
    }
    
    private List<AccessWeaverUser> transformUsers(List<LegacyUser> legacyUsers, 
                                                 MigrationConfig config) {
        return legacyUsers.stream()
            .map(user -> transformer.transformUser(user, config))
            .filter(Objects::nonNull)
            .collect(Collectors.toList());
    }
    
    private MigrationResult loadUsers(List<AccessWeaverUser> users, MigrationConfig config) {
        MigrationResult result = new MigrationResult();
        
        // Migration par batch pour éviter la surcharge
        List<List<AccessWeaverUser>> batches = Lists.partition(users, config.getBatchSize());
        
        for (int i = 0; i < batches.size(); i++) {
            List<AccessWeaverUser> batch = batches.get(i);
            log.info("Processing batch {}/{} ({} users)", 
                    i + 1, batches.size(), batch.size());
            
            try {
                BatchImportResult batchResult = apiClient.importUsers(
                    config.getTenantId(), batch);
                
                result.addBatchResult(batchResult);
                
                // Pause entre les batches pour éviter la surcharge
                if (i < batches.size() - 1) {
                    Thread.sleep(config.getBatchDelayMs());
                }
                
            } catch (Exception e) {
                log.error("Batch {} failed", i + 1, e);
                result.addError(String.format("Batch %d failed: %s", i + 1, e.getMessage()));
                
                if (config.isStopOnBatchError()) {
                    break;
                }
            }
        }
        
        return result;
    }
}
```

#### 2. Data Transformation Service

```java
@Service
public class DataTransformationService {
    
    private final ValidationService validator;
    private final MappingService mapper;
    
    public AccessWeaverUser transformUser(LegacyUser legacyUser, MigrationConfig config) {
        try {
            // 1. Validation des données source
            ValidationResult validation = validator.validateLegacyUser(legacyUser);
            if (!validation.isValid()) {
                log.warn("Invalid legacy user {}: {}", 
                        legacyUser.getId(), validation.getErrors());
                return null;
            }
            
            // 2. Mapping des champs
            AccessWeaverUser user = AccessWeaverUser.builder()
                .email(cleanEmail(legacyUser.getEmail()))
                .firstName(cleanName(legacyUser.getFirstName()))
                .lastName(cleanName(legacyUser.getLastName()))
                .tenantId(config.getTenantId())
                .status(mapUserStatus(legacyUser.getStatus()))
                .attributes(transformCustomAttributes(legacyUser, config))
                .build();
            
            // 3. Mapping des rôles
            Set<String> roles = transformRoles(legacyUser.getGroups(), config);
            user.setRoles(roles);
            
            // 4. Validation du résultat
            ValidationResult targetValidation = validator.validateAccessWeaverUser(user);
            if (!targetValidation.isValid()) {
                log.error("Transformed user validation failed for {}: {}", 
                         legacyUser.getId(), targetValidation.getErrors());
                return null;
            }
            
            return user;
            
        } catch (Exception e) {
            log.error("Error transforming user {}", legacyUser.getId(), e);
            return null;
        }
    }
    
    private String cleanEmail(String email) {
        if (email == null) return null;
        return email.toLowerCase().trim();
    }
    
    private String cleanName(String name) {
        if (name == null) return null;
        return name.trim().replaceAll("\\s+", " ");
    }
    
    private UserStatus mapUserStatus(String legacyStatus) {
        if (legacyStatus == null) return UserStatus.ACTIVE;
        
        switch (legacyStatus.toUpperCase()) {
            case "ACTIVE":
            case "ENABLED":
                return UserStatus.ACTIVE;
            case "INACTIVE":
            case "DISABLED":
                return UserStatus.SUSPENDED;
            case "LOCKED":
                return UserStatus.LOCKED;
            default:
                log.warn("Unknown legacy status: {}. Defaulting to ACTIVE", legacyStatus);
                return UserStatus.ACTIVE;
        }
    }
    
    private Set<String> transformRoles(Set<String> legacyGroups, MigrationConfig config) {
        if (legacyGroups == null) return Set.of();
        
        return legacyGroups.stream()
            .map(group -> config.getRoleMapping().getOrDefault(group, "user"))
            .collect(Collectors.toSet());
    }
    
    private Map<String, Object> transformCustomAttributes(LegacyUser legacyUser, 
                                                         MigrationConfig config) {
        Map<String, Object> attributes = new HashMap<>();
        
        // Mapping des attributs personnalisés selon la configuration
        config.getAttributeMapping().forEach((legacyAttr, targetAttr) -> {
            Object value = getAttributeValue(legacyUser, legacyAttr);
            if (value != null) {
                attributes.put(targetAttr, value);
            }
        });
        
        // Ajout d'attributs de traçabilité
        attributes.put("migrationDate", Instant.now().toString());
        attributes.put("sourceSystem", config.getSourceType().toString());
        attributes.put("legacyId", legacyUser.getId());
        
        return attributes;
    }
}
```

#### 3. Validation Service

```java
@Service
public class ValidationService {
    
    private static final Pattern EMAIL_PATTERN = 
        Pattern.compile("^[A-Za-z0-9+_.-]+@([A-Za-z0-9.-]+\\.[A-Za-z]{2,})$");
    
    public ValidationResult validateLegacyUser(LegacyUser user) {
        ValidationResult result = new ValidationResult();
        
        // Validation email
        if (user.getEmail() == null || !EMAIL_PATTERN.matcher(user.getEmail()).matches()) {
            result.addError("Invalid or missing email");
        }
        
        // Validation nom
        if (user.getFirstName() == null || user.getFirstName().trim().isEmpty()) {
            result.addError("Missing first name");
        }
        
        if (user.getLastName() == null || user.getLastName().trim().isEmpty()) {
            result.addError("Missing last name");
        }
        
        // Validation unicité email
        if (isDuplicateEmail(user.getEmail())) {
            result.addError("Duplicate email detected");
        }
        
        return result;
    }
    
    public ValidationResult validateAccessWeaverUser(AccessWeaverUser user) {
        ValidationResult result = new ValidationResult();
        
        // Validation format AccessWeaver
        if (user.getTenantId() == null || user.getTenantId().trim().isEmpty()) {
            result.addError("Missing tenant ID");
        }
        
        if (user.getRoles() == null || user.getRoles().isEmpty()) {
            result.addWarning("User has no roles assigned");
        }
        
        // Validation contraintes business
        if (user.getRoles().size() > 10) {
            result.addWarning("User has many roles (" + user.getRoles().size() + ")");
        }
        
        return result;
    }
    
    private boolean isDuplicateEmail(String email) {
        // Vérification dans la cache des emails déjà traités
        return processedEmails.contains(email.toLowerCase());
    }
}
```

### 📋 Data Migration Checklist

#### Pré-Migration
- [ ] **Backup complet** du système source
- [ ] **Analyse qualité** des données source
- [ ] **Mapping détaillé** des schémas
- [ ] **Tests transformation** sur échantillon
- [ ] **Validation règles business**

#### Migration
- [ ] **Migration mode read-only** du source
- [ ] **Exécution ETL** avec monitoring
- [ ] **Validation données** post-import
- [ ] **Tests d'intégrité** référentielle
- [ ] **Validation performance** AccessWeaver

#### Post-Migration
- [ ] **Reconciliation complète** des données
- [ ] **Tests fonctionnels** end-to-end
- [ ] **Validation avec utilisateurs** métier
- [ ] **Documentation** des écarts
- [ ] **Plan de correction** des anomalies

---
