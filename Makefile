.PHONY: help setup-backend init plan apply destroy validate fmt security-scan costs outputs clean promote-staging promote-prod rollback tag-version

# Configuration par défaut
ENV ?= dev
REGION ?= eu-west-1
PROJECT := accessweaver

# Couleurs pour l'affichage
RED := \033[31m
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
PURPLE := \033[35m
CYAN := \033[36m
WHITE := \033[37m
RESET := \033[0m

help: ## 📚 Afficher l'aide
	@echo "$(CYAN)🏗 AccessWeaver Infrastructure Commands$(RESET)"
	@echo ""
	@echo "$(YELLOW)📋 Commandes principales:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)🎯 Exemples d'utilisation:$(RESET)"
	@echo "  $(BLUE)make setup-backend ENV=dev$(RESET)     # Setup backend S3/DynamoDB"
	@echo "  $(BLUE)make deploy ENV=dev$(RESET)            # Déployer environnement dev"
	@echo "  $(BLUE)make costs ENV=prod$(RESET)            # Estimer coûts production"
	@echo ""
	@echo "$(YELLOW)🌍 Environnements disponibles:$(RESET) dev, staging, prod"

setup-backend: ## 🚀 Setup backend S3/DynamoDB pour un environnement
	@echo "$(CYAN)🚀 Setting up Terraform backend for $(ENV) environment$(RESET)"
	@if [ ! -f "scripts/setup-backend.sh" ]; then \
		echo "$(RED)❌ Script setup-backend.sh not found$(RESET)"; \
		exit 1; \
	fi
	@chmod +x scripts/setup-backend.sh
	@./scripts/setup-backend.sh $(ENV) $(REGION)
	@echo "$(GREEN)✅ Backend setup completed$(RESET)"

init: ## 🔧 Initialiser Terraform pour un environnement
	@echo "$(CYAN)🔧 Initializing Terraform for $(ENV)$(RESET)"
	@if [ ! -d "environments/$(ENV)" ]; then \
		echo "$(RED)❌ Environment $(ENV) does not exist$(RESET)"; \
		exit 1; \
	fi
	@cd environments/$(ENV) && terraform init
	@echo "$(GREEN)✅ Terraform initialized$(RESET)"

plan: init ## 📋 Planifier les changements pour un environnement
	@echo "$(CYAN)📋 Planning changes for $(ENV)$(RESET)"
	@cd environments/$(ENV) && terraform plan -out=terraform.tfplan -var-file=terraform.tfvars
	@echo "$(GREEN)✅ Plan generated: environments/$(ENV)/terraform.tfplan$(RESET)"

apply: ## 🚀 Appliquer les changements planifiés
	@echo "$(CYAN)🚀 Applying changes for $(ENV)$(RESET)"
	@if [ ! -f "environments/$(ENV)/terraform.tfplan" ]; then \
		echo "$(RED)❌ No plan found. Run 'make plan ENV=$(ENV)' first$(RESET)"; \
		exit 1; \
	fi
	@cd environments/$(ENV) && terraform apply terraform.tfplan
	@rm -f environments/$(ENV)/terraform.tfplan
	@echo "$(GREEN)✅ Changes applied successfully$(RESET)"

deploy: plan apply ## 🎯 Déployer (plan + apply) en une commande
	@echo "$(GREEN)✅ Deployment completed for $(ENV)$(RESET)"

destroy: ## 💥 Détruire l'infrastructure (avec confirmation)
	@echo "$(RED)💥 WARNING: This will destroy ALL infrastructure for $(ENV)$(RESET)"
	@echo "$(YELLOW)⚠️  This action is IRREVERSIBLE$(RESET)"
	@read -p "Are you absolutely sure you want to destroy $(ENV)? Type 'yes' to confirm: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		echo "$(CYAN)🔥 Destroying infrastructure for $(ENV)$(RESET)"; \
		cd environments/$(ENV) && terraform destroy -var-file=terraform.tfvars -auto-approve; \
		echo "$(GREEN)✅ Infrastructure destroyed$(RESET)"; \
	else \
		echo "$(YELLOW)⏹️  Operation cancelled$(RESET)"; \
	fi

validate: ## ✅ Valider la configuration Terraform
	@echo "$(CYAN)✅ Validating Terraform configuration for $(ENV)$(RESET)"
	@cd environments/$(ENV) && terraform validate
	@cd environments/$(ENV) && terraform fmt -check=true -diff=true
	@echo "$(GREEN)✅ Configuration is valid$(RESET)"

fmt: ## 🎨 Formatter le code Terraform
	@echo "$(CYAN)🎨 Formatting Terraform code$(RESET)"
	@terraform fmt -recursive .
	@echo "$(GREEN)✅ Code formatted$(RESET)"

security-scan: ## 🛡 Scanner la sécurité avec tfsec
	@echo "$(CYAN)🛡 Running security scan$(RESET)"
	@if ! command -v tfsec >/dev/null 2>&1; then \
		echo "$(YELLOW)⚠️  tfsec not installed. Installing...$(RESET)"; \
		if command -v brew >/dev/null 2>&1; then \
			brew install tfsec; \
		else \
			echo "$(RED)❌ Please install tfsec manually: https://github.com/aquasecurity/tfsec$(RESET)"; \
			exit 1; \
		fi \
	fi
	@tfsec . --format=compact
	@echo "$(GREEN)✅ Security scan completed$(RESET)"

costs: init ## 💰 Estimer les coûts avec Infracost
	@echo "$(CYAN)💰 Estimating costs for $(ENV)$(RESET)"
	@if ! command -v infracost >/dev/null 2>&1; then \
		echo "$(YELLOW)⚠️  Infracost not installed. Using basic Terraform plan$(RESET)"; \
		cd environments/$(ENV) && terraform plan -var-file=terraform.tfvars; \
	else \
		cd environments/$(ENV) && infracost breakdown --path .; \
	fi

outputs: ## 📊 Afficher les outputs Terraform
	@echo "$(CYAN)📊 Terraform outputs for $(ENV)$(RESET)"
	@cd environments/$(ENV) && terraform output -json | jq '.'

state-list: ## 📋 Lister les ressources dans le state
	@echo "$(CYAN)📋 Terraform state resources for $(ENV)$(RESET)"
	@cd environments/$(ENV) && terraform state list

refresh: ## 🔄 Refresh du state Terraform
	@echo "$(CYAN)🔄 Refreshing Terraform state for $(ENV)$(RESET)"
	@cd environments/$(ENV) && terraform refresh -var-file=terraform.tfvars

import: ## 📥 Importer une ressource existante
	@echo "$(CYAN)📥 Import existing resource$(RESET)"
	@echo "Usage: make import ENV=dev RESOURCE=aws_instance.example ID=i-1234567890abcdef0"
	@if [ -z "$(RESOURCE)" ] || [ -z "$(ID)" ]; then \
		echo "$(RED)❌ RESOURCE and ID parameters are required$(RESET)"; \
		exit 1; \
	fi
	@cd environments/$(ENV) && terraform import $(RESOURCE) $(ID)

unlock: ## 🔓 Forcer l'unlock du state (en cas de lock bloqué)
	@echo "$(YELLOW)⚠️  Force unlocking Terraform state for $(ENV)$(RESET)"
	@read -p "Lock ID to unlock: " lock_id; \
	if [ -n "$$lock_id" ]; then \
		cd environments/$(ENV) && terraform force-unlock $$lock_id; \
	else \
		echo "$(RED)❌ Lock ID is required$(RESET)"; \
	fi

clean: ## 🧹 Nettoyer les fichiers temporaires
	@echo "$(CYAN)🧹 Cleaning temporary files$(RESET)"
	@find . -name "*.tfplan" -delete
	@find . -name ".terraform.lock.hcl" -delete
	@find . -name "terraform.tfstate.backup" -delete
	@echo "$(GREEN)✅ Temporary files cleaned$(RESET)"

docs: ## 📚 Générer la documentation des modules
	@echo "$(CYAN)📚 Generating module documentation$(RESET)"
	@if ! command -v terraform-docs >/dev/null 2>&1; then \
		echo "$(YELLOW)⚠️  terraform-docs not installed$(RESET)"; \
		echo "Install with: brew install terraform-docs"; \
		exit 1; \
	fi
	@for module in modules/*/; do \
		echo "$(BLUE)📝 Generating docs for $$module$(RESET)"; \
		terraform-docs markdown table --output-file README.md $$module; \
	done
	@echo "$(GREEN)✅ Documentation generated$(RESET)"

check-tools: ## 🔍 Vérifier les outils requis
	@echo "$(CYAN)🔍 Checking required tools$(RESET)"
	@echo -n "Terraform: "; terraform --version | head -n1 || echo "$(RED)❌ Not installed$(RESET)"
	@echo -n "AWS CLI: "; aws --version || echo "$(RED)❌ Not installed$(RESET)"
	@echo -n "jq: "; jq --version || echo "$(RED)❌ Not installed$(RESET)"
	@echo -n "GitHub CLI: "; gh --version || echo "$(RED)❌ Not installed (required for promotions)$(RESET)"
	@echo -n "tfsec: "; tfsec --version || echo "$(YELLOW)⚠️  Not installed (optional)$(RESET)"
	@echo -n "terraform-docs: "; terraform-docs --version || echo "$(YELLOW)⚠️  Not installed (optional)$(RESET)"
	@echo -n "infracost: "; infracost --version || echo "$(YELLOW)⚠️  Not installed (optional)$(RESET)"

# Commandes spécifiques aux environnements
dev: ENV=dev
dev: deploy ## 🔧 Déployer l'environnement dev

staging: ENV=staging
staging: deploy ## 🎭 Déployer l'environnement staging

prod: ENV=prod
prod: deploy ## 🚀 Déployer l'environnement prod

# Commandes de promotion et rollback
promote-staging: ## 🚀 Promouvoir une version vers staging
	@echo "$(CYAN)🚀 Promoting version to staging$(RESET)"
	@read -p "Enter version tag to promote (e.g., v1.2.3): " version; \
	if [ -n "$$version" ]; then \
		echo "$(YELLOW)Triggering GitHub workflow to promote $$version to staging...$(RESET)"; \
		if command -v gh >/dev/null 2>&1; then \
			gh workflow run promote-staging.yml -f version=$$version; \
		else \
			echo "$(RED)❌ GitHub CLI not installed. Please install it or trigger the workflow manually.$(RESET)"; \
		fi; \
	else \
		echo "$(RED)❌ Version tag is required$(RESET)"; \
	fi

promote-prod: ## 🚀 Promouvoir une version vers production
	@echo "$(CYAN)🚀 Promoting version to production$(RESET)"
	@read -p "Enter version tag to promote (e.g., v1.2.3): " version; \
	if [ -n "$$version" ]; then \
		echo "$(YELLOW)⚠️  This will trigger deployment to PRODUCTION environment$(RESET)"; \
		read -p "Are you sure you want to continue? (yes/no): " confirm; \
		if [ "$$confirm" = "yes" ]; then \
			echo "$(YELLOW)Triggering GitHub workflow to promote $$version to production...$(RESET)"; \
			if command -v gh >/dev/null 2>&1; then \
				gh workflow run promote-prod.yml -f version=$$version -f approve=true; \
			else \
				echo "$(RED)❌ GitHub CLI not installed. Please install it or trigger the workflow manually.$(RESET)"; \
			fi; \
		else \
			echo "$(YELLOW)⏹️  Operation cancelled$(RESET)"; \
		fi; \
	else \
		echo "$(RED)❌ Version tag is required$(RESET)"; \
	fi

rollback: ## ⏮️ Rollback d'urgence
	@echo "$(RED)⏮️  EMERGENCY ROLLBACK$(RESET)"
	@echo "$(YELLOW)⚠️  This will rollback an environment to a previous version$(RESET)"
	@read -p "Enter environment to rollback (dev/staging/prod): " env; \
	read -p "Enter version tag to rollback to (e.g., v1.2.2): " version; \
	if [ -n "$$env" ] && [ -n "$$version" ]; then \
		if [ "$$env" = "prod" ]; then \
			echo "$(RED)⚠️  WARNING: You are about to rollback the PRODUCTION environment!$(RESET)"; \
			read -p "Type 'CONFIRM ROLLBACK' to proceed: " confirm; \
			if [ "$$confirm" != "CONFIRM ROLLBACK" ]; then \
				echo "$(YELLOW)⏹️  Rollback cancelled$(RESET)"; \
				exit 1; \
			fi; \
		fi; \
		echo "$(YELLOW)Triggering GitHub workflow for rollback...$(RESET)"; \
		if command -v gh >/dev/null 2>&1; then \
			gh workflow run rollback.yml -f environment=$$env -f version=$$version; \
		else \
			echo "$(RED)❌ GitHub CLI not installed. Please install it or trigger the workflow manually.$(RESET)"; \
		fi; \
	else \
		echo "$(RED)❌ Both environment and version tag are required$(RESET)"; \
	fi

# Commande pour créer un nouveau tag de version
tag-version: ## 🏷️ Créer un nouveau tag de version
	@echo "$(CYAN)🏷️ Creating new version tag$(RESET)"
	@read -p "Enter new version (e.g., v1.2.3): " version; \
	if [ -n "$$version" ]; then \
		echo "$(YELLOW)Creating git tag $$version...$(RESET)"; \
		git tag -a $$version -m "Release $$version"; \
		git push origin $$version; \
		echo "$(GREEN)✅ Tag $$version created and pushed$(RESET)"; \
	else \
		echo "$(RED)❌ Version is required$(RESET)"; \
	fi

# Targets spéciaux
.DEFAULT_GOAL := help