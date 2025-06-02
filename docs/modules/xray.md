# 🔍 Module X-Ray - AccessWeaver Infrastructure

**Version :** 1.0  
**Date :** Juin 2025  
**Module :** modules/xray  
**Responsable :** Équipe Platform AccessWeaver

---

## 🔧 Configuration Terraform

### Structure du Module

Le module X-Ray implémente une solution complète de tracé distribué avec la structure suivante :

```hcl
modules/
└── xray/
    ├── main.tf            # Configuration principale d'X-Ray
    ├── variables.tf       # Déclaration des variables d'entrée
    ├── outputs.tf         # Sorties du module
    ├── iam.tf             # Rôles IAM et politiques pour X-Ray
    ├── daemon.tf          # Configuration du daemon X-Ray
    ├── sampling.tf        # Règles d'échantillonnage
    ├── groups.tf          # Groupes X-Ray et filtres
    └── monitoring.tf      # Intégration CloudWatch
```

### Utilisation du Module

```hcl
module "xray" {
  source = "../../modules/xray"
  
  environment                  = "production"
  sampling_rate                = 0.2
  error_sampling_rate          = 1.0
  encryption_key_id            = module.kms.xray_key_id
  trace_retention_in_days      = 30
  
  # Configuration des groupes de tracé
  enable_custom_groups         = true
  error_group_filter_expression = "error = true"
  latency_group_filter_expression = "responsetime > 1"
  
  # Intégration avec daemon
  daemon_image                 = "amazon/aws-xray-daemon:latest"
  daemon_cpu                   = 256
  daemon_memory                = 512
  
  # Monitoring
  create_dashboard             = true
  enable_insights              = true
  create_alarms                = true
  alarm_sns_topic_arn          = module.monitoring.alert_topic_arn
  
  tags = {
    Project     = "AccessWeaver"
    Environment = "production"
    Managed     = "terraform"
  }
}
```

### Variables d'Entrée Principales

| Nom Variable | Type | Description | Défaut |
|--------------|------|-------------|--------|
| `environment` | string | Environnement de déploiement | `"development"` |
| `sampling_rate` | number | Taux d'échantillonnage global | `1.0` |
| `error_sampling_rate` | number | Taux d'échantillonnage pour les erreurs | `1.0` |
| `encryption_key_id` | string | ID de clé KMS pour le chiffrement | `null` |
| `trace_retention_in_days` | number | Durée de conservation des traces | `7` |
| `enable_custom_groups` | bool | Activer les groupes personnalisés | `false` |
| `create_dashboard` | bool | Créer un dashboard CloudWatch | `true` |
| `create_alarms` | bool | Créer des alarmes CloudWatch | `false` |
| `alarm_sns_topic_arn` | string | ARN du topic SNS pour les alertes | `null` |

### Ressources AWS Créées

```hcl
# Règle d'échantillonnage X-Ray
resource "aws_xray_sampling_rule" "custom" {
  rule_name      = "${var.environment}-default-sampling"
  priority       = 1000
  version        = 1
  reservoir_size = 1
  fixed_rate     = var.sampling_rate
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_name   = "*"
  service_type   = "*"
  
  attributes = {
    environment = var.environment
  }
}

# Groupe X-Ray pour les erreurs
resource "aws_xray_group" "errors" {
  count       = var.enable_custom_groups ? 1 : 0
  group_name  = "${var.environment}-errors"
  filter_expression = var.error_group_filter_expression
}

# Rôle IAM pour le daemon X-Ray
resource "aws_iam_role" "xray_daemon" {
  name = "${var.environment}-xray-daemon-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Dashboard CloudWatch pour X-Ray
resource "aws_cloudwatch_dashboard" "xray" {
  count          = var.create_dashboard ? 1 : 0
  dashboard_name = "${var.environment}-xray-monitoring"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/XRay", "Traces", "ServiceType", "AWS::ApiGateway::Stage"],
            ["AWS/XRay", "Traces", "ServiceType", "AWS::Lambda::Function"],
            ["AWS/XRay", "Traces", "ServiceType", "AWS::DynamoDB::Table"]
          ],
          view    = "timeSeries",
          stacked = false,
          title   = "Traces par Service"
        }
      }
      # Autres widgets...
    ]
  })
}
```

### Outputs du Module

| Nom | Description |
|-----|-------------|
| `sampling_rule_arns` | ARNs des règles d'échantillonnage créées |
| `xray_group_arns` | ARNs des groupes X-Ray créés |
| `daemon_role_arn` | ARN du rôle IAM pour le daemon X-Ray |
| `dashboard_arn` | ARN du dashboard CloudWatch (si créé) |
| `xray_policy_json` | JSON de la politique IAM pour l'intégration X-Ray |

---

## 🔗 Intégration des Applications

### Installation des Dépendances

#### Java / Spring Boot

```xml
<!-- pom.xml -->
<dependencies>
  <!-- AWS X-Ray SDK pour Java -->
  <dependency>
    <groupId>com.amazonaws</groupId>
    <artifactId>aws-xray-recorder-sdk-core</artifactId>
    <version>2.11.0</version>
  </dependency>
  
  <!-- Intégration Spring Boot -->
  <dependency>
    <groupId>com.amazonaws</groupId>
    <artifactId>aws-xray-recorder-sdk-spring</artifactId>
    <version>2.11.0</version>
  </dependency>
  
  <!-- Intégration SQL -->
  <dependency>
    <groupId>com.amazonaws</groupId>
    <artifactId>aws-xray-recorder-sdk-sql</artifactId>
    <version>2.11.0</version>
  </dependency>
  
  <!-- Intégration AWS SDK -->
  <dependency>
    <groupId>com.amazonaws</groupId>
    <artifactId>aws-xray-recorder-sdk-aws-sdk</artifactId>
    <version>2.11.0</version>
  </dependency>
</dependencies>
```

### Configuration Spring Boot

```java
// XRayConfig.java
@Configuration
public class XRayConfig {

    @Bean
    public Filter xrayFilter() {
        return new AWSXRayServletFilter("accessweaver-service");
    }
    
    static {
        AWSXRayRecorderBuilder builder = AWSXRayRecorderBuilder.standard()
            .withSegmentListener(new SLF4JSegmentListener())
            .withPlugin(new EC2Plugin())
            .withPlugin(new ECSPlugin());
        
        if (isProduction()) {
            builder.withSamplingStrategy(new CentralizedSamplingStrategy());
        }
        
        AWSXRay.setGlobalRecorder(builder.build());
    }
    
    private static boolean isProduction() {
        return "production".equals(System.getenv("ENVIRONMENT"));
    }
}
```

```java
// Application.java
@SpringBootApplication
@RestController
@EnableXRay  // Activer l'instrumentation X-Ray
public class Application {

    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
    
    @GetMapping("/api/data")
    public ResponseEntity<Data> getData() {
        // Ajouter des annotations personnalisées
        Segment segment = AWSXRay.getCurrentSegment();
        segment.putAnnotation("environment", System.getenv("ENVIRONMENT"));
        segment.putAnnotation("version", "1.0.0");
        
        // Ajouter des métadonnées
        segment.putMetadata("metadata_key", "metadata_value");
        
        // Sous-segment pour opération spécifique
        Subsegment subsegment = AWSXRay.beginSubsegment("getData-processing");
        try {
            Data result = processData();
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            subsegment.addException(e);
            throw e;
        } finally {
            AWSXRay.endSubsegment();
        }
    }
    
    private Data processData() {
        // Logique métier
        return new Data();
    }
}
```

### Configuration pour Lambda

```java
// Handler.java
import com.amazonaws.xray.entities.Subsegment;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.xray.AWSXRay;

public class Handler implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {

    @Override
    public APIGatewayProxyResponseEvent handleRequest(APIGatewayProxyRequestEvent input, Context context) {
        // X-Ray est automatiquement activé pour Lambda, ajouter des annotations personnalisées
        Subsegment subsegment = AWSXRay.beginSubsegment("handleRequest-processing");
        
        try {
            subsegment.putAnnotation("path", input.getPath());
            subsegment.putAnnotation("httpMethod", input.getHttpMethod());
            
            // Traitement de la requête
            return processRequest(input);
        } catch (Exception e) {
            subsegment.addException(e);
            throw e;
        } finally {
            AWSXRay.endSubsegment();
        }
    }
    
    private APIGatewayProxyResponseEvent processRequest(APIGatewayProxyRequestEvent input) {
        // Logique métier
        return new APIGatewayProxyResponseEvent().withStatusCode(200);
    }
}
```

### Bonnes Pratiques d'Instrumentation

1. **Découpe en sous-segments** : Créer des sous-segments pour les opérations significatives (appels DB, API externes)
2. **Annotations pertinentes** : Ajouter des annotations permettant le filtrage efficace des traces
3. **Capture d'exceptions** : Toujours enregistrer les exceptions dans les segments
4. **Métadonnées contextuelles** : Enrichir les segments avec des métadonnées métier
5. **Gestion des segments asynchrones** : Utiliser les entités spécifiques pour le code asynchrone
6. **Traces personnalisées** : Utiliser `AWSXRay.beginSegment()` et `AWSXRay.endSegment()` pour le code non-web
7. **Éviter l'over-instrumentation** : Ne pas instrumenter les méthodes trop petites ou trop fréquemment appelées

---

## 📊 Monitoring et Troubleshooting

### Dashboard de Monitoring X-Ray

Le module crée automatiquement un dashboard CloudWatch pour la visualisation des métriques X-Ray :

| Widget | Métriques | Description |
|--------|-----------|-------------|
| **Traces par Service** | `AWS/XRay/Traces` | Nombre de traces segmentées par type de service |
| **Latence par Service** | `AWS/XRay/ResponseTime` | Temps de réponse moyen par service |
| **Erreurs par Service** | `AWS/XRay/ErrorRate` | Taux d'erreur segmenté par service |
| **Throttling par Service** | `AWS/XRay/ThrottleCount` | Nombre d'opérations limitées par AWS |
| **Utilisation X-Ray** | `AWS/XRay/SegmentCount` | Volume de segments traités par X-Ray |

### Alarmes CloudWatch

Les alarmes suivantes sont configurées par défaut en production :

| Alarme | Condition | Sévérité | Action |
|--------|-----------|----------|--------|
| **Erreurs API élevées** | Taux d'erreur > 5% pendant 5 min | Haute | Notification SNS + PagerDuty |
| **Latence élevée** | P95 > 1000ms pendant 10 min | Moyenne | Notification SNS |
| **Throttling X-Ray** | > 10 throttles en 5 min | Basse | Notification SNS |
| **Traces perdues** | SegmentSendingErrors > 0 | Moyenne | Notification SNS |

### Expressions de Filtrage X-Ray

Voici quelques expressions de filtrage utiles pour le troubleshooting :

```
# Requêtes avec erreurs HTTP 5xx
http.status >= 500

# Requêtes lentes (> 2 secondes)
responsetime > 2

# Requêtes spécifiques à un service ayant échoué
service("auth-service") AND error = true

# Requêtes contenant des exceptions spécifiques
exception.message CONTAINS "OutOfMemory"

# Requêtes avec latence élevée sur DynamoDB
service("AWS::DynamoDB") AND responsetime > 0.1

# Toutes les erreurs d'un utilisateur spécifique
annotation.userId = "12345" AND error = true
```

### Guide de Résolution des Problèmes

#### 1. Traces manquantes

**Symptômes** : Aucune donnée visible dans la console X-Ray

**Solutions** :
- Vérifier que le daemon X-Ray est en cours d'exécution
- Confirmer que les IAM permissions sont correctes
- Vérifier l'instrumentation du code (SDK configuré correctement)
- Examiner les logs du daemon X-Ray pour détecter les erreurs

**Commande utile** :
```bash
# Vérifier les logs du daemon X-Ray
aws logs get-log-events --log-group-name /ecs/xray-daemon --log-stream-name ecs/xray-daemon/{INSTANCE_ID}
```

#### 2. Performances dégradées

**Analyse avec X-Ray** :
1. Consulter la carte des services pour identifier les goulots d'étranglement
2. Utiliser l'expression `responsetime > 1` pour filtrer les requêtes lentes
3. Examiner les sous-segments pour identifier les opérations coûteuses
4. Vérifier les annotations et métadonnées pour le contexte des requêtes lentes

**Optimisations courantes** :
- Optimiser les requêtes de base de données identifiées comme lentes
- Configurer le caching pour les opérations fréquentes
- Augmenter les ressources des services surchargés
- Réduire les dépendances entre services si possible

#### 3. Erreurs en cascade

**Détection** : Utiliser la carte des services pour identifier les services défaillants qui impactent d'autres services

**Mitigation** :
- Implémenter des politiques de retry avec backoff exponentiel
- Configurer des circuit breakers pour isoler les services défaillants
- Définir des timeouts appropriés pour éviter le blocage des ressources
- Ajouter des fallbacks pour les services critiques

### Rapports Opérationnels

Le module fournit des scripts pour générer des rapports périodiques sur les performances :

```bash
#!/bin/bash
# Script de génération de rapport hebdomadaire X-Ray

# Extraction des données X-Ray via AWS CLI
aws xray get-group --group-name "production-errors" > /tmp/xray-group.json

# Requête des traces pour la semaine
END_TIME=$(date +%s)
START_TIME=$(date -d "7 days ago" +%s)

aws xray get-trace-summaries \
  --start-time $START_TIME \
  --end-time $END_TIME \
  --filter-expression "service(\"accessweaver-*\")" \
  > /tmp/trace-summary.json

# Génération du rapport HTML avec statistiques
python3 /opt/scripts/generate-xray-report.py \
  --input /tmp/trace-summary.json \
  --template /opt/templates/weekly-report.html \
  --output /var/www/reports/xray-week-$(date +%Y%m%d).html

# Notification par email
aws ses send-email \
  --source reports@accessweaver.com \
  --destination file://report-recipients.json \
  --message file://email-with-report-link.json
```

---

## 🏗️ Architecture et Implémentation

### Stratégie par Environnement

| Aspect | Development | Staging | Production |
|--------|-------------|---------|------------|
| **🔍 Niveau de tracé** | Détaillé (100%) | Échantillonné (50%) | Sélectif (20% + 100% erreurs) |
| **⏰ Rétention des traces** | 7 jours | 14 jours | 30 jours |
| **🔐 Encryption** | Standard | KMS | KMS avec clefs dédiées |
| **💼 Groupes** | Base | Base + API | Base + API + Métier |
| **🔎 Insights** | Désactivé | Erreurs uniquement | Complet avec anomalies |
| **📈 Métriques** | Basiques | Standard | Avancées |
| **📄 Journalisation** | DEBUG | INFO | WARNING en normal, DEBUG en incident |

### Composants Principaux

Le module X-Ray déploie et configure les composants suivants :

```
┌─────────────────────────────────────────────────────────┐
│                                                           │
│             AWS X-Ray - Composants Déployés                │
│                                                           │
│  ┌────────────────────────────────────────────────┐  │
│  │                  Daemon X-Ray                      │  │
│  │  - Déployé sur ECS en sidecar                      │  │
│  │  - Configuré via ConfigMap (Kubernetes)             │  │
│  │  - Gestion du buffering et de la retransmission      │  │
│  └────────────────────────────────────────────────┘  │
│                                                           │
│  ┌────────────────────────────────────────────────┐  │
│  │                  Groupes X-Ray                     │  │
│  │  - Groupes par services et APIs                     │  │
│  │  - Expressions de filtrage personnalisées           │  │
│  │  - Règles de détection d'anomalies                  │  │
│  └────────────────────────────────────────────────┘  │
│                                                           │
│  ┌────────────────────────────────────────────────┐  │
│  │              Rôles IAM et Politiques                │  │
│  │  - Rôle pour daemon X-Ray                          │  │
│  │  - Rôles pour services instrumentalisés             │  │
│  │  - Politiques de moindre privilège                   │  │
│  └────────────────────────────────────────────────┘  │
│                                                           │
│  ┌────────────────────────────────────────────────┐  │
│  │               Intégration Monitoring                │  │
│  │  - Dashboard CloudWatch                             │  │
│  │  - Alarmes sur latences et taux d'erreurs            │  │
│  │  - Intégration avec services d'alerting              │  │
│  └────────────────────────────────────────────────┘  │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

### Configuration des Services

Le module X-Ray configure tous les services AccessWeaver pour une instrumentalisation optimale :

| Service | Niveau d'Instrumentation | Détails |
|---------|--------------------------|----------|
| **API Gateway** | Complet | Traces pour toutes les requêtes API, annotations pour authentification |
| **Lambda** | Complet | Tracé automatique, ajout de métadonnées personnalisées |
| **ECS Services** | Application | Instrumentation via SDK Spring Boot, annotations métier |
| **DynamoDB** | Client | Tracé automatique des opérations DynamoDB |
| **RDS** | Personnalisé | SQL queries capturées au niveau application |
| **ElastiCache** | Basique | Métriques de latence sur opérations clés |
| **S3** | Basique | Tracé des opérations PUT/GET/DELETE sur objets |

---
## 🎯 Vue d'Ensemble

### Objectif Principal
Le module X-Ray fournit une solution complète de **tracé distribué et d'analyse des performances** pour l'ensemble des services et applications de la plateforme AccessWeaver. Il implémente AWS X-Ray, un service qui collecte des données sur les requêtes traitées par l'application et fournit des outils pour visualiser, filtrer et comprendre ces données afin d'identifier les problèmes et les opportunités d'optimisation.

### Concept de Tracé Distribué

```
┌─────────────────────────────────────────────────────────┐
│                                                           │
│             AWS X-Ray - Tracé Distribué                    │
│                                                           │
│  ┌──────────────┐                                   │
│  │ Utilisateur    │─→┌──────────────┐─→┌──────────────┐─→┌──────────────┐  │
│  └──────────────┘   │ API Gateway   │   │ Service A     │   │ Service B     │  │
│                      └──────────────┘   └──────────────┘   └──────────────┘  │
│                           ↓                ↓                ↓            │
│                      ┌──────────────┐   ┌──────────────┐   ┌──────────────┐  │
│                      │   Lambda     │─→│ DynamoDB     │   │ RDS DB       │  │
│                      └──────────────┘   └──────────────┘   └──────────────┘  │
│                                                           │
│                          X-Ray Daemon                       │
│                               ↓                           │
│  ┌───────────────────────────────────────────────────┐  │
│  │                 AWS X-Ray Service                     │  │
│  └───────────────────────────────────────────────────┘  │
│                               ↓                           │
│  ┌──────────────────────┐   ┌──────────────────────┐  │
│  │ Traces & Segments    │   │ Service Map         │  │
│  └──────────────────────┘   └──────────────────────┘  │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

### Caractéristiques Principales

- **Tracé end-to-end** : Suivi des requêtes depuis l'utilisateur jusqu'aux bases de données
- **Cartographie des services** : Visualisation graphique des relations entre services
- **Analyse des performances** : Identification des goulots d'étranglement et des latences
- **Détection d'anomalies** : Identification des erreurs et comportements anormaux
- **Intégration complète** : Compatible avec tous les services AWS et applications personnalisées
- **Filtrage avancé** : Expressions de filtrage pour analyser des segments spécifiques
- **Alertes automatiques** : Intégration avec CloudWatch pour la surveillance proactive
- **Personnalisation des traces** : Annotations et métadonnées pour enrichir les informations collectées

---