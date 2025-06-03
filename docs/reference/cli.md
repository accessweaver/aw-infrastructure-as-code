# 💻 Commandes CLI

## Introduction

Ce document répertorie les commandes CLI (Command Line Interface) utilisées chez AccessWeaver pour interagir avec notre infrastructure, outils de développement et plateformes de test. Ces commandes sont essentielles pour les développeurs, testeurs et opérateurs d'infrastructure.

---

## AWS CLI

### Configuration

```bash
# Configuration du profil par défaut
aws configure

# Configuration d'un profil spécifique
aws configure --profile accessweaver-dev

# Vérification de l'identité connectée
aws sts get-caller-identity
```

### EC2 & Networking

```bash
# Liste des instances EC2
aws ec2 describe-instances

# Liste des VPCs
aws ec2 describe-vpcs

# Liste des sous-réseaux
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-1234abcd"

# Liste des groupes de sécurité
aws ec2 describe-security-groups
```

### S3 & Stockage

```bash
# Liste des buckets
aws s3 ls

# Copie d'un fichier vers S3
aws s3 cp fichier.txt s3://mon-bucket/

# Synchronisation d'un répertoire avec S3
aws s3 sync ./mon-repertoire s3://mon-bucket/dossier/

# Liste des objets dans un bucket
aws s3 ls s3://mon-bucket --recursive
```

### CloudWatch & Monitoring

```bash
# Liste des groupes de logs CloudWatch
aws logs describe-log-groups

# Récupération des événements de logs
aws logs get-log-events --log-group-name /aws/lambda/ma-fonction --log-stream-name 2023/06/01

# Liste des alarmes
aws cloudwatch describe-alarms

# Récupération des métriques
aws cloudwatch get-metric-statistics --namespace AWS/Lambda --metric-name Duration --dimensions Name=FunctionName,Value=ma-fonction --start-time 2023-06-01T00:00:00Z --end-time 2023-06-02T00:00:00Z --period 3600 --statistics Average
```

---

## Terraform CLI

### Commandes de Base

```bash
# Initialisation
terraform init

# Planification des changements
terraform plan

# Application des changements
terraform apply

# Destruction des ressources
terraform destroy
```

### Gestion d'État

```bash
# Liste des ressources dans l'état
terraform state list

# Affichage des détails d'une ressource
terraform state show aws_vpc.main

# Suppression d'une ressource de l'état
terraform state rm aws_instance.old

# Import d'une ressource existante
terraform import aws_s3_bucket.example bucket-name
```

### Workspace & Environnements

```bash
# Liste des workspaces
terraform workspace list

# Création d'un nouveau workspace
terraform workspace new dev

# Sélection d'un workspace
terraform workspace select prod

# Suppression d'un workspace
terraform workspace delete old-workspace
```

---

## Docker & Conteneurs

### Gestion des Conteneurs

```bash
# Liste des conteneurs
docker ps -a

# Exécution d'un conteneur
docker run -d -p 8080:80 --name web nginx

# Arrêt d'un conteneur
docker stop web

# Suppression d'un conteneur
docker rm web
```

### Images & Build

```bash
# Liste des images
docker images

# Construction d'une image
docker build -t mon-app:1.0 .

# Push d'une image vers un registry
docker push mon-registry/mon-app:1.0

# Pull d'une image
docker pull postgres:14
```

### Docker Compose

```bash
# Démarrage des services
docker-compose up -d

# Arrêt des services
docker-compose down

# Visualisation des logs
docker-compose logs -f

# Exécution d'une commande dans un service
docker-compose exec db psql -U postgres
```

---

## Commandes de Test

### Tests d'Infrastructure

```bash
# Exécution des tests Terratest
cd tests && go test -v ./...

# Exécution d'un test spécifique avec timeout
go test -v -timeout 30m -run TestVpcModule

# Exécution des tests avec journalisation détaillée
TF_LOG=DEBUG go test -v ./...

# Scan de sécurité avec Checkov
checkov -d . --framework terraform

# Scan de sécurité avec tfsec
tfsec .
```

### Tests Java 21 & Spring Boot

```bash
# Exécution des tests Maven
mvn test

# Exécution des tests d'intégration uniquement
mvn verify -DskipUnitTests

# Exécution des tests avec un profil spécifique
mvn test -Pintegration

# Tests avec couverture de code
mvn clean test jacoco:report

# Exécution d'un test spécifique
mvn test -Dtest=UserServiceTest
```

### Tests API & Performance

```bash
# Tests API avec Postman/Newman
newman run collection.json -e environment.json

# Tests de charge avec Apache JMeter
jmeter -n -t test-plan.jmx -l results.jtl

# Tests de performance avec k6
k6 run script.js

# Tests d'API avec curl
curl -X GET https://api.example.com/users -H "Authorization: Bearer token"
```

### Tests AWS Spécifiques

```bash
# Exécution d'une expérience de chaos avec AWS FIS
aws fis start-experiment --experiment-template-id exp-1234abcd

# Vérification de l'état d'une expérience
aws fis get-experiment --id experiment-1234abcd

# Tests de configuration AWS
aws configservice start-config-rules-evaluation --config-rule-names ["required-tags"]

# Validation de la conformité
aws configservice describe-compliance-by-config-rule --config-rule-names ["required-tags"]
```

---

## Git & Version Control

### Commandes de Base

```bash
# Clonage d'un repository
git clone https://github.com/accessweaver/aw-infrastructure-as-code.git

# Création d'une branche
git checkout -b feature/new-test-framework

# Commit des changements
git commit -m "Add new test framework for infrastructure"

# Push des changements
git push origin feature/new-test-framework
```

### Collaboration & Review

```bash
# Récupération des dernières modifications
git pull

# Rebase sur main
git rebase main

# Merge d'une branche
git merge feature/completed-tests

# Création d'un tag
git tag -a v1.0.0 -m "Version 1.0.0"
```

---

## Utilitaires de Développement & Test

### Outils de Diagnostic

```bash
# Vérification de la connectivité réseau
ping hostname
telnet hostname port
dig domain
nslookup hostname

# Analyse des processus
ps aux | grep process-name
netstat -tulpn
lsof -i :port

# Surveillance système
top
htop
dstat
```

### Outils de Build

```bash
# Maven
mvn clean install
mvn dependency:tree

# Gradle
gradle build
gradle dependencies

# NPM
npm install
npm run test
npm run build
```

---

## Commandes CI/CD

### Jenkins

```bash
# Déclenchement d'un job Jenkins via CLI
java -jar jenkins-cli.jar -s http://jenkins.accessweaver.com -auth username:password build job-name

# Récupération des logs d'un build
java -jar jenkins-cli.jar -s http://jenkins.accessweaver.com -auth username:password console job-name 123

# Vérification du statut d'un job
curl -s -X GET http://jenkins.accessweaver.com/job/job-name/api/json?tree=lastBuild[number,result]
```

### GitHub Actions

```bash
# Utilisation de GitHub CLI pour les workflows
gh workflow list
gh workflow run workflow-name.yml
gh run list --workflow=workflow-name.yml

# Visualisation des logs d'un run
gh run view 1234567890
gh run view 1234567890 --log
```

---

## Commandes Spécifiques AccessWeaver

### CLI Interne

```bash
# Déploiement d'un environnement
aw-cli deploy --env dev

# Exécution des tests d'infrastructure
aw-cli test infra --module vpc

# Génération d'un rapport de test
aw-cli report --type test --format html

# Création d'un nouveau module
aw-cli scaffold --type module --name networking
```

### Raccourcis de Productivité

```bash
# Exécution de la suite de tests complète
testall

# Nettoyage des ressources de test
cleantest

# Vérification rapide de l'infrastructure
infracheck

# Déploiement rapide
quickdeploy dev
```

---

## Ressources et Outils Complémentaires

### Documentation Interne

- [Stratégie de Test](../reference/testing-strategy.md)
- [Outillage d'Automation](../reference/automation.md)
- [Scripts Utilitaires](../reference/scripts.md)

### Ressources Externes

- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/latest/reference/)
- [Terraform CLI Documentation](https://developer.hashicorp.com/terraform/cli/commands)
- [Docker CLI Documentation](https://docs.docker.com/engine/reference/commandline/cli/)