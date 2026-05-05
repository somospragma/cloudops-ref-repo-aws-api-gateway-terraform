############################################################################
# Locals - Transformación de Variables (PC-IAC-026)
############################################################################

locals {
  # Transformación del formato simple del consumidor al formato api_config del módulo
  api_config = {
    for key, api in var.apis : key => {
      # Generales
      stage_name = api.stage_name

      # Modo simple
      integration_type = api.integration_type
      lambda_arn       = api.lambda_key != "" ? var.lambda_arns[api.lambda_key] : ""
      backend_url      = api.backend_url
      vpc_link_id      = api.vpc_link_id

      # Modo rutas - transformar lambda_key a lambda_arn
      routes = {
        for route_path, route in api.routes : route_path => {
          methods       = route.methods
          type          = route.type
          lambda_arn    = route.lambda_key != "" ? var.lambda_arns[route.lambda_key] : ""
          backend_url   = route.backend_url
          vpc_link_id   = route.vpc_link_id
          http_url      = route.http_url
          mock_response = route.mock_response
          auth          = route.auth
        }
      }

      # CORS
      cors = api.cors

      # Auth
      auth = {
        type                   = api.auth.type
        cognito_user_pool_arns = api.auth.cognito_user_pool_arns
        authorizer_uri         = api.auth.authorizer_uri
      }
    }
  }
}
