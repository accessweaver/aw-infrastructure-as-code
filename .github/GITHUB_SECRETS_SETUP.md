# Configuration des Secrets GitHub pour AccessWeaver Infrastructure

Ce document explique comment configurer les secrets GitHub nécessaires pour le bon fonctionnement des workflows CI/CD.

## Secrets requis

Configurez les secrets suivants dans les paramètres de votre repository GitHub (`https://github.com/accessweaver/aw-infrastructure-as-code/settings/secrets/actions`) :

### Secrets AWS

| Nom du Secret | Description | Exemple |
|--------------|------------|---------|
| `AWS_ROLE_TO_ASSUME` | ARN du rôle IAM à assumer par GitHub Actions | `arn:aws:iam::123456789012:role/github-actions-role` |

### Secrets de Notification

| Nom du Secret | Description | Exemple |
|--------------|------------|---------|
| `SLACK_WEBHOOK_URL` | URL du webhook Slack pour les notifications | `https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX` |

## Configuration des Environnements GitHub

Pour chaque environnement (dev, staging, prod), configurez les environnements GitHub avec les protections appropriées :

1. Allez dans `https://github.com/accessweaver/aw-infrastructure-as-code/settings/environments`
2. Créez les environnements suivants :
   - `dev` (sans protection)
   - `staging` (avec reviewers optionnels)
   - `prod-plan` (avec reviewers obligatoires)
   - `prod` (avec reviewers obligatoires et délai d'attente)

## Configuration IAM AWS

Créez un rôle IAM dans votre compte AWS avec les permissions suivantes :

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:accessweaver/aw-infrastructure-as-code:*"
        }
      }
    }
  ]
}
```

Attachez les politiques suivantes à ce rôle :
- `AmazonS3FullAccess` (ou politique personnalisée plus restrictive pour vos buckets S3)
- `AmazonDynamoDBFullAccess` (ou politique personnalisée pour vos tables DynamoDB)
- `AmazonECR-FullAccess` (pour accéder aux images Docker)
- Politiques personnalisées pour les services que vous utilisez (VPC, ECS, RDS, etc.)

## Configuration GitHub CLI

Pour utiliser les commandes `make promote-*` et `make rollback` localement, installez GitHub CLI :

```bash
# Sur macOS
brew install gh

# Sur Windows
winget install --id GitHub.cli

# Sur Linux
sudo apt install gh  # Debian/Ubuntu
sudo dnf install gh  # Fedora
```

Puis authentifiez-vous :

```bash
gh auth login
```

Suivez les instructions pour vous connecter à votre compte GitHub.
