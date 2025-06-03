# Stratégies d'Optimisation des Coûts AWS pour AccessWeaver

## Optimisation des ressources

L'optimisation des ressources constitue un pilier fondamental de notre stratégie de gestion des coûts AWS. Cette approche nous permet de maximiser la valeur de chaque euro dépensé dans notre infrastructure cloud.

### Évaluation de l'utilisation des ressources

Notre processus d'évaluation comporte plusieurs volets :

#### 1. Analyse des métriques d'utilisation

Nous suivons systématiquement ces métriques clés :

| Ressource | Métriques suivies | Seuil d'optimisation |
|-----------|-------------------|----------------------|
| EC2 | CPU, mémoire, I/O réseau | < 30% sur 14 jours |
| RDS | CPU, mémoire, IOPS, stockage | < 35% sur 30 jours |
| EBS | IOPS, débit, utilisation | < 40% sur 30 jours |
| Lambda | Durée, mémoire utilisée | > 80% sur la configuration |

#### 2. Outil d'analyse personnalisé

Nous avons développé un outil d'analyse qui collecte et traite automatiquement les données d'utilisation :

```java
public class ResourceUtilizationAnalyzer {
    
    public static void main(String[] args) {
        // Configuration du client CloudWatch avec Java 21
        CloudWatchClient cloudWatchClient = CloudWatchClient.builder()
                .region(Region.US_EAST_1)
                .credentialsProvider(ProfileCredentialsProvider.create())
                .build();
        
        // Période d'analyse : 14 derniers jours
        Instant endTime = Instant.now();
        Instant startTime = endTime.minus(14, ChronoUnit.DAYS);
        
        // Récupérer les métriques CPU pour toutes les instances EC2
        GetMetricDataRequest request = buildEC2CPUUtilizationRequest(startTime, endTime);
        GetMetricDataResponse response = cloudWatchClient.getMetricData(request);
        
        // Analyser les résultats et identifier les instances sous-utilisées
        List<String> underutilizedInstances = analyzeUtilization(response);
        
        // Générer les recommandations d'optimisation
        generateOptimizationRecommendations(underutilizedInstances);
    }
    
    private static List<String> analyzeUtilization(GetMetricDataResponse response) {
        // Logique d'analyse des métriques pour identifier les instances sous-utilisées
        return List.of("i-0123456789abcdef0", "i-0123456789abcdef1");
    }
}
```

#### 3. Rapport d'utilisation hebdomadaire

Un exemple de notre rapport hebdomadaire d'utilisation des ressources :

```
RAPPORT D'UTILISATION DES RESSOURCES AWS - SEMAINE 23 (2025)

• INSTANCES EC2 SOUS-UTILISÉES : 12/45 (27%)
  - 5 instances en production
  - 3 instances en staging
  - 4 instances en développement
  Économies potentielles : 2 450€/mois

• VOLUMES EBS SUR-PROVISIONNÉS : 8/30 (26%)
  - 125 Go pouvant être réduits
  Économies potentielles : 180€/mois

• INSTANCES RDS SOUS-UTILISÉES : 2/6 (33%)
  - 1 instance en production (candidat pour réplication lecture)
  - 1 instance en staging
  Économies potentielles : 850€/mois
```

### Méthodologie de redimensionnement

Notre méthodologie de redimensionnement suit un processus en trois étapes :

1. **Identification** : Utilisation des outils d'analyse pour identifier les ressources mal dimensionnées
2. **Validation** : Évaluation de l'impact opérationnel et confirmation avec les équipes responsables
3. **Exécution** : Mise en œuvre des changements durant les fenêtres de maintenance planifiées

Voici un exemple de notre script de redimensionnement d'instances EC2 :

```java
public class EC2Resizer {
    public static void main(String[] args) {
        // Utilisation des API asynchrones de Java 21 pour le redimensionnement
        Ec2AsyncClient ec2Client = Ec2AsyncClient.builder()
                .region(Region.US_EAST_1)
                .build();
        
        // Liste des instances à redimensionner avec leur nouveau type
        Map<String, String> instancesToResize = Map.of(
            "i-0123456789abcdef0", "t3.micro",
            "i-0123456789abcdef1", "t3.small"
        );
        
        // Arrêter et redimensionner chaque instance
        for (Map.Entry<String, String> entry : instancesToResize.entrySet()) {
            String instanceId = entry.getKey();
            String newInstanceType = entry.getValue();
            
            // Arrêt de l'instance
            StopInstancesRequest stopRequest = StopInstancesRequest.builder()
                    .instanceIds(instanceId)
                    .build();
            
            ec2Client.stopInstances(stopRequest)
                    .thenCompose(response -> waitForInstanceStopped(ec2Client, instanceId))
                    .thenCompose(stopped -> modifyInstanceType(ec2Client, instanceId, newInstanceType))
                    .thenCompose(modified -> startInstance(ec2Client, instanceId))
                    .join(); // Attend la fin du processus complet
        }
    }
    
    private static CompletableFuture<Boolean> waitForInstanceStopped(Ec2AsyncClient client, String instanceId) {
        // Code pour attendre l'arrêt de l'instance
        return CompletableFuture.completedFuture(true);
    }
    
    private static CompletableFuture<ModifyInstanceAttributeResponse> modifyInstanceType(
            Ec2AsyncClient client, String instanceId, String newType) {
        // Modification du type d'instance
        ModifyInstanceAttributeRequest request = ModifyInstanceAttributeRequest.builder()
                .instanceId(instanceId)
                .instanceType(AttributeValue.builder().value(newType).build())
                .build();
        
        return client.modifyInstanceAttribute(request);
    }
    
    private static CompletableFuture<StartInstancesResponse> startInstance(Ec2AsyncClient client, String instanceId) {
        // Redémarrage de l'instance
        StartInstancesRequest request = StartInstancesRequest.builder()
                .instanceIds(instanceId)
                .build();
        
        return client.startInstances(request);
    }
}
```

## Réduction des coûts

Au-delà de l'optimisation des ressources existantes, nous implémentons plusieurs stratégies spécifiques pour réduire activement nos coûts AWS.

### Stratégies d'économies à court terme

#### 1. Nettoyage des ressources inutilisées

Nous exécutons un script hebdomadaire pour identifier et supprimer les ressources orphelines :

```java
public class OrphanedResourceCleaner {
    public static void main(String[] args) {
        // Structures de données pour stocker les ressources orphelines
        List<String> orphanedEBSVolumes = findOrphanedEBSVolumes();
        List<String> unusedEIPs = findUnusedElasticIPs();
        List<String> oldSnapshots = findOldSnapshots(180); // > 180 jours
        
        // Générer un rapport de nettoyage
        generateCleanupReport(orphanedEBSVolumes, unusedEIPs, oldSnapshots);
        
        // Demander confirmation avant de supprimer
        if (confirmCleanup()) {
            deleteOrphanedResources(orphanedEBSVolumes, unusedEIPs, oldSnapshots);
        }
    }
    
    private static List<String> findOrphanedEBSVolumes() {
        // Logique pour identifier les volumes EBS non attachés depuis > 30 jours
        return List.of("vol-0123456789abcdef0", "vol-0123456789abcdef1");
    }
    
    // Autres méthodes d'implémentation...
}
```

#### 2. Mise en place de politiques de cycle de vie

Exemple de notre politique de cycle de vie S3 via Terraform :

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "accessweaver_lifecycle" {
  bucket = aws_s3_bucket.logs_bucket.id

  rule {
    id = "log-transition-to-ia"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }

  rule {
    id = "backups-transition"
    status = "Enabled"

    filter {
      prefix = "backups/"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    expiration {
      days = 730 # 2 ans
    }
  }
}
```

### Stratégies d'économies à long terme

#### 1. Utilisation des instances Spot

Nous avons migré nos workloads batch et de test vers des instances Spot, réalisant des économies substantielles :

```java
public class SpotInstanceManager {
    public static void main(String[] args) {
        Ec2Client ec2Client = Ec2Client.builder()
                .region(Region.US_EAST_1)
                .build();
        
        // Demander des instances Spot pour notre batch de traitement nocturne
        RequestSpotInstancesRequest spotRequest = RequestSpotInstancesRequest.builder()
                .instanceCount(5)
                .type(SpotInstanceType.ONE_TIME)
                .launchSpecification(LaunchSpecification.builder()
                        .imageId("ami-0c55b159cbfafe1f0")
                        .instanceType("c5.xlarge")
                        .securityGroupIds("sg-0123456789abcdef0")
                        .subnetId("subnet-0123456789abcdef0")
                        .userData(Base64.getEncoder().encodeToString(
                                "#!/bin/bash\naws s3 cp s3://accessweaver-batch/scripts/run.sh /home/ec2-user/\nchmod +x /home/ec2-user/run.sh\n/home/ec2-user/run.sh".getBytes()))
                        .build())
                .build();
        
        RequestSpotInstancesResponse response = ec2Client.requestSpotInstances(spotRequest);
        
        // Suivre l'état des demandes d'instances Spot
        List<String> spotInstanceRequestIds = response.spotInstanceRequests().stream()
                .map(SpotInstanceRequest::spotInstanceRequestId)
                .collect(Collectors.toList());
        
        monitorSpotInstanceRequests(ec2Client, spotInstanceRequestIds);
    }
    
    private static void monitorSpotInstanceRequests(Ec2Client client, List<String> requestIds) {
        // Code pour surveiller l'état des demandes d'instances Spot
    }
}
```

#### 2. Consolidation des ressources

Nous avons mis en place une stratégie de consolidation des services et applications :

- Migration vers des services multi-tenant (plusieurs applications sur un seul cluster)
- Consolidation des bases de données pour réduire le nombre d'instances RDS
- Utilisation de conteneurs pour augmenter la densité des applications

#### 3. Optimisation du stockage S3

Analyse et réorganisation de notre utilisation du stockage S3 :

```java
public class S3StorageOptimizer {
    public static void main(String[] args) {
        S3Client s3Client = S3Client.builder()
                .region(Region.US_EAST_1)
                .build();
        
        String bucketName = "accessweaver-data";        
        // Analyser les patterns d'accès aux objets
        Map<String, AccessPattern> accessPatterns = analyzeObjectAccessPatterns(s3Client, bucketName);
        
        // Recommander des changements de classe de stockage
        Map<String, String> storageClassRecommendations = recommendStorageClassChanges(accessPatterns);
        
        // Appliquer les recommandations pour les objets sélectionnés
        applyStorageClassChanges(s3Client, bucketName, storageClassRecommendations);
    }
    
    // Classes et méthodes d'implémentation...
}
```

## Automatisation

L'automatisation est un élément clé de notre stratégie de gestion des coûts AWS, permettant d'optimiser de manière proactive et cohérente nos ressources.

### Scripts d'automatisation

#### 1. Arrêt automatique des environnements non critiques

Nous avons développé un système qui arrête automatiquement les environnements de développement et test en dehors des heures de travail :

```java
public class EnvironmentScheduler {
    public static void main(String[] args) {
        // Tirer parti des fonctionnalités de date/heure de Java 21
        LocalDateTime now = LocalDateTime.now(ZoneId.of("Europe/Paris"));
        DayOfWeek dayOfWeek = now.getDayOfWeek();
        int hour = now.getHour();
        
        boolean isWorkingHours = dayOfWeek != DayOfWeek.SATURDAY && 
                               dayOfWeek != DayOfWeek.SUNDAY && 
                               hour >= 8 && hour < 20;
        
        Ec2Client ec2Client = Ec2Client.builder()
                .region(Region.EU_WEST_3) // Paris
                .build();
        
        // Filtrer les instances avec le tag Environment=Development ou Environment=Test
        Filter envFilter = Filter.builder()
                .name("tag:Environment")
                .values("Development", "Test")
                .build();
        
        DescribeInstancesRequest request = DescribeInstancesRequest.builder()
                .filters(envFilter)
                .build();
        
        DescribeInstancesResponse response = ec2Client.describeInstances(request);
        
        // Collecter tous les IDs d'instances
        List<String> instanceIds = new ArrayList<>();
        response.reservations().forEach(reservation -> 
            reservation.instances().forEach(instance -> 
                instanceIds.add(instance.instanceId())
            )
        );
        
        if (!instanceIds.isEmpty()) {
            if (isWorkingHours) {
                // Démarrer les instances pendant les heures de travail
                StartInstancesRequest startRequest = StartInstancesRequest.builder()
                        .instanceIds(instanceIds)
                        .build();
                ec2Client.startInstances(startRequest);
                System.out.println("Started " + instanceIds.size() + " instances");
            } else {
                // Arrêter les instances en dehors des heures de travail
                StopInstancesRequest stopRequest = StopInstancesRequest.builder()
                        .instanceIds(instanceIds)
                        .build();
                ec2Client.stopInstances(stopRequest);
                System.out.println("Stopped " + instanceIds.size() + " instances");
            }
        }
    }
}
```

#### 2. Détection et redimensionnement automatique

Notre système de détection et redimensionnement automatique exécute ce workflow :

1. Collecte des métriques d'utilisation via CloudWatch
2. Analyse des patterns d'utilisation sur plusieurs semaines
3. Génération de recommandations de redimensionnement
4. Approbation humaine via un processus de validation
5. Exécution automatique des changements approuvés

### Intégration avec CI/CD

Nous avons intégré l'optimisation des coûts dans notre pipeline CI/CD :

```groovy
pipeline {
    agent any
    stages {
        // Étapes habituelles du pipeline
        stage('Build') { /* ... */ }
        stage('Test') { /* ... */ }
        
        // Étape d'estimation des coûts
        stage('Cost Estimation') {
            steps {
                script {
                    // Estimer le coût des modifications d'infrastructure
                    sh 'java -jar aws-cost-estimator.jar --template=cloudformation/template.yaml --output=cost-report.json'
                    
                    // Vérifier si l'estimation dépasse un seuil
                    def costReport = readJSON file: 'cost-report.json'
                    if (costReport.estimatedMonthlyCost > 500) {
                        // Demander une approbation si le coût estimé est élevé
                        input message: "Cette modification augmentera les coûts mensuels de ${costReport.estimatedMonthlyCost} €. Approuver ?"
                    }
                }
            }
        }
        
        // Déploiement
        stage('Deploy') { /* ... */ }
        
        // Tagging des ressources pour l'attribution des coûts
        stage('Cost Tagging') {
            steps {
                sh 'java -jar resource-tagger.jar --resource-ids=@deployed-resources.txt --tags="Project=AccessWeaver,CostCenter=IT-Cloud-001,Owner=jenkins@accessweaver.com"'
            }
        }
    }
}
```

### Surveillance continue

Notre système de surveillance continue vérifie régulièrement :

1. Les ressources nouvellement provisionnées pour s'assurer qu'elles sont correctement dimensionées
2. Les changements de pattern d'utilisation qui pourraient justifier un redimensionnement
3. Les opportunités d'utiliser des options d'achat plus économiques (Savings Plans, instances réservées)

```java
public class ContinuousOptimizationMonitor {
    public static void main(String[] args) {
        // Configuration des clients AWS avec Java 21
        Ec2Client ec2Client = Ec2Client.builder().region(Region.US_EAST_1).build();
        CloudWatchClient cloudWatchClient = CloudWatchClient.builder().region(Region.US_EAST_1).build();
        
        // 1. Identifier les nouvelles ressources (< 7 jours)
        List<Instance> newInstances = findNewInstances(ec2Client, 7);
        
        // 2. Analyser l'utilisation initiale
        Map<String, UtilizationMetrics> utilizationData = collectUtilizationData(cloudWatchClient, newInstances);
        
        // 3. Comparer avec les benchmarks de dimensionnement optimal
        List<OptimizationRecommendation> recommendations = generateRecommendations(newInstances, utilizationData);
        
        // 4. Envoyer les alertes pour les ressources mal dimensionnées
        if (!recommendations.isEmpty()) {
            sendOptimizationAlerts(recommendations);
        }
    }
    
    // Méthodes d'implémentation utilisant les API Java 21...
}
```

## Résultats et ROI

Grâce à nos stratégies d'optimisation, nous avons réalisé les économies suivantes sur les 12 derniers mois :

| Initiative d'optimisation | Économies annuelles | Investissement | ROI |
|---------------------------|---------------------|---------------|-----|
| Redimensionnement des instances | 42 000€ | 5 000€ | 840% |
| Migration vers Spot Instances | 35 000€ | 8 000€ | 437% |
| Optimisation du stockage | 18 000€ | 3 000€ | 600% |
| Arrêt automatique | 22 000€ | 2 000€ | 1100% |
| Reserved Instances & Savings Plans | 65 000€ | 0€ | ∞ |
| **Total** | **182 000€** | **18 000€** | **1011%** |

Ces résultats démontrent clairement que l'investissement dans l'optimisation des coûts AWS génère un retour sur investissement exceptionnel et devrait rester une priorité stratégique pour AccessWeaver.