# 🔒 Gestion des Certificats SSL/TLS

Ce document détaille la stratégie et les procédures de gestion des certificats SSL/TLS pour l'infrastructure AccessWeaver, assurant des communications sécurisées et chiffrées.

---

## 📋 Vue d'Ensemble

La gestion appropriée des certificats SSL/TLS est essentielle pour assurer la sécurité des communications au sein de l'infrastructure AccessWeaver. Ce document décrit notre approche complète pour l'acquisition, le déploiement, la rotation et la surveillance des certificats SSL/TLS.

### Objectifs Clés

- Maintenir des communications sécurisées pour tous les services AccessWeaver
- Éviter les interruptions de service liées à l'expiration des certificats
- Appliquer les meilleures pratiques de sécurité pour les certificats
- Automatiser la gestion du cycle de vie des certificats
- Assurer la conformité aux normes de sécurité et de conformité

---

## 🌐 Types de Certificats Utilisés

| Type | Utilisation | Durée | Autorité de Certification |
|------|-------------|--------|----------------------------|
| **Certificats EV (Extended Validation)** | Domaines critiques de production | 1 an | DigiCert |
| **Certificats OV (Organization Validation)** | Services principaux | 1 an | Let's Encrypt / AWS ACM |
| **Certificats Wildcard** | Sous-domaines multiples | 1 an | AWS ACM |
| **Certificats internes** | Communication inter-services | 90 jours | PKI interne |

---

## 📚 Architecture de Gestion des Certificats

### 1. Sources de Certificats

- **AWS Certificate Manager (ACM)**
  - Utilisé pour les certificats destinés aux services AWS (ALB, CloudFront)
  - Gestion automatisée du renouvellement
  - Intégration native avec les services AWS

- **Let's Encrypt**
  - Utilisé pour les certificats non-ACM
  - Intégré via cert-manager dans Kubernetes
  - Renouvellement automatisé via ACME

- **PKI Interne**
  - Basée sur HashiCorp Vault
  - Pour les certificats des services internes
  - Rotation automatique via les hooks Terraform

### 2. Flux de Déploiement

```
                      +-------------------+
                      |   Infrastructure  |
                      |    as Code (IaC)  |
                      +-------------------+
                               |
                               v
+----------------+    +-------------------+    +----------------+
|  Certificate   |    |  Terraform /     |    | AWS Services   |
|  Authorities   |--->|  Automation      |--->| (ALB, ECS,     |
+----------------+    +-------------------+    |  CloudFront)   |
                               |               +----------------+
                               v
                      +-------------------+
                      |   Monitoring &    |
                      |   Alerting        |
                      +-------------------+
```

---

## 🛠️ Gestion du Cycle de Vie

### 1. Acquisition et Génération

#### Avec AWS ACM

```hcl
# Exemple de configuration Terraform pour ACM
resource "aws_acm_certificate" "main" {
  domain_name       = "api.accessweaver.com"
  validation_method = "DNS"
  
  subject_alternative_names = [
    "auth.accessweaver.com",
    "pdp.accessweaver.com"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "AccessWeaver-API-Certificate"
    Environment = var.environment
    Service     = "api-gateway"
  }
}
```

#### Avec cert-manager/Let's Encrypt

```yaml
# Exemple de configuration cert-manager
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: accessweaver-api-cert
  namespace: accessweaver
spec:
  secretName: accessweaver-api-tls
  duration: 2160h  # 90 jours
  renewBefore: 360h  # 15 jours avant expiration
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - api.accessweaver.com
  - auth.accessweaver.com
```

### 2. Déploiement

- **AWS ACM** : Intégré directement avec les services AWS via IaC
- **Services ECS** : Montés via AWS Secrets Manager
- **Services K8s** : Déployés via cert-manager et secrets Kubernetes

### 3. Rotation et Renouvellement

- **Stratégie de renouvellement** : Automatique, 30 jours avant expiration
- **Processus de rotation** : Zero-downtime avec configuration blue/green
- **Validation** : Tests automatiques post-rotation

### 4. Révocation

- **Critères de révocation** : Compromission, départ d'employés avec accès
- **Procédure de révocation** : Intégrée au processus de réponse aux incidents

---

## 📈 Surveillance et Alertes

### Monitoring des Certificats

- **Alertes d'expiration** : Notification 30, 14, et 7 jours avant expiration
- **Validation continue** : Vérification quotidienne de la validité des certificats
- **Contrôles d'intégrité** : Vérification de la configuration TLS

```bash
# Script de surveillance des certificats - Extrait
function check_certificate_expiry() {
  domain=$1
  expiry_date=$(echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | \
                openssl x509 -noout -enddate | cut -d= -f2)
  
  expiry_epoch=$(date -d "$expiry_date" +%s)
  current_epoch=$(date +%s)
  
  days_remaining=$(( ($expiry_epoch - $current_epoch) / 86400 ))
  
  if [ $days_remaining -lt 30 ]; then
    aws cloudwatch put-metric-data --namespace "AccessWeaver/SSL" \
      --metric-name "CertificateExpirySoon" \
      --dimensions "Domain=$domain" \
      --value $days_remaining
  fi
}
```

### CloudWatch Alertes

```hcl
# Alerte CloudWatch pour les certificats expirant bientôt
resource "aws_cloudwatch_metric_alarm" "certificate_expiry" {
  alarm_name          = "certificate-expiry-warning"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DaysToExpiry"
  namespace           = "AccessWeaver/SSL"
  period              = "86400"
  statistic           = "Minimum"
  threshold           = "15"
  alarm_description   = "Cette alarme surveille l'expiration imminente des certificats SSL"
  alarm_actions       = [aws_sns_topic.ssl_alerts.arn]
  
  dimensions = {
    CertificateType = "All"
  }
}
```

---

## 🛃 Bonnes Pratiques Implémentées

### Configuration TLS

- **Versions supportées** : TLS 1.2 et TLS 1.3 uniquement
- **Suites de chiffrement** : Recommandations Mozilla Modern
- **HSTS** : Activé avec includeSubDomains et preload
- **OCSP Stapling** : Activé pour tous les certificats publics

### Exemple de Configuration ALB

```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"  # TLS 1.2+
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
```

### Exemple de Configuration Nginx

```nginx
server {
    listen 443 ssl http2;
    server_name api.accessweaver.com;
    
    ssl_certificate /etc/ssl/certs/api-accessweaver.pem;
    ssl_certificate_key /etc/ssl/private/api-accessweaver.key;
    
    # Paramètres TLS optimisés
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    
    # HSTS (31536000 seconds = 1 year)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    
    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # ... reste de la configuration
}
```

---

## 🗃️ Inventaire et Documentation

### Registre des Certificats

Un inventaire centralisé des certificats est maintenu avec les informations suivantes :

| Domaine | Type | Expiration | Autorité | Service | Environnement | Responsable |
|---------|------|------------|-----------|---------|---------------|-------------|
| api.accessweaver.com | EV | 2025-12-01 | DigiCert | API Gateway | Production | DevOps Team |
| *.staging.accessweaver.com | Wildcard | 2025-09-15 | ACM | Multiple | Staging | DevOps Team |
| internal-auth.accessweaver.com | OV | 2025-08-03 | Let's Encrypt | Auth Service | Production | Security Team |

L'inventaire est maintenu à jour par automation et accessible via :

```bash
# Génération de l'inventaire des certificats
make ssl-inventory ENV=all
```

### Diagramme d'Architecture

```
+------------------+      +------------------+      +------------------+
|                  |      |                  |      |                  |
|  Client Browser  +----->+      ALB        +----->+  Application     |
|                  |      | (ACM Certificate)|      |                  |
+------------------+      +------------------+      +------------------+
                                                             |
                                                             v
                                                    +------------------+
                                                    |                  |
                                                    |  Internal        |
                                                    |  Services        |
                                                    | (Let's Encrypt)  |
                                                    +------------------+
                                                             |
                                                             v
                                                    +------------------+
                                                    |                  |
                                                    |   Databases      |
                                                    | (Internal PKI)   |
                                                    |                  |
                                                    +------------------+
```

---

## 🗡️ Procédures Opérationnelles

### Renouvellement Manuel (Cas d'Urgence)

```bash
# Procédure de renouvellement manuel d'un certificat Let's Encrypt

# 1. Générer le certificat
certbot certonly --webroot -w /var/www/html -d api.accessweaver.com

# 2. Convertir au format approprié
openssl pkcs12 -export -out cert.p12 -inkey /etc/letsencrypt/live/api.accessweaver.com/privkey.pem \
-in /etc/letsencrypt/live/api.accessweaver.com/fullchain.pem

# 3. Importer dans AWS Secrets Manager
aws secretsmanager update-secret --secret-id api/ssl-cert --secret-binary fileb://cert.p12

# 4. Vérifier le déploiement
curl -vI https://api.accessweaver.com 2>&1 | grep "expire date"
```

### Rotation d'Urgence

En cas de compromission suspectée d'un certificat :

1. **Révoquer** le certificat actuel auprès de l'autorité de certification
2. **Générer** un nouveau certificat via la procédure d'urgence
3. **Déployer** immédiatement sur tous les services concernés
4. **Notifier** l'équipe de sécurité et documenter l'incident
5. **Vérifier** l'impact sur les utilisateurs et services

---

## 📃 Plan d'Amélioration Continue

| Initiative | Description | Priorité | Échéance |
|------------|-------------|----------|------------|
| **Migration Certificate Transparency** | Implémenter la surveillance via Certificate Transparency logs | Moyenne | Q3 2025 |
| **Automatisation complète** | Finaliser l'automation zero-touch pour tous les certificats | Haute | Q4 2025 |
| **PKI interne renforcée** | Migration vers une infrastructure PKI HA avec rotation automatique | Moyenne | Q1 2026 |
| **Implémentation mTLS** | Déployer mTLS pour les communications inter-services | Basse | Q2 2026 |

---

## 👮‍♂️ Responsabilités et Contacts

### Matrice RACI

| Activité | DevOps | Sécurité | Développement | Direction |
|----------|--------|----------|---------------|----------|
| Génération des certificats | R | A | I | I |
| Configuration sécurisée TLS | R | A | C | I |
| Monitoring et alertes | R | A | I | I |
| Gestion des incidents | R | A | C | I |
| Revue de sécurité | C | R | I | A |

*R: Responsible, A: Accountable, C: Consulted, I: Informed*

### Contacts d'Urgence

| Niveau | Contact | Délai de Réponse |
|--------|---------|------------------|
| Problème de certificat | certificates@accessweaver.com | <4h |
| Expiration imminente | devops@accessweaver.com | <2h |
| Compromission suspecte | security@accessweaver.com | <30min |

---

## 📓 Ressources Utiles

- **[SSL Labs Server Test](https://www.ssllabs.com/ssltest/)** - Outil d'évaluation de configuration SSL/TLS
- **[Procédure de Réponse aux Incidents](../operations/incident-response.md)** - En cas de compromission
- **[Politique de Chiffrement](./encryption.md)** - Politique générale de chiffrement

---

*Dernière mise à jour: 2025-06-03*

*Statut du document: ✅ Complet*