############################################################################
# Configuración de Providers (PC-IAC-005)
############################################################################

provider "aws" {
  region = var.region
  alias  = "principal"

  assume_role {
    role_arn = var.deploy_role_arn
  }

  default_tags {
    tags = var.common_tags
  }
}
