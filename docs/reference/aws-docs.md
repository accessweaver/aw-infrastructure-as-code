# 📖 Documentation AWS

## Introduction

Ce document centralise les ressources de documentation AWS utiles pour l'infrastructure, le développement et les tests chez AccessWeaver. Il sert de référence rapide pour localiser les informations pertinentes concernant les différents services AWS que nous utilisons.

---

## Documentation Générale AWS

| Catégorie | Lien | Description |
|------------|------|-------------|
| **Documentation AWS** | [AWS Documentation](https://docs.aws.amazon.com/) | Portail principal de documentation AWS |
| **Architecture** | [AWS Well-Architected](https://aws.amazon.com/architecture/well-architected/) | Bonnes pratiques d'architecture sur AWS |
| **Centre d'Architecture** | [AWS Architecture Center](https://aws.amazon.com/architecture/) | Patterns, diagrammes et meilleures pratiques |
| **Solutions** | [AWS Solutions](https://aws.amazon.com/solutions/) | Solutions préconstruites pour scénarios communs |
| **Formations** | [AWS Training](https://aws.amazon.com/training/) | Cours et certifications officiels |
| **Blog Technique** | [AWS Blog](https://aws.amazon.com/blogs/aws/) | Annonces et tutoriels techniques |

---

## Documentation de Services par Catégorie

### Services Réseau

| Service | Documentation | Guides & Tutoriels |
|---------|---------------|--------------------|
| **VPC** | [VPC Documentation](https://docs.aws.amazon.com/vpc/) | [Conception de VPC](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-design-patterns.html) |
| **Route 53** | [Route 53 Documentation](https://docs.aws.amazon.com/route53/) | [Contrôle de santé](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover.html) |
| **CloudFront** | [CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/) | [Sécurité CloudFront](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/security.html) |
| **API Gateway** | [API Gateway Documentation](https://docs.aws.amazon.com/apigateway/) | [Tests d'API](https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-test-method.html) |

### Services Calcul & Conteneurs

| Service | Documentation | Guides & Tutoriels |
|---------|---------------|--------------------|
| **ECS** | [ECS Documentation](https://docs.aws.amazon.com/ecs/) | [Tests de services ECS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-auto-scaling.html) |
| **Lambda** | [Lambda Documentation](https://docs.aws.amazon.com/lambda/) | [Tests Lambda](https://docs.aws.amazon.com/lambda/latest/dg/testing-functions.html) |
| **ECR** | [ECR Documentation](https://docs.aws.amazon.com/ecr/) | [Scanning d'images](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning.html) |
| **EC2** | [EC2 Documentation](https://docs.aws.amazon.com/ec2/) | [Automatisation avec SSM](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-automation.html) |

### Services Stockage & Bases de données

| Service | Documentation | Guides & Tutoriels |
|---------|---------------|--------------------|
| **S3** | [S3 Documentation](https://docs.aws.amazon.com/s3/) | [Performance S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/optimizing-performance.html) |
| **RDS** | [RDS Documentation](https://docs.aws.amazon.com/rds/) | [Multi-AZ & Réplication](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html) |
| **DynamoDB** | [DynamoDB Documentation](https://docs.aws.amazon.com/dynamodb/) | [Tests DynamoDB](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Testing.DynamoDBLocal.html) |
| **ElastiCache** | [ElastiCache Documentation](https://docs.aws.amazon.com/elasticache/) | [Patterns de mise en cache](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/Strategies.html) |

---

## Documentation pour Tests AWS

### Tests d'Infrastructure

| Catégorie | Documentation | Description |
|------------|---------------|-------------|
| **CloudFormation** | [Tests CloudFormation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/continuous-delivery-codepipeline-cfn-artifacts.html) | Tests des templates CloudFormation |
| **CodeBuild** | [CodeBuild pour Tests](https://docs.aws.amazon.com/codebuild/latest/userguide/test-reporting.html) | Rapports de tests automatisés |
| **Terratest** | [Guide Terratest](https://terratest.gruntwork.io/docs/getting-started/quick-start/) | Tests d'infrastructure Terraform |
| **AWS CDK** | [Tests CDK](https://docs.aws.amazon.com/cdk/latest/guide/testing.html) | Tests des constructions CDK |

### Tests de Sécurité

| Service | Documentation | Guides & Tutoriels |
|---------|---------------|--------------------|
| **Security Hub** | [Security Hub Documentation](https://docs.aws.amazon.com/securityhub/) | [Intégration des checks](https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-standards.html) |
| **IAM Access Analyzer** | [Access Analyzer Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer.html) | [Validation des politiques](https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-policy-validation.html) |
| **Inspector** | [Inspector Documentation](https://docs.aws.amazon.com/inspector/) | [Scanning de vulnérabilités](https://docs.aws.amazon.com/inspector/latest/user/what-is-inspector.html) |
| **GuardDuty** | [GuardDuty Documentation](https://docs.aws.amazon.com/guardduty/) | [Détection de menaces](https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_findings.html) |

### Tests de Performance

| Service | Documentation | Guides & Tutoriels |
|---------|---------------|--------------------|
| **CloudWatch** | [CloudWatch Documentation](https://docs.aws.amazon.com/cloudwatch/) | [Métriques personnalisées](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/publishingMetrics.html) |
| **X-Ray** | [X-Ray Documentation](https://docs.aws.amazon.com/xray/) | [Traçage d'applications](https://docs.aws.amazon.com/xray/latest/devguide/xray-services.html) |
| **Load Testing** | [AWS Blog - Load Testing](https://aws.amazon.com/blogs/devops/performance-testing-on-aws-cloud/) | Guide pratique pour tests de charge |

### Tests de Résilience

| Service | Documentation | Guides & Tutoriels |
|---------|---------------|--------------------|
| **Fault Injection Service** | [FIS Documentation](https://docs.aws.amazon.com/fis/) | [Expériences FIS](https://docs.aws.amazon.com/fis/latest/userguide/experiments.html) |
| **Resilience Hub** | [Resilience Hub Documentation](https://docs.aws.amazon.com/resilience-hub/) | [Évaluation de résilience](https://docs.aws.amazon.com/resilience-hub/latest/userguide/resiliency-assessment.html) |
| **AWS GameDay** | [GameDay Documentation](https://gameday.workshop.aws/) | Simulation d'incidents |

---

## Documentation Spécifique à Java 21 sur AWS

| Catégorie | Documentation | Description |
|------------|---------------|-------------|
| **Lambda Java 21** | [Java 21 Lambda](https://docs.aws.amazon.com/lambda/latest/dg/lambda-java.html) | Développement Lambda avec Java 21 |
| **Corretto 21** | [Amazon Corretto 21](https://docs.aws.amazon.com/corretto/latest/corretto-21-ug/what-is-corretto-21.html) | Distribution Amazon de OpenJDK 21 |
| **ECS Java** | [Java Applications sur ECS](https://aws.amazon.com/blogs/containers/optimizing-java-applications-on-amazon-ecs/) | Optimisation d'applications Java sur ECS |
| **Spring Boot sur AWS** | [Spring Boot AWS](https://spring.io/guides/tutorials/spring-boot-kotlin-aws/) | Intégration Spring Boot avec services AWS |

## Tests spécifiques pour AWS Lambda avec Java 21

```java
// Extrait de la documentation AWS pour tester les fonctions Lambda Java 21
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import org.junit.jupiter.api.Test;
import static org.mockito.Mockito.mock;
import static org.junit.jupiter.api.Assertions.assertEquals;

public class MyLambdaTest {

    @Test
    public void testFunction() {
        // Préparation
        MyLambdaFunction lambdaFunction = new MyLambdaFunction();
        Context context = mock(Context.class);
        MyEvent testEvent = new MyEvent("testValue");
        
        // Exécution
        MyResponse response = lambdaFunction.handleRequest(testEvent, context);
        
        // Vérification
        assertEquals("processed: testValue", response.getMessage());
    }
}
```

---

## Guides AWS pour Terraform

| Catégorie | Documentation | Description |
|------------|---------------|-------------|
| **AWS Provider** | [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) | Documentation officielle du provider AWS |
| **AWS Modules** | [Terraform AWS Modules](https://registry.terraform.io/namespaces/terraform-aws-modules) | Modules AWS communautaires |
| **AWS Examples** | [AWS Terraform Examples](https://github.com/terraform-providers/terraform-provider-aws/tree/main/examples) | Exemples de code Terraform AWS |
| **Terratest AWS** | [Terratest AWS Modules](https://terratest.gruntwork.io/docs/reference/modules/aws/) | Modules Terratest spécifiques à AWS |

### Exemple de Test Terraform AWS avec Terratest

```go
// Extrait de documentation pour tester des ressources AWS avec Terratest
package test

import (
	"fmt"
	"testing"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestS3Bucket(t *testing.T) {
	// Générer un nom unique pour éviter les conflits
	uniqueName := random.UniqueId()
	bucketName := fmt.Sprintf("terratest-s3-example-%s", uniqueName)
	
	// Configuration Terraform
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/s3",
		Vars: map[string]interface{}{
			"bucket_name": bucketName,
			"versioning_enabled": true,
		},
	})
	
	// Nettoyage à la fin
	defer terraform.Destroy(t, terraformOptions)
	
	// Déployer
	terraform.InitAndApply(t, terraformOptions)
	
	// Vérifier la création
	aws.AssertS3BucketExists(t, "eu-west-1", bucketName)
	
	// Vérifier le versioning
	actualStatus := aws.GetS3BucketVersioning(t, "eu-west-1", bucketName)
	assert.Equal(t, "Enabled", actualStatus)
}
```

---

## Ressources Spécifiques AccessWeaver

### Wikis et Guides Internes

- [Wiki de Tests AWS AccessWeaver](../internal/aws-testing-wiki.md)
- [Guide d'Environnements AWS](../internal/aws-environments.md)
- [Standards AWS AccessWeaver](../internal/aws-standards.md)

### Ressources pour Java 21 sur AWS

- [Guide d'Optimisation Java 21 pour AWS](../internal/java21-aws-optimizations.md)
- [Métriques et Alertes AWS pour Java](../internal/java-aws-monitoring.md)

---

## Communauté AWS

- [AWS re:Post](https://repost.aws/) - Q&A et discussions techniques
- [AWS GitHub](https://github.com/aws) - Projets open-source AWS
- [AWS DevOps Blog](https://aws.amazon.com/blogs/devops/) - Articles sur DevOps avec AWS
- [AWS Java Development Blog](https://aws.amazon.com/blogs/developer/category/programing-language/java/) - Articles spécifiques Java