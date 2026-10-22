terraform {
  required_version = ">= 1.10"

  # Stan w S3 (bucket tworzy workflow infra.yml), blokada przez plik w S3.
  # Nazwa bucketu podawana przy init: -backend-config="bucket=..."
  backend "s3" {
    key          = "devops-projekt/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}
