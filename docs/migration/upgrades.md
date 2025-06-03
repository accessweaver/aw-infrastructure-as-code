
## 🔄 Version Upgrades

### Stratégie de Mise à Jour

#### 1. Blue-Green Deployment

```yaml
# blue-green-deployment.yml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: accessweaver-api-gateway
spec:
  replicas: 3
  strategy:
    blueGreen:
      activeService: accessweaver-api-gateway-active
      previewService: accessweaver-api-gateway-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
      prePromotionAnalysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: accessweaver-api-gateway-preview
      postPromotionAnalysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: accessweaver-api-gateway-active
  selector:
    matchLabels:
      app: accessweaver-api-gateway
  template:
    metadata:
      labels:
        app: accessweaver-api-gateway
    spec:
      containers:
      - name: api-gateway
        image: accessweaver/api-gateway:{{.Values.image.tag}}
        ports:
        - containerPort: 8080
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: 8080
          initialDelaySeconds: 5
```

#### 2. Database Migration Service

```java
@Service
@Slf4j
public class DatabaseMigrationService {
    
    private final FlywayService flywayService;
    private final DatabaseHealthChecker healthChecker;
    private final BackupService backupService;
    
    public UpgradeResult executeUpgrade(UpgradeRequest request) {
        log.info("Starting database upgrade from {} to {}", 
                request.getCurrentVersion(), request.getTargetVersion());
        
        UpgradeResult result = new UpgradeResult();
        
        try {
            // 1. Pre-upgrade validation
            validateUpgradeCompatibility(request);
            
            // 2. Create backup
            String backupId = createUpgradeBackup(request);
            result.setBackupId(backupId);
            
            // 3. Execute migration
            executeMigration(request);
            
            // 4. Post-upgrade validation
            validateUpgradeSuccess(request);
            
            result.setStatus(UpgradeStatus.SUCCESS);
            log.info("Database upgrade completed successfully");
            
        } catch (Exception e) {
            log.error("Database upgrade failed", e);
            result.setStatus(UpgradeStatus.FAILED);
            result.setError(e.getMessage());
            
            // Auto-rollback si configuré
            if (request.isAutoRollbackOnFailure()) {
                rollbackUpgrade(result.getBackupId());
            }
        }
        
        return result;
    }
    
    private void validateUpgradeCompatibility(UpgradeRequest request) {
        // Vérification version actuelle
        String currentVersion = flywayService.getCurrentVersion();
        if (!currentVersion.equals(request.getCurrentVersion())) {
            throw new UpgradeException(
                String.format("Version mismatch: expected %s, got %s", 
                            request.getCurrentVersion(), currentVersion));
        }
        
        // Vérification chemin de migration
        if (!isUpgradePathValid(currentVersion, request.getTargetVersion())) {
            throw new UpgradeException(
                String.format("Invalid upgrade path: %s -> %s", 
                            currentVersion, request.getTargetVersion()));
        }
        
        // Vérification ressources système
        validateSystemResources();
    }
    
    private String createUpgradeBackup(UpgradeRequest request) {
        BackupRequest backupRequest = BackupRequest.builder()
            .type(BackupType.FULL)
            .reason("Pre-upgrade backup for version " + request.getTargetVersion())
            .retention(Duration.ofDays(30))
            .build();
            
        return backupService.createBackup(backupRequest);
    }
    
    private void executeMigration(UpgradeRequest request) {
        // Configuration Flyway pour l'upgrade
        FlywayConfig config = FlywayConfig.builder()
            .targetVersion(request.getTargetVersion())
            .validateOnMigrate(true)
            .cleanOnValidationError(false)
            .outOfOrder(false)
            .build();
        
        // Exécution des migrations
        MigrationInfo[] pendingMigrations = flywayService.info().pending();
        log.info("Found {} pending migrations", pendingMigrations.length);
        
        for (MigrationInfo migration : pendingMigrations) {
            log.info("Executing migration: {}", migration.getDescription());
        }
        
        MigrateResult migrateResult = flywayService.migrate(config);
        log.info("Applied {} migrations successfully", migrateResult.migrationsExecuted);
    }
    
    private void validateUpgradeSuccess(UpgradeRequest request) {
        // Vérification version finale
        String finalVersion = flywayService.getCurrentVersion();
        if (!finalVersion.equals(request.getTargetVersion())) {
            throw new UpgradeException(
                String.format("Upgrade incomplete: expected %s, got %s", 
                            request.getTargetVersion(), finalVersion));
        }
        
        // Tests de santé de la base
        HealthCheckResult healthCheck = healthChecker.checkDatabaseHealth();
        if (!healthCheck.isHealthy()) {
            throw new UpgradeException("Database health check failed after upgrade");
        }
        
        // Validation des contraintes d'intégrité
        validateDataIntegrity();
    }
}
```

#### 3. Application Upgrade Controller

```java
@RestController
@RequestMapping("/api/v1/admin/upgrades")
@PreAuthorize("hasRole('ADMIN')")
public class UpgradeController {
    
    private final UpgradeService upgradeService;
    private final UpgradeValidationService validationService;
    
    @PostMapping("/validate")
    public ResponseEntity<UpgradeValidationResult> validateUpgrade(
            @RequestBody UpgradeRequest request) {
        
        UpgradeValidationResult validation = validationService.validateUpgrade(request);
        return ResponseEntity.ok(validation);
    }
    
    @PostMapping("/execute")
    public ResponseEntity<UpgradeResult> executeUpgrade(
            @RequestBody UpgradeRequest request) {
        
        // Validation préalable
        UpgradeValidationResult validation = validationService.validateUpgrade(request);
        if (!validation.isValid()) {
            return ResponseEntity.badRequest()
                .body(UpgradeResult.failed(validation.getErrors()));
        }
        
        // Exécution asynchrone
        CompletableFuture<UpgradeResult> futureResult = 
            upgradeService.executeUpgradeAsync(request);
        
        // Retour immédiat avec ID de suivi
        UpgradeResult response = UpgradeResult.builder()
            .status(UpgradeStatus.IN_PROGRESS)
            .upgradeId(UUID.randomUUID().toString())
            .build();
        
        return ResponseEntity.accepted().body(response);
    }
    
    @GetMapping("/status/{upgradeId}")
    public ResponseEntity<UpgradeStatus> getUpgradeStatus(
            @PathVariable String upgradeId) {
        
        Optional<UpgradeStatus> status = upgradeService.getUpgradeStatus(upgradeId);
        
        return status.map(ResponseEntity::ok)
                    .orElse(ResponseEntity.notFound().build());
    }
    
    @PostMapping("/rollback/{upgradeId}")
    public ResponseEntity<RollbackResult> rollbackUpgrade(
            @PathVariable String upgradeId) {
        
        RollbackResult result = upgradeService.rollbackUpgrade(upgradeId);
        return ResponseEntity.ok(result);
    }
}
```
