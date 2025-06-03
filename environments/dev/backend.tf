terraform {
  backend "s3" {
    bucket         = "accessweaver-terraform-state-dev"
    key            = "dev/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "accessweaver-terraform-locks-dev"
    
    # Utilisation de IAM role pour l'authentification
    # Ne pas spécifier de credentials ici, ils seront fournis par AWS CLI ou GitHub Actions
    
    # Paramètres de sécurité supplémentaires
    acl            = "private"
    # Utiliser KMS pour le chiffrement
    kms_key_id     = "alias/terraform-bucket-key-dev"
  }

  # Spécification de la version minimale de Terraform requise
  required_version = ">= 1.5.0"
}
