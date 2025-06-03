# 🔐 Conformité GDPR/RGPD

Ce document décrit les mesures techniques et organisationnelles mises en place pour assurer la conformité de l'infrastructure AccessWeaver au Règlement Général sur la Protection des Données (RGPD/GDPR).

---

## 📋 Aperçu de la Conformité GDPR

En tant que plateforme d'autorisation, AccessWeaver traite des données à caractère personnel, notamment des informations d'identité et d'accès. Notre infrastructure AWS est configurée pour répondre aux exigences strictes du GDPR, garantissant la protection des données des utilisateurs tout au long de leur cycle de vie.

### Principes Clés GDPR Couverts

- **Licéité, loyauté et transparence** - Traitement légitime des données
- **Limitation des finalités** - Collecte pour des objectifs spécifiques
- **Minimisation des données** - Uniquement les données nécessaires
- **Exactitude** - Données à jour et précises
- **Limitation de conservation** - Durée de stockage limitée
- **Intégrité et confidentialité** - Sécurité appropriée
- **Responsabilité** - Démonstration de conformité

---

## 🧲 Types de Données Traitées

| Catégorie | Exemples | Classification | Durée de Conservation |
|------------|----------|----------------|-----------------------|
| **Données d'identité** | Identifiants utilisateurs, adresses email | Personnelles | Durée du contrat + 30 jours |
| **Données d'accès** | Logs de connexion, autorisations | Personnelles | 90 jours |
| **Données techniques** | Adresses IP, User-Agents | Personnelles | 30 jours |
| **Données d'audit** | Actions utilisateurs, décisions d'autorisation | Personnelles | 12 mois |

---

## 🛡️ Mesures Techniques de Protection

### 1. Chiffrement des Données

- **Au repos**: Toutes les données personnelles sont chiffrées dans les bases de données PostgreSQL et les systèmes de stockage S3 via AWS KMS
- **En transit**: Communications sécurisées via TLS 1.3+ pour tous les échanges de données
- **Gestion des clés**: Rotation automatique des clés KMS et politique de moindre privilège

### 2. Contrôle d'Accès

- **IAM**: Accès aux données strictement limité selon le principe du moindre privilège
- **MFA**: Authentification multi-facteurs obligatoire pour tous les accès administratifs
- **Audit d'accès**: Journalisation complète de tous les accès aux données personnelles

### 3. Séparation des Environnements

- **Isolation**: Séparation stricte des environnements de développement, test et production
- **Anonymisation**: Données de test anonymisées pour le développement et les tests
- **Contrôles d'accès**: Restrictions d'accès différenciées par environnement

---

## 📝 Processus de Gestion des Données

### 1. Cycle de Vie des Données

```
Collecte → Traitement → Stockage → Suppression/Anonymisation
```

- **Collecte**: Uniquement les données nécessaires au service
- **Traitement**: Conformément aux finalités déclarées
- **Stockage**: Dans les régions AWS conformes au GDPR (EU)
- **Suppression**: Automatique à l'expiration du délai de conservation

### 2. Mise en Œuvre des Droits des Personnes

| Droit | Implémentation Technique |
|-------|----------------------------|
| **Accès** | API dédiée pour extraction des données personnelles |
| **Rectification** | Interfaces de correction des données inexactes |
| **Effacement** | Procédure automatisée de suppression complète |
| **Portabilité** | Export au format JSON/CSV des données utilisateur |
| **Opposition** | Mécanisme de retrait du consentement avec logging |

### 3. Gestion des Violations de Données

- **Détection**: Surveillance continue via AWS GuardDuty et CloudWatch
- **Notification**: Procédure de notification dans les 72 heures
- **Documentation**: Registre des violations maintenu dans AWS S3 sécurisé
- **Remédiation**: Procédures d'intervention et de correction définies

---

## 📑 Documentation et Registres

### 1. Registre des Activités de Traitement

- Maintenu dans un format structuré et accessible
- Inclut toutes les opérations de traitement, finalités et bases légales
- Mis à jour à chaque modification du traitement

### 2. Analyses d'Impact (DPIA)

- Réalisées pour tous les traitements à risque élevé
- Documentées et conservées dans le système de gestion documentaire
- Révisées annuellement ou lors de changements majeurs

---

## 🧸 Sous-Traitants et Transferts

### 1. Sous-Traitants AWS

- **AWS**: Principal sous-traitant pour l'hébergement
- **Conformité**: AWS est certifié conforme au GDPR
- **DPA**: Data Processing Addendum signé avec AWS

### 2. Transferts de Données

- **Localisation**: Données stockées exclusivement dans les régions AWS EU (Paris, Francfort)
- **Transferts**: Aucun transfert hors UE par défaut
- **Exceptions**: Si nécessaires, uniquement avec garanties appropriées (CCT, BCR)

---

## 📊 Monitoring et Audit

### 1. Logging et Monitoring GDPR

- **CloudWatch**: Métriques spécifiques pour la conformité GDPR
- **CloudTrail**: Audit complet des actions sur les données personnelles
- **AWS Config**: Vérification continue de la conformité des ressources

```bash
# Exemple de règle AWS Config pour vérifier le chiffrement RDS
aws configservice put-config-rule --config-rule '{"ConfigRuleName":"rds-storage-encrypted","Description":"GDPR Compliance - Checks if RDS instances are encrypted","Source":{"Owner":"AWS","SourceIdentifier":"RDS_STORAGE_ENCRYPTED"},"Scope":{"ComplianceResourceTypes":["AWS::RDS::DBInstance"]}}'
```

### 2. Revues de Conformité

- **Fréquence**: Audits trimestriels de conformité GDPR
- **Documentation**: Rapports d'audit conservés 3 ans
- **Actions correctives**: Suivi des non-conformités dans Jira

---

## 💼 Rôles et Responsabilités

### 1. Organisation Interne

| Rôle | Responsabilités |
|-------|------------------|
| **DPO** | Supervision de la conformité GDPR, point de contact |
| **Équipe Sécurité** | Mise en œuvre des mesures techniques |
| **DevOps** | Configuration conforme de l'infrastructure |
| **Développeurs** | Privacy by Design dans le code |

### 2. Formation et Sensibilisation

- Formation obligatoire sur le GDPR pour tous les employés
- Sessions spécialisées pour les équipes techniques
- Tests de connaissance annuels

---

## 📃 Configuration AWS Spécifique

Voici les principaux éléments de configuration AWS pour assurer la conformité GDPR:

### 1. Stockage et Rétention

```hcl
# Exemple de configuration Terraform pour la rétention des données
resource "aws_s3_bucket_lifecycle_configuration" "gdpr_compliant" {
  bucket = aws_s3_bucket.personal_data.id

  rule {
    id = "gdpr-expiration"
    status = "Enabled"
    
    expiration {
      days = 90  # Rétention conforme au GDPR
    }
  }
}
```

### 2. Chiffrement et Sécurité

```hcl
# Configuration RDS conforme GDPR
resource "aws_db_instance" "postgres" {
  # ...
  storage_encrypted  = true
  kms_key_id         = aws_kms_key.gdpr_key.arn
  deletion_protection = true
  backup_retention_period = 35  # Conservation des backups
}
```

### 3. Monitoring GDPR

```hcl
# Alerte sur accès aux données sensibles
resource "aws_cloudwatch_metric_alarm" "sensitive_data_access" {
  alarm_name          = "gdpr-sensitive-data-access"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "SensitiveDataAccess"
  namespace           = "AccessWeaver/GDPR"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Cette alarme surveille les accès fréquents aux données sensibles"
  alarm_actions       = [aws_sns_topic.gdpr_alerts.arn]
}
```

---

## 📕 Liste de Contrôle GDPR

Utilisez cette liste pour vérifier régulièrement la conformité de l'infrastructure:

- [ ] Chiffrement activé pour toutes les bases de données
- [ ] Politiques de rétention des données configurées
- [ ] Logs d'audit activés sur tous les services
- [ ] Droits des personnes concernées implémentés
- [ ] Mécanismes de suppression des données testés
- [ ] Alertes de sécurité configurées
- [ ] Régions AWS conformes utilisées uniquement
- [ ] DPA signés avec tous les sous-traitants
- [ ] DPIA réalisées et documentées
- [ ] Formation GDPR à jour pour l'équipe

---

## 📓 Ressources Utiles

- **[Documentation AWS sur la conformité GDPR](https://aws.amazon.com/compliance/gdpr-center/)**
- **[Guide CNIL sur la sécurité des données personnelles](https://www.cnil.fr/fr/principes-cles/guide-de-la-securite-des-donnees-personnelles)**
- **[Checklist GDPR pour les infrastructures cloud](../reference/gdpr-checklist.md)**
- **[Procédures internes pour les demandes d'accès](../operations/gdpr-requests.md)**

---

*Dernière mise à jour: 2025-06-03*

*Statut du document: ✅ Complet*