# 🔧 Outils de Debugging

## Introduction

Ce document présente les outils et techniques de debugging utilisés chez AccessWeaver pour résoudre les problèmes d'infrastructure, d'applications et de tests. Un debugging efficace est essentiel pour maintenir la fiabilité et la performance de notre plateforme.

---

## Outils de Debugging Infrastructure

### AWS CloudWatch

| Fonctionnalité | Usage | Avantages |
|----------------|-------|----------|
| **CloudWatch Logs** | Analyse des logs d'infrastructure | Centralisation, recherche, filtrage |
| **CloudWatch Metrics** | Suivi des métriques de performance | Visualisation, alerting, historique |
| **CloudWatch Insights** | Analyse avancée des logs | Requêtes personnalisées, corrélation |
| **CloudWatch Dashboards** | Tableaux de bord personnalisés | Vue unifiéé des métriques clés |

### Terraform

| Commande | Usage | Exemple |
|----------|-------|--------|
| **terraform plan -detailed-exitcode** | Détection précise des changements | `terraform plan -detailed-exitcode -out=plan.out` |
| **terraform console** | Évaluation d'expressions | `terraform console` puis `aws_vpc.main.id` |
| **terraform graph** | Visualisation des dépendances | `terraform graph | dot -Tpng > graph.png` |
| **terraform state list** | Liste des ressources gérées | `terraform state list` |
| **terraform state show** | Détails d'une ressource | `terraform state show aws_vpc.main` |

---

## Outils de Debugging Tests

### Tests d'Infrastructure

| Outil | Usage | Technique |
|-------|-------|----------|
| **Terratest Log** | Logs détaillés des tests | `t.Logf("Debug info: %s", output)` |
| **TF_LOG=DEBUG** | Logs détaillés Terraform | `TF_LOG=DEBUG terraform apply` |
| **AWS CLI debug** | Débogage AWS CLI | `aws --debug ec2 describe-instances` |
| **LocalStack Logs** | Débogage émulation AWS | `docker logs localstack -f` |

### Tests Automatisés Java 21

| Outil | Usage | Technique |
|-------|-------|----------|
| **JUnit Debug Mode** | Exécution pas à pas des tests | Débugger avec breakpoints |
| **Remote Debugging** | Débogage à distance | `-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=5005` |
| **@DisplayName** | Documentation des tests | `@DisplayName("Should validate VPC CIDR")` |
| **Logging avancé** | Traçage des tests | `log.debug("Test state: {}", currentState);` |

### Tests d'Intégration

| Outil | Usage | Technique |
|-------|-------|----------|
| **Wiremock Logging** | Traçage des requêtes mock | `WireMock.configureLogging(WireMockConfiguration.options().verbose(true))` |
| **AWS X-Ray** | Traçage des transactions | Analyse du traçage distribué |
| **SpringBoot Test Logs** | Logs détaillés des tests Spring | `logging.level.org.springframework.test=DEBUG` |
| **Docker Logs** | Logs des conteneurs de test | `docker logs testcontainer_id` |

---

## Techniques de Debugging

### Débogage des Tests Échoués

1. **Identifier le contexte d'échec**
   ```bash
   # Récupérer les logs détaillés
   make test-debug TEST_NAME="TestVpcModule"
   ```

2. **Reproduire en local**
   ```bash
   # Exécuter un test spécifique avec verbosité maximale
   cd tests/infrastructure
   go test -v -run TestVpcModule
   ```

3. **Inspecter l'état Terraform**
   ```bash
   # Pour les tests d'infrastructure, examiner l'état
   cd .terratest-working-dir-*
   terraform state list
   terraform state show aws_vpc.main
   ```

4. **Analyser les ressources AWS**
   ```bash
   # Vérifier les ressources créées
   aws ec2 describe-vpcs --filters "Name=tag:Name,Values=terratest-*"
   ```

### Débogage des Performances

1. **Profiling des Tests**
   ```bash
   # Profiler un test Java 21
   java -XX:+FlightRecorder -XX:StartFlightRecording=duration=60s,filename=test-recording.jfr -jar app.jar
   ```

2. **Analyse des Goulots d'étranglement**
   ```bash
   # Mesurer le temps d'exécution des étapes
   time terraform apply -auto-approve
   ```

3. **Monitoring en temps réel**
   ```bash
   # Surveiller les métriques pendant les tests
   watch "aws cloudwatch get-metric-statistics --metric-name CPUUtilization --namespace AWS/RDS --dimensions Name=DBInstanceIdentifier,Value=test-db --start-time $(date -u -v-5M +%Y-%m-%dT%H:%M:%SZ) --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) --period 60 --statistics Average"
   ```

---

## Debugging dans le CI/CD

### Jenkins

| Technique | Description | Utilisation |
|-----------|-------------|-------------|
| **Archive des Artefacts** | Conserver logs et résultats | `archiveArtifacts artifacts: 'test-results/**'` |
| **Console Debug** | Active le mode debug | Paramètre `debugMode=true` |
| **Replay Pipeline** | Modification temporaire du pipeline | Option "Replay" dans l'interface |
| **Blue Ocean** | Visualisation avancée | Interface visuelle des étapes |

### GitHub Actions

```yaml
# Débogage des workflows GitHub Actions
name: Debug Tests

on: workflow_dispatch

jobs:
  debug:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Enable Step Debug Logging
        run: echo "ACTIONS_STEP_DEBUG=true" >> $GITHUB_ENV
      
      - name: Setup tmate session
        uses: mxschmitt/action-tmate@v3
        with:
          limit-access-to-actor: true
        
      - name: Run Tests with Debug
        run: |
          export TF_LOG=DEBUG
          make test-infrastructure
```

---

## Debugging Post-Mortem

### Collecte des Données

- **Logs Système** - CloudWatch Logs, journald, syslog
- **Métriques** - CloudWatch Metrics, Prometheus
- **Captures d'état** - Terraform state, AWS Config
- **Historique** - AWS CloudTrail, Git history

### Analyse de Cause Racine

1. **Timeline des événements**
   ```bash
   # Extraire chronologie depuis CloudTrail
   aws cloudtrail lookup-events --start-time "2025-06-01T00:00:00Z" --end-time "2025-06-02T00:00:00Z" --region eu-west-1 > events.json
   ```

2. **5 Pourquoi**
   - Problème: Le test de VPC a échoué
   - Pourquoi? Terraform n'a pas pu créer le VPC
   - Pourquoi? Le CIDR était déjà utilisé
   - Pourquoi? Un autre test utilise le même CIDR
   - Pourquoi? Les tests ne génèrent pas de CIDR uniques
   - Pourquoi? La fonction de génération aléatoire a un bug

3. **Template de rapport**
   ```md
   ## Rapport d'incident
   
   ### Description
   Test d'infrastructure échoué: TestVpcModule
   
   ### Impact
   Pipeline bloqué pendant 45 minutes
   
   ### Cause racine
   Conflit de CIDR dans les tests en parallèle
   
   ### Solution
   Implémentation de CIDRs aléatoires dans les tests
   
   ### Actions préventives
   - Ajouter des validations pré-test
   - Améliorer l'isolation des tests
   ```

---

## Ressources et Outils Complémentaires

### Documentation

- [Guide de Débogage Terraform](https://developer.hashicorp.com/terraform/internals/debugging)
- [AWS CloudWatch User Guide](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/)
- [Java Flight Recorder](https://docs.oracle.com/javacomponents/jmc-5-5/jfr-runtime-guide/about.htm)

### Outils Recommandés

- [IntelliJ IDEA](https://www.jetbrains.com/idea/) - Débogage Java 21 avancé
- [AWS CloudWatch Logs Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html) - Analyse avancée de logs
- [Terraformer](https://github.com/GoogleCloudPlatform/terraformer) - Retroingénierie d'infrastructure
- [AWS X-Ray](https://aws.amazon.com/xray/) - Traçage distribué