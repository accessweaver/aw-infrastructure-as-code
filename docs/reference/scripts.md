# 📜 Scripts Utilitaires

## Introduction

Ce document répertorie et décrit les scripts utilitaires utilisés chez AccessWeaver pour faciliter le développement, les tests, le déploiement et la maintenance de notre infrastructure. Ces scripts sont conçus pour automatiser les tâches répétitives, standardiser les procédures et améliorer la productivité.

---

## Scripts de Configuration d'Environnement

### Installation & Setup

| Script | Description | Usage |
|--------|-------------|-------|
| `setup-dev-env.sh` | Configure l'environnement de développement | `./setup-dev-env.sh [--with-docker] [--with-aws]` |
| `install-terraform.sh` | Installe Terraform avec la version spécifiée | `./install-terraform.sh [version]` |
| `configure-aws.sh` | Configure le profil AWS CLI | `./configure-aws.sh [profile-name]` |
| `setup-terratest.sh` | Installe Terratest et dépendances Go | `./setup-terratest.sh` |

### Exemples

```bash
# Installation de l'environnement complet
./setup-dev-env.sh --with-docker --with-aws

# Installation d'une version spécifique de Terraform
./install-terraform.sh 1.5.4

# Configuration d'un profil AWS spécifique
./configure-aws.sh accessweaver-dev
```

---

## Scripts de Tests

### Tests d'Infrastructure

| Script | Description | Usage |
|--------|-------------|-------|
| `run-terratest.sh` | Exécute les tests Terratest | `./run-terratest.sh [directory] [test-name]` |
| `cleanup-test-resources.sh` | Nettoie les ressources de test AWS | `./cleanup-test-resources.sh [--force]` |
| `validate-all-modules.sh` | Valide tous les modules Terraform | `./validate-all-modules.sh` |
| `security-scan.sh` | Exécute les scans de sécurité | `./security-scan.sh [--checkov] [--tfsec]` |

### Tests Applicatifs

| Script | Description | Usage |
|--------|-------------|-------|
| `run-integration-tests.sh` | Exécute les tests d'intégration | `./run-integration-tests.sh [--env=dev]` |
| `run-chaos-tests.sh` | Exécute les tests de chaos | `./run-chaos-tests.sh [--duration=30m]` |
| `performance-test.sh` | Exécute les tests de performance | `./performance-test.sh [--users=100]` |
| `api-test.sh` | Exécute les tests d'API avec Postman | `./api-test.sh [collection]` |

### Code & Exemples

```bash
#!/bin/bash
# run-terratest.sh - Exécute les tests Terratest pour un module spécifique

set -e

DIR=${1:-"./tests"}
TEST_NAME=${2:-""}
TEST_TIMEOUT=${TEST_TIMEOUT:-"30m"}

echo "Exécution des tests dans $DIR avec timeout $TEST_TIMEOUT"

if [ -n "$TEST_NAME" ]; then
  echo "Exécution du test spécifique: $TEST_NAME"
  cd "$DIR" && go test -v -timeout "$TEST_TIMEOUT" -run "$TEST_NAME"
else
  echo "Exécution de tous les tests"
  cd "$DIR" && go test -v -timeout "$TEST_TIMEOUT" ./...
fi

echo "Tests terminés avec succès!"
```

```bash
#!/bin/bash
# security-scan.sh - Exécute les scans de sécurité sur l'infrastructure

RUN_CHECKOV=false
RUN_TFSEC=false
DIRECTORY="./terraform"

for arg in "$@"; do
  case $arg in
    --checkov)
      RUN_CHECKOV=true
      ;;
    --tfsec)
      RUN_TFSEC=true
      ;;
    --dir=*)
      DIRECTORY="${arg#*=}"
      ;;
    *)
      echo "Option inconnue: $arg"
      exit 1
      ;;
  esac
shift
done

if [ "$RUN_CHECKOV" = true ]; then
  echo "Exécution de Checkov sur $DIRECTORY"
  checkov -d "$DIRECTORY" --framework terraform
fi

if [ "$RUN_TFSEC" = true ]; then
  echo "Exécution de tfsec sur $DIRECTORY"
  tfsec "$DIRECTORY" --format=junit
fi

echo "Scan de sécurité terminé"
```

---

## Scripts de Déploiement

### Déploiement et Mise à Jour

| Script | Description | Usage |
|--------|-------------|-------|
| `deploy-env.sh` | Déploie un environnement complet | `./deploy-env.sh [env-name]` |
| `update-module.sh` | Met à jour un module spécifique | `./update-module.sh [module-name]` |
| `rollback.sh` | Effectue un rollback vers une version précédente | `./rollback.sh [version]` |
| `blue-green-switch.sh` | Bascule entre les environnements Blue/Green | `./blue-green-switch.sh` |

### Exemple

```bash
#!/bin/bash
# deploy-env.sh - Déploie un environnement complet

ENV_NAME=${1:-"dev"}
SKIP_TESTS=${SKIP_TESTS:-false}

echo "Déploiement de l'environnement: $ENV_NAME"

# 1. Validation des pré-requis
if ! command -v terraform &> /dev/null; then
  echo "Terraform n'est pas installé. Installation..."
  ./install-terraform.sh
fi

# 2. Exécution des tests si demandé
if [ "$SKIP_TESTS" != "true" ]; then
  echo "Exécution des tests avant déploiement"
  ./run-terratest.sh "./tests/infrastructure"
  ./security-scan.sh --checkov --tfsec
fi

# 3. Déploiement de l'infrastructure
cd "./terraform/environments/$ENV_NAME"
terraform init
terraform plan -out=tfplan
terraform apply -auto-approve tfplan

# 4. Vérification post-déploiement
echo "Vérification du déploiement"
./verify-deployment.sh "$ENV_NAME"

echo "Déploiement terminé avec succès!"
```

---

## Scripts de Maintenance

### Surveillance et Maintenance

| Script | Description | Usage |
|--------|-------------|-------|
| `monitor-resources.sh` | Surveille les ressources AWS | `./monitor-resources.sh [--interval=5m]` |
| `rotate-keys.sh` | Effectue la rotation des clés | `./rotate-keys.sh [--force]` |
| `backup-state.sh` | Sauvegarde l'état Terraform | `./backup-state.sh` |
| `prune-logs.sh` | Nettoie les anciens logs | `./prune-logs.sh [--days=30]` |

### Analyse et Rapports

| Script | Description | Usage |
|--------|-------------|-------|
| `generate-test-report.sh` | Génère des rapports de tests | `./generate-test-report.sh [--format=html]` |
| `cost-analysis.sh` | Analyse les coûts AWS | `./cost-analysis.sh [--month=current]` |
| `security-report.sh` | Génère un rapport de sécurité | `./security-report.sh` |
| `coverage-report.sh` | Génère un rapport de couverture de code | `./coverage-report.sh` |

### Exemple

```bash
#!/bin/bash
# generate-test-report.sh - Génère des rapports de tests

FORMAT=${1:-"html"}
OUTPUT_DIR=${OUTPUT_DIR:-"./reports"}

# Vérifier si le répertoire de sortie existe
if [ ! -d "$OUTPUT_DIR" ]; then
  mkdir -p "$OUTPUT_DIR"
fi

# Générer le rapport pour les tests unitaires
echo "Génération du rapport pour les tests unitaires"
java -jar test-reporter.jar \
  --input "./target/surefire-reports" \
  --output "$OUTPUT_DIR/unit-tests.$FORMAT" \
  --format "$FORMAT"

# Générer le rapport pour les tests d'intégration
echo "Génération du rapport pour les tests d'intégration"
java -jar test-reporter.jar \
  --input "./target/failsafe-reports" \
  --output "$OUTPUT_DIR/integration-tests.$FORMAT" \
  --format "$FORMAT"

# Générer le rapport pour les tests d'infrastructure
echo "Génération du rapport pour les tests d'infrastructure"
go tool cover -html=coverage.out -o "$OUTPUT_DIR/infra-tests.$FORMAT"

echo "Rapports générés avec succès dans $OUTPUT_DIR"
```

---

## Bonnes Pratiques pour les Scripts

### Générales

- **Documentation** - Ajouter un commentaire en-tête expliquant le but du script
- **Gestion des erreurs** - Utiliser `set -e` pour arrêter sur erreur, `trap` pour les nettoyages
- **Paramètres par défaut** - Fournir des valeurs par défaut raisonnables pour les paramètres
- **Messages informatifs** - Inclure des messages clairs sur l'avancement du script

### Sécurité

- **Ne pas stocker de credentials** - Utiliser AWS IAM roles ou environnement
- **Validation des entrées** - Valider les entrées utilisateur pour éviter les injections
- **Permissions restrictives** - Limiter les permissions des fichiers scripts (`chmod 750`)
- **Audit** - Journaliser les actions importantes pour audit

---

## Ressources et Outils Complémentaires

### Documentation Interne

- [Stratégie de Test](../reference/testing-strategy.md)
- [Outillage d'Automation](../reference/automation.md)
- [Commandes CLI](../reference/cli.md)

### Ressources Externes

- [Bash Scripting Guide](https://tldp.org/LDP/abs/html/)
- [ShellCheck](https://www.shellcheck.net/) - Outil d'analyse statique pour scripts shell
- [Terraform CLI](https://developer.hashicorp.com/terraform/cli)
- [AWS CLI](https://aws.amazon.com/cli/)