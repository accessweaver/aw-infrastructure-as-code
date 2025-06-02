# 🛡️ Module WAF - AccessWeaver Infrastructure

**Version :** 1.0  
**Date :** Juin 2025  
**Module :** modules/waf  
**Responsable :** Équipe Platform AccessWeaver

---

## 🎯 Vue d'Ensemble

### Objectif Principal
Le module WAF (Web Application Firewall) fournit une **protection avancée contre les menaces web** pour toutes les applications AccessWeaver. Il implémente des règles de sécurité conformes aux standards OWASP Top 10 et offre une protection évolutive contre les attaques courantes comme les injections SQL, le cross-site scripting (XSS) et les attaques par déni de service (DDoS).

### Positionnement dans l'écosystème
```
┌────────────────────────────────────────────────────────────────┐
│                     Internet                                   │
│                        │                                       │
│                        │                                       │
│                        ▼                                       │
│               ┌─────────────────────────┐                      │
│               │     AWS WAF + Shield     │  ← CE MODULE        │
│               └─────────────────────────┘                      │
│                        │                                       │
│                        ▼                                       │
│               ┌─────────────────────────┐                      │
│               │      CloudFront         │                      │
│               └─────────────────────────┘                      │
│                        │                                       │
│                        ▼                                       │
│               ┌────────────────────────────┐                   │
│               │ Application Load Balancer  │                   │
│               └────────────────────────────┘                   │
│                        │                                       │
│                        ▼                                       │
│ ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐ │
│ │ ECS Services     │ │ ECS Services     │ │ ECS Services     │ │
│ └──────────────────┘ └──────────────────┘ └──────────────────┘ │
└────────────────────────────────────────────────────────────────┘
```

### Caractéristiques Principales
- **Protection OWASP Top 10** : Défense contre les vulnérabilités web les plus critiques
- **Détection d'attaques par modèles** : Règles basées sur des signatures et des modèles comportementaux
- **Protection DDoS** : Intégration avec AWS Shield pour la protection contre les attaques volumiques
- **Rate limiting** : Limitation du nombre de requêtes par IP pour prévenir les abus
- **Géoblocage** : Restriction d'accès basée sur l'origine géographique
- **Log et monitoring** : Traçabilité des attaques et intégration avec CloudWatch

---

## 🏗 Architecture par Environnement

### Stratégie Multi-Environnement

| Aspect | Development | Staging | Production |
|--------|-------------|---------|------------|
| **🔒 Niveau Protection** | Basique | Standard | Avancé |
| **🔍 Mode Inspection** | Count | Count+Block | Block |
| **🚫 Rate Limit** | 1000/min | 500/min | 200/min |
| **⏱️ Sampling** | 50% | 75% | 100% |
| **📊 Logging** | Minimal | Standard | Complet |
| **🌍 Géo-restrictions** | Aucune | Pays à risque | Liste blanche |

### Architecture WAF Development
```
┌─────────────────────────────────────────────────────────┐
│            AWS WAF - Environnement Development          │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Web ACL                                        │    │
│  │  - accessweaver-dev-webacl                      │    │
│  │  - Mode: Count (surveillance sans blocage)      │    │
│  │  - Log: 50% des requêtes                        │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Règles AWS Managed                             │    │
│  │  - Core rule set (détection simple)             │    │
│  │  - Known bad inputs                             │    │
│  │  - Mode: Count uniquement                       │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Règles personnalisées                          │    │
│  │  - Rate limiting: 1000 requêtes/min par IP      │    │
│  │  - Protection API minimale                      │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Architecture WAF Production
```
┌─────────────────────────────────────────────────────────┐
│            AWS WAF - Environnement Production           │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Web ACL                                        │    │
│  │  - accessweaver-prod-webacl                     │    │
│  │  - Mode: Block (protection active)              │    │
│  │  - Log: 100% des requêtes                       │    │
│  │  - Shield Advanced: Activé                      │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Règles AWS Managed                             │    │
│  │  - Core rule set (OWASP Top 10)                 │    │
│  │  - Known bad inputs                             │    │
│  │  - Bot Control                                  │    │
│  │  - IP Reputation database                       │    │
│  │  - Mode: Block                                  │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Règles personnalisées                          │    │
│  │  - Rate limiting: 200 requêtes/min par IP       │    │
│  │  - Geo-blocking: Liste blanche de pays          │    │
│  │  - Protection API avancée                       │    │
│  │  - Inspection payload complète                  │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 🔐 Configuration et Règles

### Groupes de Règles AWS Managed

Le module WAF utilise les groupes de règles gérés par AWS pour fournir une protection complète :

| Groupe de Règles | Description | Environnements |
|-------------------|-------------|----------------|
| **Core Rule Set** | Ensemble de règles de base pour les vulnérabilités OWASP Top 10 | Tous |
| **Known Bad Inputs** | Détection des modèles d'entrée connus comme malveillants | Tous |
| **Bot Control** | Identification et gestion des robots et scrapers | Staging, Production |
| **IP Reputation** | Blocage des IPs connues comme malveillantes | Staging, Production |
| **Anonymous IP** | Détection des accès via VPN, proxy anonymes, Tor | Production |
| **Admin Protection** | Protection renforcée des chemins administratifs | Production |

### Règles Personnalisées

Le module définit également des règles personnalisées adaptées aux besoins spécifiques d'AccessWeaver :

1. **Rate Limiting** : Restriction du nombre de requêtes par IP
2. **Géo-restrictions** : Filtrage géographique adapté à l'environnement
3. **Protection API** : Règles spécifiques pour les endpoints API critiques
4. **Validation des Tokens** : Vérification des JWT et tokens de session
5. **Inspection du Payload** : Analyse approfondie des requêtes POST et JSON

### Exemple de configuration Terraform

```hcl
module "waf" {
  source = "./modules/waf"
  
  environment = "production"
  
  # Points d'attache du WAF
  alb_arn     = module.alb.alb_arn
  cloudfront_distributions = [module.cloudfront.distribution_id]
  
  # Configuration par environnement
  protection_level = "advanced"  # basic, standard, advanced
  
  # Règles personnalisées
  rate_limit = 200
  enable_geo_blocking = true
  allowed_countries = ["FR", "DE", "ES", "IT", "BE", "CH", "LU"]
  
  # Logging et monitoring
  enable_logging = true
  log_destination_arn = aws_s3_bucket.waf_logs.arn
  log_sampling_rate = 100  # pourcentage
  
  # Intégration Shield Advanced
  enable_shield_advanced = true
  
  # Notification des attaques
  notification_topic_arn = aws_sns_topic.security_alerts.arn
}
```

### Intégration avec AWS Shield

Pour une protection DDoS complète, le module WAF s'intègre avec AWS Shield :

- **Shield Standard** : Activé par défaut sur tous les environnements
- **Shield Advanced** : Activé uniquement en production

Cette intégration fournit une protection contre :
- Attaques DDoS volumiques (couche 3/4)
- Attaques DDoS applicatives (couche 7)
- Support d'intervention rapide 24/7 (Shield Advanced)

---

## 📈 Monitoring et Logging

### Architecture de Logging

Le module WAF met en place une architecture complète de collecte et d'analyse des logs :

```
┌──────────────────────────────────────────────────────────┐
│                     AWS WAF                              │
│                        │                                 │
│                        ▼                                 │
│               ┌────────────────────────────┐             │
│               │  Amazon Kinesis Firehose   │             │
│               └────────────────────────────┘             │
│                     /        \                           │
│                    /          \                          │
│                   ▼           ▼                          │
│       ┌─────────────┐    ┌─────────────────┐             │
│       │   S3 Bucket │    │ CloudWatch Logs │             │
│       └─────────────┘    └─────────────────┘             │
│             │                │                           │
│             ▼                ▼                           │
│   ┌──────────────────┐    ┌────────────────────┐         │
│   │ Athena Queries   │    │  Dashboards        │         │
│   └──────────────────┘    └────────────────────┘         │
│             │                │                           │
│             ┴                ┴                           │
│                    ▲           ▲                         │
│                    │           │                         │
│               ┌────────────────────────────┐             │
│               │     Sécurité & DevOps      │             │
│               └────────────────────────────┘             │
└──────────────────────────────────────────────────────────┘
```

### Métriques WAF essentielles

Le module configure des métriques CloudWatch pour surveiller l'efficacité du WAF :

| Métrique | Description | Seuil d'Alerte |
|-----------|-------------|----------------|
| **AllowedRequests** | Requêtes autorisées par le WAF | - |
| **BlockedRequests** | Requêtes bloquées par le WAF | ↑ >5% du trafic total |
| **CountedRequests** | Requêtes qui auraient été bloquées en mode Block | ↑ >10% du trafic total |
| **PassedRequests** | Requêtes évaluées sans correspondance | - |
| **CaptchaRequests** | Requêtes ayant déclenché un CAPTCHA | ↑ >2% du trafic total |
| **RequestsWithValidToken** | Requêtes avec un token valide | ↓ <90% des requêtes |

### Alertes et Notifications

Le module configure les alertes suivantes dans CloudWatch :

1. **Alerte de pic d'attaque** : Déclenchée lorsque le nombre de requêtes bloquées dépasse un seuil prédéfini
2. **Alerte de scan** : Détection de motifs de scan systématique d'endpoints
3. **Alerte géographique** : Trafic suspect depuis des pays inhabituels
4. **Alerte de bot malveillant** : Détection de bots non conformes
5. **Alerte de manipulation de tokens** : Tentatives de modification de JWT ou tokens de session

### Dashboard WAF intégré

Le module crée un dashboard CloudWatch complet incluant :

- Vue d'ensemble du trafic et des actions du WAF
- Distribution géographique des requêtes et des attaques
- Top 10 des règles déclenchées et leur fréquence
- Tendances temporelles des attaques
- Statut des protections AWS Shield

### Exemple de configuration du logging

```hcl
resource "aws_wafv2_web_acl_logging_configuration" "accessweaver_waf_logging" {
  log_destination_configs = [aws_kinesis_firehose_delivery_stream.waf_logs.arn]
  resource_arn            = aws_wafv2_web_acl.accessweaver_waf.arn
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
  logging_filter {
    default_behavior = "KEEP"
    filter {
      behavior = "DROP"
      condition {
        action_condition {
          action = "COUNT"
        }
      }
      requirement = "MEETS_ANY"
    }
  }
}
```

---

## 🔗 Intégration avec d'autres Services

### Intégration avec CloudFront

Le module WAF s'intègre à CloudFront pour une protection à la frontière du réseau :

```hcl
# Dans le module CloudFront
resource "aws_cloudfront_distribution" "accessweaver_distribution" {
  # ...
  web_acl_id = module.waf.cloudfront_web_acl_id
  # ...
}
```

Cette intégration offre les avantages suivants :
- Protection au niveau Edge (plus proche des utilisateurs)
- Défense contre les attaques avant qu'elles n'atteignent votre infrastructure
- Capacité d'absorption de très grands volumes de trafic

### Intégration avec Application Load Balancer

Le module WAF se connecte également aux ALB pour une protection au niveau régional :

```hcl
# Dans le module ALB
resource "aws_lb" "accessweaver_alb" {
  # ...
}

resource "aws_wafv2_web_acl_association" "alb_waf_association" {
  resource_arn = aws_lb.accessweaver_alb.arn
  web_acl_arn  = module.waf.regional_web_acl_arn
}
```

Cette protection au niveau ALB permet :
- Filtrage plus détaillé du trafic entrant
- Protection des APIs REST et des applications web
- Contrôle du trafic avant qu'il n'atteigne les containers ECS

### Intégration avec Spring Security

Le module WAF complète la sécurité applicative implémentée dans Spring Security :

| Niveau | Responsabilité | Mise en œuvre |
|--------|----------------|---------------|
| **WAF** | Protection périmétrique, attaques OWASP, DDoS | AWS WAF, AWS Shield |
| **Spring Security** | Authentification, autorisation, CSRF | Filtres Spring Security |

Recommandations pour une défense en profondeur :
1. Configurer des en-têtes de sécurité HTTP côté application
2. Utiliser des tokens JWT signés côté application
3. Définir des validations de données avec Bean Validation
4. Implémenter des contrôles d'accès avec `@PreAuthorize`

### Intégration avec AWS Config

Le module WAF est configuré pour s'intégrer avec AWS Config pour la conformité :

```hcl
resource "aws_config_config_rule" "waf_enabled" {
  name        = "accessweaver-${var.environment}-waf-enabled"
  description = "Vérifie que WAF est activé sur les ressources appropriées"

  source {
    owner             = "AWS"
    source_identifier = "WAF_REGIONAL_WEBACL_NOT_EMPTY"
  }
}
```

Cette intégration permet :
- Surveillance continue de la conformité
- Détection automatique des dérives de configuration
- Rapports de conformité pour les audits

### Matrice d'Intégration

| Service | Type d'Intégration | Production | Staging | Development |
|---------|---------------------|------------|---------|-------------|
| **CloudFront** | Edge WAF | ✅ | ✅ | ✅ |
| **ALB** | Regional WAF | ✅ | ✅ | ✅ |
| **API Gateway** | Regional WAF | ✅ | ✅ | ❌ |
| **Cognito** | Validation supplémentaire | ✅ | ✅ | ❌ |
| **Shield Advanced** | Protection DDoS | ✅ | ❌ | ❌ |
| **AWS Config** | Surveillance de conformité | ✅ | ✅ | ❌ |
| **GuardDuty** | Détection de menaces | ✅ | ✅ | ❌ |

---

## 💯 Bonnes Pratiques et Optimisation

### Sécurité en Couches

L'efficacité maximale du WAF est atteinte en implémentant une stratégie de sécurité multi-couches :

1. **Défense périmétrique** : WAF + CloudFront + Shield
2. **Défense réseau** : Groupes de sécurité + Network ACLs
3. **Défense applicative** : Spring Security + validation des données
4. **Défense base de données** : Requêtes paramétrées + Row-Level Security

### Optimisation des Coûts

Le module propose une stratégie d'optimisation des coûts tout en maintenant une sécurité robuste :

| Approche | Description | Économie |
|----------|-------------|----------|
| **Taux d'échantillonnage logs** | Ajuster le taux d'échantillonnage par environnement | 30-50% sur les coûts de stockage |
| **Shield Advanced sélectif** | Activer uniquement en production | 66% sur les coûts Shield |
| **Règles WAF par environnement** | Ajuster les règles selon la sensibilité | 20-40% sur les coûts WAF |
| **Consolidation des WebACLs** | Réutiliser les WebACLs pour plusieurs ressources | 40-60% sur les coûts WAF |

### Recommandations de Déploiement

1. **Priorisation des règles** : Ordonner les règles du moins coûteux au plus coûteux
2. **Début en mode Count** : Toujours commencer avec les règles en mode Count avant de passer en mode Block
3. **Exceptions précises** : Créer des exceptions plutôt que de désactiver des règles entières
4. **Incrémentalité** : Ajouter progressivement des règles pour minimiser les faux positifs
5. **Tests automatiques** : Valider que les changements de règles WAF n'affectent pas l'application

### Tests de Charge et de Pénétration

Pour valider l'efficacité des règles WAF :

1. **Tests d'attaque simulée** : OWASP ZAP, sqlmap, nikto sur les environnements non-production
2. **Tests de conformité OWASP** : Vérification de la protection contre les 10 principales vulnérabilités
3. **Tests de charge** : Vérifier que le WAF gère correctement les pics de trafic légitimes
4. **Pentests réguliers** : Évaluation par des experts externes au moins annuellement

---

## 📙 Procédures Opérationnelles

### Procédure d'Escalade en cas d'Attaque

1. **Détection**
   - Alertes CloudWatch déclenchées
   - Notification via SNS vers l'équipe de garde

2. **Évaluation initiale** (SLA: 15 min)
   - Vérifier le dashboard WAF
   - Consulter les logs des attaques
   - Évaluer l'impact sur les services

3. **Action immédiate** (SLA: 30 min)
   - Si faux positif : Ajuster les règles WAF
   - Si attaque réelle : Activer les règles d'urgence préconfigurées
   - Si DDoS : Contacter l'équipe de support AWS Shield Advanced

4. **Analyse post-incident** (SLA: 1-2 jours)
   - Revue des logs détaillée
   - Identification des améliorations des règles
   - Documentation et mise à jour des procédures

### Gestion des Faux Positifs

```hcl
resource "aws_wafv2_rule_group" "exception_rules" {
  name     = "accessweaver-${var.environment}-exceptions"
  scope    = "REGIONAL"
  capacity = 100

  rule {
    name     = "allow-trusted-partner"
    priority = 1

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.trusted_partners.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "TrustedPartnerException"
      sampled_requests_enabled   = true
    }
  }
}
```

### Processus de Mise à Jour des Règles

1. **Évaluation des nouvelles règles**
   - Revue des alertes de sécurité AWS
   - Analyse des tendances d'attaque
   - Revue des faux positifs récurrents

2. **Test et Validation**
   - Déployer en mode Count sur staging
   - Analyser l'impact sur 72 heures
   - Test de non-régression des fonctionnalités

3. **Déploiement Progressif**
   - Déployer en production en mode Count
   - Basculer en mode Block après validation
   - Documentation des changements

---

## 📊 Métriques et KPIs

### Indicateurs de Performance

Les KPIs suivants sont mesurés pour évaluer l'efficacité du WAF :

| KPI | Objectif | Méthode de Mesure |
|-----|----------|--------------------|
| **Taux de blocage** | <0.5% trafic légitime | (Faux positifs / Total requêtes) |
| **Taux de détection** | >95% attaques | Tests de pénétration |
| **Latence induite** | <10ms | CloudWatch Metrics |
| **MTTR incidents** | <30 min | Temps moyen de résolution |
| **Couverture OWASP** | 10/10 | Conformité aux règles |

### Tableau de Bord Mensuel

Les métriques suivantes sont incluses dans le rapport mensuel :

1. **Volume d'attaques** : Nombre total d'attaques bloquées
2. **Types d'attaques** : Distribution par catégorie (XSS, SQLi, etc.)
3. **Origine des attaques** : Distribution géographique
4. **Efficacité des règles** : Top 10 des règles déclenchées
5. **Faux positifs** : Nombre et impact

---

## 🗓 Changelog

### Version 1.2 (Juin 2025)
- Ajout de la protection contre Log4Shell
- Intégration avec GuardDuty
- Amélioration des règles de détection de bots

### Version 1.1 (Mars 2025)
- Ajout du support pour Shield Advanced
- Amélioration du rate limiting
- Nouveaux dashboards de monitoring

### Version 1.0 (Janvier 2025)
- Version initiale
- Support OWASP Top 10
- Intégration CloudFront et ALB

---

## 👤 Contacts et Support

### Équipe Responsable
- **Propriétaire du module** : Équipe Platform AccessWeaver
- **Slack** : #accessweaver-security-ops
- **Email** : security-ops@accessweaver.com

### Escalade d'Urgence
- **Astreinte Sécurité** : +33 1 23 45 67 89
- **AWS Support Premium** : Via la console AWS

---

*Document généré par l'équipe Platform AccessWeaver - Derniere mise à jour : Juin 2025*