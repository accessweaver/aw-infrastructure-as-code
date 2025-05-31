#!/bin/bash
set -e

# Configuration par défaut
ENV=${1:-dev}
REGION=${2:-eu-west-1}
PROJECT="accessweaver"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Fonction d'affichage avec couleurs
print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_step() {
    echo -e "${BLUE}🔧 $1${NC}"
}

# Validation des paramètres
if [[ "$ENV" != "dev" && "$ENV" != "staging" && "$ENV" != "prod" ]]; then
    print_error "Environment must be one of: dev, staging, prod"
    exit 1
fi

if [[ ! "$REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]$ ]]; then
    print_error "Invalid AWS region format: $REGION"
    exit 1
fi

print_info "Setting up Terraform backend for environment: $ENV in region: $REGION"

# Vérifier que AWS CLI est configuré
print_step "Checking AWS CLI configuration..."
if ! aws sts get-caller-identity &>/dev/null; then
    print_error "AWS CLI is not configured or credentials are invalid"
    echo "Please run: aws configure"
    exit 1
fi

# Obtenir l'account ID pour des noms uniques
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_info "Using AWS Account ID: $ACCOUNT_ID"

# Noms des ressources
BUCKET_NAME="${PROJECT}-terraform-state-${ENV}-${ACCOUNT_ID}"
TABLE_NAME="${PROJECT}-terraform-locks-${ENV}"

print_info "Backend resources:"
print_info "  S3 Bucket: $BUCKET_NAME"
print_info "  DynamoDB Table: $TABLE_NAME"

# Créer le bucket S3 pour le state
print_step "Creating S3 bucket for Terraform state..."
if aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
    print_warning "S3 bucket $BUCKET_NAME already exists"
else
    if [[ "$REGION" == "us-east-1" ]]; then
        # us-east-1 ne nécessite pas LocationConstraint
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    print_success "S3 bucket created: $BUCKET_NAME"
fi

# Activer le versioning sur le bucket
print_step "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled
print_success "Versioning enabled"

# Activer l'encryption
print_step "Enabling encryption on S3 bucket..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }
        ]
    }'
print_success "Encryption enabled"

# Bloquer l'accès public
print_step "Blocking public access to S3 bucket..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
print_success "Public access blocked"

# Configurer lifecycle policy pour les anciennes versions
print_step "Setting up lifecycle policy..."
cat > /tmp/lifecycle.json << EOF
{
    "Rules": [
        {
            "ID": "terraform-state-cleanup",
            "Status": "Enabled",
            "Filter": {
                "Prefix": ""
            },
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 30
            },
            "AbortIncompleteMultipartUpload": {
                "DaysAfterInitiation": 7
            }
        }
    ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
    --bucket "$BUCKET_NAME" \
    --lifecycle-configuration file:///tmp/lifecycle.json
rm /tmp/lifecycle.json
print_success "Lifecycle policy configured"

# Créer la table DynamoDB pour les locks
print_step "Creating DynamoDB table for Terraform locks..."
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" &>/dev/null; then
    print_warning "DynamoDB table $TABLE_NAME already exists"
else
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$REGION" \
        --tags Key=Project,Value=AccessWeaver Key=Environment,Value="$ENV" Key=ManagedBy,Value=Terraform

    # Attendre que la table soit active
    print_info "Waiting for DynamoDB table to be active..."
    aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$REGION"
    print_success "DynamoDB table created: $TABLE_NAME"
fi

# Activer l'encryption sur DynamoDB si pas déjà fait
print_step "Enabling encryption on DynamoDB table..."
aws dynamodb update-table \
    --table-name "$TABLE_NAME" \
    --region "$REGION" \
    --sse-specification Enabled=true,SSEType=KMS &>/dev/null || true
print_success "DynamoDB encryption enabled"

# Générer la configuration backend pour Terraform
print_step "Generating backend configuration..."
BACKEND_FILE="environments/$ENV/backend.tf"
mkdir -p "environments/$ENV"

cat > "$BACKEND_FILE" << EOF
# Backend configuration for $ENV environment
# Generated automatically by setup-backend.sh
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "$ENV/terraform.tfstate"
    region         = "$REGION"
    dynamodb_table = "$TABLE_NAME"
    encrypt        = true

    # Prevent accidental deletion
    skip_region_validation      = false
    skip_credentials_validation = false
    skip_metadata_api_check     = false
    force_path_style           = false
  }
}
EOF

print_success "Backend configuration generated: $BACKEND_FILE"

# Créer le fichier d'exemple de variables si il n'existe pas
VARS_EXAMPLE_FILE="environments/$ENV/terraform.tfvars.example"
if [[ ! -f "$VARS_EXAMPLE_FILE" ]]; then
    print_step "Creating terraform.tfvars.example..."
    cat > "$VARS_EXAMPLE_FILE" << EOF
# Terraform variables for $ENV environment
# Copy this file to terraform.tfvars and fill in your values

# Project configuration
project_name = "accessweaver"
environment  = "$ENV"
aws_region   = "$REGION"

# Network configuration
vpc_cidr = "10.0.0.0/16"
availability_zones = ["${REGION}a", "${REGION}b"]

# Database configuration
db_instance_class    = "db.t3.micro"  # Adjust for $ENV
db_allocated_storage = 20              # GB
db_multi_az         = false            # Set to true for prod
db_backup_retention = 7                # days

# Redis configuration
redis_node_type         = "cache.t3.micro"  # Adjust for $ENV
redis_num_cache_nodes   = 1                  # Set to 2+ for prod
redis_parameter_group   = "default.redis7"

# ECS configuration
ecs_cpu    = 256   # CPU units
ecs_memory = 512   # MB

# Domain configuration (optional)
# domain_name = "accessweaver-$ENV.example.com"
# certificate_arn = "arn:aws:acm:$REGION:123456789012:certificate/12345678-1234-1234-1234-123456789012"

# Monitoring
enable_monitoring = true
log_retention_days = 14  # CloudWatch logs retention

# Tags
default_tags = {
  Project     = "AccessWeaver"
  Environment = "$ENV"
  ManagedBy   = "Terraform"
  CostCenter  = "Engineering"
}
EOF
    print_success "Variables example file created: $VARS_EXAMPLE_FILE"
fi

# Résumé final
echo ""
print_success "🎉 Backend setup completed successfully!"
echo ""
print_info "📋 Summary:"
print_info "  ✅ S3 bucket: $BUCKET_NAME (versioned, encrypted)"
print_info "  ✅ DynamoDB table: $TABLE_NAME (encrypted)"
print_info "  ✅ Backend config: $BACKEND_FILE"
print_info "  ✅ Variables example: $VARS_EXAMPLE_FILE"
echo ""
print_info "🚀 Next steps:"
print_info "  1. Copy $VARS_EXAMPLE_FILE to environments/$ENV/terraform.tfvars"
print_info "  2. Edit terraform.tfvars with your specific values"
print_info "  3. Run: make init ENV=$ENV"
print_info "  4. Run: make plan ENV=$ENV"
print_info "  5. Run: make apply ENV=$ENV"
echo ""
print_warning "⚠️  Important: Keep your terraform.tfvars file secure and never commit it to Git!"
echo ""