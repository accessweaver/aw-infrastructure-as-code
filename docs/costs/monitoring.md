# Suivi en Temps Réel des Coûts AWS pour AccessWeaver

## Tableaux de bord CloudWatch

Le suivi en temps réel de nos coûts AWS est essentiel pour maintenir la visibilité et le contrôle de nos dépenses cloud. Nous avons implémenté plusieurs tableaux de bord CloudWatch pour suivre différents aspects de nos coûts.

### Tableau de bord principal

Notre tableau de bord principal fournit une vue d'ensemble des coûts actuels et des tendances. Il est accessible via ce lien interne : [Tableau de bord des coûts AWS](https://console.aws.amazon.com/cloudwatch/home#dashboards:name=AccessWeaver-Cost-Dashboard).

#### Métriques affichées

- Dépenses quotidiennes et tendances sur 7 jours
- Coûts mensuels accumulés vs budget
- Répartition des coûts par service AWS
- Répartition des coûts par environnement (prod, staging, dev)
- Métriques d'utilisation des services les plus coûteux

### Création de widgets personnalisés

Pour ajouter un widget de suivi des coûts EC2 par région, utilisez la configuration JSON suivante dans CloudWatch:

```json
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/EC2", "EstimatedCharges", "ServiceName", "AmazonEC2", "Region", "eu-west-1" ],
          [ ".", ".", ".", ".", ".", "us-east-1" ],
          [ ".", ".", ".", ".", ".", "ap-northeast-1" ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "us-east-1",
        "period": 86400,
        "stat": "Average",
        "title": "EC2 Costs by Region"
      }
    }
  ]
}
```

### Exportation des données de tableau de bord

Notre tableau de bord exporte automatiquement ses données quotidiennement vers notre data lake pour une analyse plus approfondie. Voici un exemple de la configuration Lambda utilisée :

```java
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;

public class DashboardExporter implements RequestHandler<Object, String> {
    @Override
    public String handleRequest(Object input, Context context) {
        // Exporter les données du tableau de bord vers S3
        exportDashboardDataToS3("AccessWeaver-Cost-Dashboard", "accessweaver-data-lake");
        return "Export completed successfully";
    }
    
    private void exportDashboardDataToS3(String dashboardName, String bucketName) {
        // Code pour extraire les données et les envoyer vers S3
    }
}
```

## Alertes de coûts

Nous avons configuré un système d'alertes en plusieurs couches pour nous avertir de toute anomalie ou dépassement de coûts.

### Alertes de tendance anormale

Ces alertes sont déclenchées lorsque les coûts augmentent de manière inhabituelle :

- Alerte mineure : augmentation de 20% par rapport à la même période la semaine dernière
- Alerte modérée : augmentation de 40% par rapport à la même période la semaine dernière
- Alerte critique : augmentation de 60% par rapport à la même période la semaine dernière

### Exemple de configuration d'alerte CloudWatch

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Resources:
  AnomalyCostAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: AnomalyCostDetection-Critical
      AlarmDescription: "Détecte une augmentation critique des coûts AWS"
      ActionsEnabled: true
      OKActions: []
      AlarmActions:
        - !Ref SNSTopicForAlerts
      MetricName: AnomalyDetectionBillingMetric
      Namespace: "AWS/Billing"
      Statistic: Maximum
      Dimensions:
        - Name: Currency
          Value: EUR
      Period: 86400
      EvaluationPeriods: 1
      Threshold: 60
      ComparisonOperator: GreaterThanThreshold
      TreatMissingData: missing
```

### Acheminement des alertes

Nos alertes sont acheminées vers différents canaux selon leur sévérité :

| Type d'alerte | Destinataires | Canaux de notification |
|--------------|---------------|------------------------|
| Mineure | Équipe DevOps | Slack #cost-alerts |
| Modérée | DevOps + Responsables techniques | Slack + Email |
| Critique | DevOps + Tech Leads + CTO | Slack + Email + SMS |

### Script de vérification des alertes

Ce script exécuté quotidiennement vérifie que nos alertes sont correctement configurées :

```java
public class AlertValidator {
    public static void main(String[] args) {
        // Vérifier que toutes les alertes sont actives
        validateAlertsAreEnabled();
        
        // Vérifier que les canaux de notification sont correctement configurés
        validateNotificationChannels();
        
        // Vérifier que les seuils d'alerte sont conformes aux politiques
        validateAlertThresholds();
    }
    
    // Méthodes d'implémentation...
}
```

## Rapports hebdomadaires

Nous produisons des rapports hebdomadaires détaillés qui sont distribués aux parties prenantes pour maintenir la transparence sur nos coûts AWS.

### Contenu des rapports

Chaque rapport hebdomadaire contient :

1. Résumé des coûts totaux de la semaine
2. Comparaison avec la semaine précédente et le budget
3. Top 5 des services les plus coûteux
4. Tendances et anomalies détectées
5. Opportunités d'optimisation identifiées
6. Actions en cours pour réduire les coûts

### Génération automatique des rapports

Les rapports sont générés automatiquement chaque lundi matin via un job Jenkins :

```groovy
pipeline {
    agent any
    triggers {
        cron('0 6 * * 1') // Tous les lundis à 6h00
    }
    stages {
        stage('Générer rapport') {
            steps {
                sh 'java -jar cost-report-generator.jar --week-offset=1 --format=pdf,html'
            }
        }
        stage('Distribuer rapport') {
            steps {
                sh 'python distribute_report.py --recipients="cost-stakeholders@accessweaver.com"'
            }
        }
    }
}
```

### Exemple de visualisation du rapport

Voici un exemple de graphique inclus dans nos rapports hebdomadaires :

```
Coûts hebdomadaires par service (EUR)

  14000 +---------------------------------------------------------------+
        |          +           +           +           +           +    |
  12000 |                                                      #####    |
        |                                                      #   #    |
  10000 |                                            #####     #   #    |
        |                                            #   #     #   #    |
   8000 |                                  #####     #   #     #   #    |
        |                                  #   #     #   #     #   #    |
   6000 |                        #####     #   #     #   #     #   #    |
        |                        #   #     #   #     #   #     #   #    |
   4000 |              #####     #   #     #   #     #   #     #   #    |
        |              #   #     #   #     #   #     #   #     #   #    |
   2000 |    #####     #   #     #   #     #   #     #   #     #   #    |
        |    #   #     #   #     #   #     #   #     #   #     #   #    |
      0 +---------------------------------------------------------------+
          Sem.1     Sem.2     Sem.3     Sem.4     Sem.5     Sem.6
```

### Distribution des rapports

Les rapports sont distribués via :

- Email aux parties prenantes identifiées
- Publication dans le canal Slack #cloud-cost-management
- Stockage dans notre système documentaire interne
- Présentation lors de la réunion d'alignement technique hebdomadaire

## Intégration avec les outils de gestion de projet

Nous avons intégré notre suivi des coûts avec notre système de gestion de projet pour faciliter l'attribution des coûts aux fonctionnalités et initiatives.

### Intégration avec Jira

Notre système envoie automatiquement les coûts estimés vers les épiques et user stories Jira pertinentes, ce qui nous permet de suivre le coût réel vs estimé pour chaque initiative.

```java
public class JiraCostIntegration {
    public static void updateJiraEpicWithActualCosts(String epicKey, double actualCost) {
        // Code pour mettre à jour l'épique Jira avec les coûts réels
    }
}
```