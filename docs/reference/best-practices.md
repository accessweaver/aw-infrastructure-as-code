# 💡 Meilleures Pratiques

## Introduction

Ce document présente les meilleures pratiques adoptées chez AccessWeaver pour le développement, les tests et l'opération de notre infrastructure et applications. Ces pratiques sont établies pour garantir la qualité, la sécurité, la scalabilité et la maintenabilité de notre plateforme.

---

## Meilleures Pratiques de Développement

### Java 21

| Pratique | Description | Bénéfice |
|----------|-------------|----------|
| **Utiliser les records** | `record UserDto(String id, String name) {}` | Immuabilité, simplicité, lisibilité |
| **Pattern matching** | `if (obj instanceof String s && s.length() > 0) {}` | Code plus expressif et concis |
| **Text blocks** | `String sql = """SELECT * FROM users WHERE id = ?;""";` | Meilleure lisibilité pour les chaînes multi-lignes |
| **Switch expressions** | `var result = switch(status) { case ACTIVE -> "A"; default -> "I"; };` | Évite les oublis de `break` et améliore la sûreté |
| **Virtual threads** | `try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {}` | Concurrence légère et performante |

### Spring Boot 3.x

| Pratique | Description | Bénéfice |
|----------|-------------|----------|
| **Structured logging** | `log.info("User created: {}", user.id());` | Logs structurés facilement analysables |
| **Non-blocking endpoints** | `public Mono<Response> getAsync()` | Meilleure scalabilité |
| **Configuration externalisée** | `@ConfigurationProperties(prefix = "app")` | Séparation config/code |
| **Injection de dépendances** | `record Service(Repository repo) {}` | Facilite les tests et l'inversion de contrôle |

---

## Meilleures Pratiques de Tests

### Principes Généraux

- **Test Pyramid**: Prioriser la hiérarchie tests unitaires > tests d'intégration > tests fonctionnels/E2E
- **Shift-Left Testing**: Intégrer les tests au plus tôt dans le cycle de développement
- **Tests Automatisés**: Automatiser tous les tests répétitifs
- **Test-Driven Development (TDD)**: Écrire les tests avant le code pour les fonctionnalités critiques
- **Revue de Code et Tests**: Revue systématique des tests lors des pull requests

### Tests Unitaires (Java 21)

```java
// Exemple de test unitaire avec JUnit 5 et Java 21
@DisplayName("Tests du service utilisateur")
class UserServiceTest {
    
    private final UserRepository mockRepo = mock(UserRepository.class);
    private final UserService service = new UserService(mockRepo);
    
    @Test
    @DisplayName("Doit créer un utilisateur avec succès")
    void shouldCreateUser() {
        // Given
        var newUser = new UserDto(null, "John Doe");
        var savedUser = new UserDto("123", "John Doe");
        when(mockRepo.save(any())).thenReturn(savedUser);
        
        // When
        var result = service.createUser(newUser);
        
        // Then
        assertThat(result.id()).isNotNull();
        assertThat(result.name()).isEqualTo("John Doe");
        verify(mockRepo).save(any());
    }
}
```

### Tests d'Intégration

```java
// Exemple de test d'intégration Spring Boot 3 avec Testcontainers
@SpringBootTest
@Testcontainers
class UserIntegrationTest {
    
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15.3")
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test");
    
    @DynamicPropertySource
    static void registerPgProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }
    
    @Autowired
    private TestRestTemplate restTemplate;
    
    @Test
    void shouldCreateAndRetrieveUser() {
        // Given
        var newUser = new UserDto(null, "John Doe");
        
        // When
        var createResponse = restTemplate.postForEntity("/api/users", newUser, UserDto.class);
        var userId = createResponse.getBody().id();
        var getResponse = restTemplate.getForEntity("/api/users/" + userId, UserDto.class);
        
        // Then
        assertThat(createResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(getResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(getResponse.getBody().name()).isEqualTo("John Doe");
    }
}
```

### Tests d'Infrastructure

```go
// Exemple de test d'infrastructure avec Terratest
func TestVpcModule(t *testing.T) {
	// Arrange
	t.Parallel()
	awsRegion := "eu-west-1"

	// Unique ID pour éviter les conflits
	randomId := strings.ToLower(random.UniqueId())
	vpcName := fmt.Sprintf("terratest-%s", randomId)

	// Path vers le module Terraform à tester
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/vpc",
		Vars: map[string]interface{}{
			"vpc_name": vpcName,
			"cidr_block": "10.0.0.0/16",
			"azs": []string{"eu-west-1a", "eu-west-1b"},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	})

	// Clean up resources
	defer terraform.Destroy(t, terraformOptions)

	// Deploy
	terraform.InitAndApply(t, terraformOptions)

	// Validate
	vpcId := terraform.Output(t, terraformOptions, "vpc_id")
	aws.VerifyVpcExists(t, vpcId, awsRegion)

	tags := aws.GetTagsForVpc(t, vpcId, awsRegion)
	assert.Equal(t, vpcName, tags["Name"])
}
```

---

## Meilleures Pratiques pour AWS

### Sécurité

- **Principe du moindre privilège** - Attribuer le minimum de permissions nécessaires
- **MFA pour les utilisateurs IAM** - Activer l'authentification multi-facteurs
- **Chiffrement des données au repos** - Utiliser KMS et SSE pour les données sensibles
- **Chiffrement en transit** - Utiliser TLS 1.3+ pour toutes les communications
- **Rotation régulière des clés** - Implémenter une rotation automatique des clés de chiffrement

### Haute Disponibilité

- **Multi-AZ** - Déployer dans plusieurs zones de disponibilité
- **Auto Scaling** - Adapter automatiquement la capacité en fonction de la charge
- **Circuit Breaker** - Implémenter un pattern de disjoncteur pour éviter les pannes en cascade
- **Backoff Exponentiel** - Implémenter une stratégie de retry avec backoff exponentiel

---

## Meilleures Pratiques DevOps

### CI/CD

- **Pipeline as Code** - Définir les pipelines en code (Jenkinsfile, GitHub Actions workflow)
- **Branch Protection** - Exiger revue de code et tests réussis avant merge
- **Semantic Versioning** - Utiliser SemVer pour les versions des artefacts
- **Canary Releases** - Déployer progressivement les nouvelles versions

### Infrastructure as Code

- **Terraform Modules** - Créer des modules réutilisables et testés
- **Dépendances Explicites** - Déclarer explicitement les dépendances entre ressources
- **État Partagé** - Stocker l'état Terraform dans un backend distant (S3 + DynamoDB)
- **Verrouillage d'État** - Utiliser DynamoDB pour le verrouillage d'état

---

## Meilleures Pratiques de Tests Spécifiques à AccessWeaver

### Tests de Qualité de Code

| Outil | Usage | Configuration |
|-------|-------|---------------|
| **SonarQube** | Analyse de code statique | Quality Gate: 80% couverture de tests |
| **SpotBugs** | Détection de bugs potentiels | Bloquer sur HIGH/CRITICAL |
| **Checkstyle** | Vérification de style | Standard Google Java Style |
| **PMD** | Analyse de code | Règles personnalisées AccessWeaver |

### Tests AWS

- **Tests des Politiques IAM** - Utiliser IAM Access Analyzer
- **Tests de Conformité** - Utiliser AWS Config Rules
- **Tests de Performance Cloud** - CloudWatch Synthetics Canaries
- **Tests de Sécurité Cloud** - AWS Security Hub et GuardDuty

### Tests Spring Boot 3

- **Tests Slices** - Utiliser `@WebMvcTest`, `@DataJpaTest`, etc.
- **Tests de Configuration** - Vérifier l'injection des propriétés de configuration
- **Tests de Ressources** - Vérifier la disponibilité des ressources externes
- **Tests de API Documentation** - Vérifier la conformité OpenAPI

---

## Checklist des Tests

### Avant Pull Request

- [ ] Tous les tests unitaires passent
- [ ] Couverture de code > 80% pour les nouveaux composants
- [ ] Les tests d'intégration pertinents passent
- [ ] Aucun problème de sécurité détecté par les outils d'analyse statique
- [ ] Documentation des tests mise à jour

### Avant Release

- [ ] Tests d'infrastructure complets réussis
- [ ] Tests de performance conformés aux SLAs
- [ ] Tests de sécurité OWASP Top 10 réussis
- [ ] Tests de déploiement/rollback réussis
- [ ] Tests de résilience et chaos réussis

---

## Ressources et Outils Complémentaires

### Documentation Interne

- [Stratégie de Test](../reference/testing-strategy.md)
- [Outillage d'Automation](../reference/automation.md)
- [Debugging](../reference/debugging.md)

### Ressources Externes

- [Java 21 Documentation](https://docs.oracle.com/en/java/javase/21/)
- [Spring Boot Testing](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.testing)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Testing Microservices](https://martinfowler.com/articles/microservice-testing/)