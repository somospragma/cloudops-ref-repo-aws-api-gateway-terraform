############################################################################
# Configuración de Providers
############################################################################

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# Provider principal
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Client      = var.client
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Alias para el módulo (PC-IAC-005)
provider "aws" {
  alias  = "main"
  region = var.region

  default_tags {
    tags = {
      Client      = var.client
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
