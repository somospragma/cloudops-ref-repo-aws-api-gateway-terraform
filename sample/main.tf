############################################################################
# Ejemplo de Uso del Módulo API Gateway (Terraform Nativo)
############################################################################

module "api_gateway" {
  source = "../"

  providers = {
    aws.project = aws.principal
  }

  # Variables de Gobernanza (PC-IAC-002)
  client      = var.client
  project     = var.project
  environment = var.environment

  # Configuración de APIs
  api_config = {
    # ====================================================================
    # API Hub - Ejemplo con API Key + Cognito
    # ====================================================================
    hub = {
      description = "API Hub con autenticación mixta"
      stage_name  = "v1"

      # Authorizers
      authorizers = {
        cognito = {
          type          = "COGNITO_USER_POOLS"
          provider_arns = [data.aws_cognito_user_pools.main.arns[0]]
        }
      }

      # Rutas
      routes = {
        # Solo API Key (sin Cognito) - para login
        "/auth/login" = {
          methods          = ["GET"]
          integration_type = "LAMBDA"
          lambda_arn       = data.aws_lambda_function.auth.arn
          api_key_required = true
          authorization    = "NONE"
        }

        # Solo API Key (sin Cognito) - para refresh
        "/auth/refresh" = {
          methods          = ["POST"]
          integration_type = "LAMBDA"
          lambda_arn       = data.aws_lambda_function.auth.arn
          api_key_required = true
          authorization    = "NONE"
        }

        # API Key + Cognito - para accounts
        "/accounts" = {
          methods          = ["GET"]
          integration_type = "LAMBDA"
          lambda_arn       = data.aws_lambda_function.sync.arn
          api_key_required = true
          authorization    = "COGNITO_USER_POOLS"
          authorizer_key   = "cognito"
        }

        # API Key + Cognito - para sync
        "/sync" = {
          methods          = ["POST"]
          integration_type = "LAMBDA"
          lambda_arn       = data.aws_lambda_function.sync.arn
          api_key_required = true
          authorization    = "COGNITO_USER_POOLS"
          authorizer_key   = "cognito"
        }

        # API Key + Cognito - para taxonomy
        "/taxonomy" = {
          methods          = ["GET"]
          integration_type = "LAMBDA"
          lambda_arn       = data.aws_lambda_function.sync.arn
          api_key_required = true
          authorization    = "COGNITO_USER_POOLS"
          authorizer_key   = "cognito"
        }

        # API Key + Cognito - para config
        "/config" = {
          methods          = ["GET"]
          integration_type = "LAMBDA"
          lambda_arn       = data.aws_lambda_function.sync.arn
          api_key_required = true
          authorization    = "COGNITO_USER_POOLS"
          authorizer_key   = "cognito"
        }

        # Solo API Key - health check
        "/health" = {
          methods          = ["GET"]
          integration_type = "MOCK"
          mock_status_code = 200
          mock_response    = "{\"status\":\"healthy\"}"
          api_key_required = true
          authorization    = "NONE"
          cors_enabled     = true
        }

        # Solo API Key - webhook
        "/webhook/github" = {
          methods          = ["POST"]
          integration_type = "LAMBDA"
          lambda_arn       = data.aws_lambda_function.webhook.arn
          api_key_required = true
          authorization    = "NONE"
        }
      }

      # API Keys
      api_keys = {
        hub = {
          description  = "API Key principal para Hub"
          rate_limit   = 100
          burst_limit  = 50
          quota_limit  = 10000
          quota_period = "MONTH"
        }
      }

      # CORS Global
      cors = {
        enabled         = true
        allowed_origins = ["*"]
        allowed_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
        allowed_headers = ["Content-Type", "Authorization", "X-Api-Key"]
        max_age         = 86400
      }

      # Tags adicionales
      additional_tags = {
        Team = "CloudOps"
      }
    }
  }
}
