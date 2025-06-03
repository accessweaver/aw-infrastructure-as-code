# =============================================================================
# AccessWeaver Production Environment - Backend Configuration
# =============================================================================
# Configuration du stockage de l'état Terraform dans S3 avec verrouillage DynamoDB
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "accessweaver-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "accessweaver-terraform-locks"
  }
}
