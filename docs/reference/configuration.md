# 🔧 Configuration

## Introduction

Ce document décrit les configurations standards utilisées chez AccessWeaver pour les environnements, les outils de développement, de test et d'infrastructure. Ces configurations sont essentielles pour assurer la cohérence, la reproductibilité et la fiabilité de nos environnements.

---

## Configuration des Environnements

### Environnements Standards

| Environnement | Usage | Configuration | Accès |
|--------------|-------|---------------|-------|
| **dev** | Développement | Éphémère, ressources minimales | Développeurs |
| **integration** | Tests d'intégration | Semi-permanent, données de test | Développeurs, CI/CD |
| **staging** | Tests de pré-production | Mirror de production, données synthétiques | Testeurs, DevOps |
| **perf** | Tests de performance | Dimensionnement production, isolé | DevOps, Testeurs |
| **prod** | Production | Haute disponibilité, multi-AZ | Restreint |

### Paramètres par Environnement

```yaml
# Exemple de configuration par environnement (terraform.tfvars)
dev:
  vpc_cidr: "10.10.0.0/16"
  instance_type: "t3.medium"
  rds_instance: "db.t3.medium"
  multi_az: false
  backup_retention: 3
  log_retention_days: 30

integration:
  vpc_cidr: "10.20.0.0/16"
  instance_type: "t3.large"
  rds_instance: "db.t3.large"
  multi_az: false
  backup_retention: 7
  log_retention_days: 60

staging:
  vpc_cidr: "10.30.0.0/16"
  instance_type: "m5.large"
  rds_instance: "db.m5.large"
  multi_az: true
  backup_retention: 14
  log_retention_days: 90

production:
  vpc_cidr: "10.40.0.0/16"
  instance_type: "m5.xlarge"
  rds_instance: "db.m5.xlarge"
  multi_az: true
  backup_retention: 30
  log_retention_days: 365
```

---

## Configuration des Outils de Test

### Tests Java 21

#### JUnit 5

```xml
<!-- Configuration Maven pour tests Java 21 avec JUnit 5 -->
<dependencies>
    <dependency>
        <groupId>org.junit.jupiter</groupId>
        <artifactId>junit-jupiter</artifactId>
        <version>5.10.0</version>
        <scope>test</scope>
    </dependency>
    <dependency>
        <groupId>org.junit.platform</groupId>
        <artifactId>junit-platform-suite</artifactId>
        <version>1.10.0</version>
        <scope>test</scope>
    </dependency>
    <dependency>
        <groupId>org.mockito</groupId>
        <artifactId>mockito-junit-jupiter</artifactId>
        <version>5.4.0</version>
        <scope>test</scope>
    </dependency>
    <dependency>
        <groupId>org.assertj</groupId>
        <artifactId>assertj-core</artifactId>
        <version>3.24.2</version>
        <scope>test</scope>
    </dependency>
</dependencies>

<build>
    <plugins>
        <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-surefire-plugin</artifactId>
            <version>3.1.2</version>
            <configuration>
                <includes>
                    <include>**/*Test.java</include>
                </includes>
                <excludes>
                    <exclude>**/*IntegrationTest.java</exclude>
                </excludes>
                <argLine>--enable-preview</argLine>
            </configuration>
        </plugin>
        <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-failsafe-plugin</artifactId>
            <version>3.1.2</version>
            <configuration>
                <includes>
                    <include>**/*IntegrationTest.java</include>
                </includes>
                <argLine>--enable-preview</argLine>
            </configuration>
            <executions>
                <execution>
                    <goals>
                        <goal>integration-test</goal>
                        <goal>verify</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
        <plugin>
            <groupId>org.jacoco</groupId>
            <artifactId>jacoco-maven-plugin</artifactId>
            <version>0.8.10</version>
            <executions>
                <execution>
                    <goals>
                        <goal>prepare-agent</goal>
                    </goals>
                </execution>
                <execution>
                    <id>report</id>
                    <phase>test</phase>
                    <goals>
                        <goal>report</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
    </plugins>
</build>
```

#### Testcontainers

```properties
# testcontainers.properties
docker.client.strategy=org.testcontainers.dockerclient.EnvironmentAndSystemPropertyClientProviderStrategy
testcontainers.reuse.enable=true
```

```java
// Configuration Java pour Testcontainers avec PostgreSQL
@SpringBootTest
@Testcontainers
class DatabaseIntegrationTest {
    
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15.3")
        .withDatabaseName("integration-tests-db")
        .withUsername("test")
        .withPassword("test")
        .withInitScript("init.sql");
    
    @DynamicPropertySource
    static void registerPgProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }
    
    // Tests...
}
```

### Tests d'Infrastructure

#### Terratest

```go
// terratest/go.mod
module github.com/accessweaver/infrastructure-tests

go 1.21

require (
	github.com/gruntwork-io/terratest v0.44.0
	github.com/stretchr/testify v1.8.4
)
```

```go
// terratest/modules/vpc/vpc_test.go
package test

import (
	"testing"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/stretchr/testify/assert"
)

func TestVpcModule(t *testing.T) {
	awsRegion := "eu-west-1"

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/vpc",
		Vars: map[string]interface{}{
			"environment": "test",
			"vpc_cidr": "10.100.0.0/16",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	vpcId := terraform.Output(t, terraformOptions, "vpc_id")
	aws.VerifyVpcExists(t, vpcId, awsRegion)
}
```

#### TFLint

```hcl
# .tflint.hcl
plugin "aws" {
  enabled = true
  version = "0.23.1"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}
```

---

## Configuration des Tests de Sécurité

### SAST/SCA

```yaml
# .checkov.yml
directory:
  - terraform/
  - src/
download-external-modules: true
framework:
  - terraform
  - secrets
  - dockerfile
check:
  - CKV_AWS_*
  - CKV_DOCKER_*
skip-check:
  - CKV_AWS_123  # Skip AWS S3 server access logging check
output: sarif
```

```yaml
# .tfsec.yml
exclude:
  - AWS018  # S3 bucket logging not required for test buckets

severity-overrides:
  AWS046: ERROR  # Treat IAM policy as ERROR instead of WARNING

minimum-severity: HIGH  # Only report HIGH and CRITICAL
```

### Tests DAST

```yaml
# zap-scan.yml
zap-api-scan:
  target: https://api-staging.accessweaver.com
  api: openapi.json
  rules:
    - 10010  # CSRF
    - 10020  # X-Frame-Options
  context:
    name: "AccessWeaver API"
    authentication:
      method: "bearer-token"
      token: "${AUTH_TOKEN}"
  alertFilters:
    - riskLevel: "LOW"
      status: "ignore"
```

---

## Configuration CI/CD pour Tests

### Jenkins

```groovy
// Jenkinsfile
pipeline {
    agent {
        docker {
            image 'accessweaver/java21-build:latest'
            args '-v $HOME/.m2:/root/.m2'
        }
    }
    
    environment {
        MAVEN_OPTS = '-Xmx3g'
        JAVA_TOOL_OPTIONS = '--enable-preview'
    }
    
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean compile'
            }
        }
        
        stage('Unit Tests') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                    jacoco()
                }
            }
        }
        
        stage('Integration Tests') {
            steps {
                sh 'mvn verify -DskipUnitTests'
            }
            post {
                always {
                    junit 'target/failsafe-reports/*.xml'
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                sh 'mvn org.owasp:dependency-check-maven:check'
                sh 'checkov -d .'
            }
            post {
                always {
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        reportDir: 'target',
                        reportFiles: 'dependency-check-report.html',
                        reportName: 'Dependency Check Report'
                    ])
                }
            }
        }
        
        stage('Infrastructure Tests') {
            environment {
                AWS_ACCESS_KEY_ID = credentials('aws-test-key-id')
                AWS_SECRET_ACCESS_KEY = credentials('aws-test-access-key')
            }
            steps {
                dir('tests/infrastructure') {
                    sh 'go test -v ./...'
                }
            }
        }
    }
}
```

### GitHub Actions

```yaml
# .github/workflows/test.yml
name: Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up JDK 21
        uses: actions/setup-java@v3
        with:
          java-version: '21'
          distribution: 'temurin'
          cache: maven
      
      - name: Run Unit Tests
        run: mvn test
      
      - name: Run Integration Tests
        run: mvn verify -DskipUnitTests
      
      - name: Upload Test Results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: test-results
          path: |
            target/surefire-reports/*.xml
            target/failsafe-reports/*.xml
      
      - name: SonarQube Analysis
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        run: mvn org.sonarsource.scanner.maven:sonar-maven-plugin:sonar

  infrastructure:
    runs-on: ubuntu-latest
    needs: test
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Go
        uses: actions/setup-go@v3
        with:
          go-version: '1.21'
      
      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.6
      
      - name: Run Infrastructure Tests
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_TEST_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_TEST_SECRET_ACCESS_KEY }}
        run: |
          cd tests/infrastructure
          go test -v ./...
```

---

## Ressources et Outils Complémentaires

### Documentation Interne

- [Stratégie de Test](../reference/testing-strategy.md)
- [Outillage d'Automation](../reference/automation.md)
- [Scripts Utilitaires](../reference/scripts.md)

### Ressources Externes

- [JUnit 5 User Guide](https://junit.org/junit5/docs/current/user-guide/)
- [Testcontainers Documentation](https://www.testcontainers.org/)
- [Terratest Documentation](https://terratest.gruntwork.io/docs/)