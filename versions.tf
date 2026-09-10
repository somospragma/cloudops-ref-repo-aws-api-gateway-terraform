############################################################################
# Requisitos de Versión de Terraform y Providers (PC-IAC-006)
############################################################################

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.0.0"
      configuration_aliases = [aws.project] # Alias Consumidor Obligatorio (PC-IAC-005)
    }
  }
}
