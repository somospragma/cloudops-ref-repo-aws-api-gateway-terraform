############################################################################
# Invocación del Módulo API Gateway
############################################################################

module "api" {
  source = "../"

  providers = {
    aws.project = aws.main
  }

  # Variables de gobernanza
  client      = var.client
  project     = var.project
  environment = var.environment

  # Configuración transformada
  api_config = local.api_config
}
