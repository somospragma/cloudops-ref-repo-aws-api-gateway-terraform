############################################################################
# Variables de Gobernanza (PC-IAC-002)
############################################################################

variable "client" {
  description = "Nombre del cliente o unidad de negocio"
  type        = string

  validation {
    condition     = length(var.client) > 0 && length(var.client) <= 10
    error_message = "El cliente debe tener entre 1 y 10 caracteres."
  }
}

variable "project" {
  description = "Nombre del proyecto"
  type        = string

  validation {
    condition     = length(var.project) > 0 && length(var.project) <= 15
    error_message = "El proyecto debe tener entre 1 y 15 caracteres."
  }
}

variable "environment" {
  description = "Ambiente de despliegue (dev, qa, pdn)"
  type        = string

  validation {
    condition     = contains(["dev", "qa", "stg", "pdn", "prod"], var.environment)
    error_message = "El ambiente debe ser uno de: dev, qa, stg, pdn, prod."
  }
}

############################################################################
# Variable de Configuración Principal (PC-IAC-002, PC-IAC-009)
############################################################################

variable "api_config" {
  description = <<-EOT
    Mapa de configuración de API Gateway REST APIs.
    Cada key representa una API única.
    
    MODO SIMPLE (una integración para toda la API):
    - integration_type: LAMBDA o VPC_LINK
    - lambda_arn: ARN de Lambda (si LAMBDA)
    - backend_url + vpc_link_id: URL y VPC Link (si VPC_LINK)
    
    MODO RUTAS (múltiples rutas con diferentes integraciones):
    - routes: Mapa de rutas con configuración individual
    
    AUTENTICACIÓN (a nivel API, heredable por rutas):
    - auth.type: NONE, API_KEY, IAM, COGNITO, LAMBDA_TOKEN, LAMBDA_REQUEST
    - auth.cognito_user_pool_arns: ARNs de Cognito (si COGNITO)
    - auth.authorizer_uri: URI de Lambda authorizer (si LAMBDA_*)
    - auth.authorizer_credentials: Rol IAM para invocar authorizer
    - auth.authorizer_result_ttl: TTL del cache del authorizer
    - auth.identity_source: Fuente de identidad (header, query, etc)
    - auth.identity_validation_expression: Regex para validar token
    
    CORS:
    - cors.enabled: Habilitar CORS
    - cors.allowed_origins, allowed_methods, allowed_headers, max_age
    
    CUSTOM DOMAIN:
    - custom_domain_name, certificate_arn, base_path
    
    VPC LINK (crear nuevo):
    - vpc_link.create: true para crear
    - vpc_link.target_arn: ARN del NLB
  EOT

  type = map(object({
    # Generales
    description                  = optional(string, "API Gateway REST API")
    endpoint_type                = optional(string, "REGIONAL")
    stage_name                   = optional(string, "v1")
    disable_execute_api_endpoint = optional(bool, false)
    minimum_compression_size     = optional(number, -1)
    binary_media_types           = optional(list(string), [])
    xray_tracing_enabled         = optional(bool, false)
    access_log_destination_arn   = optional(string, "")
    access_log_format            = optional(string, "")
    vpc_endpoint_ids             = optional(list(string), [])
    additional_tags              = optional(map(string), {})

    # ========== MODO SIMPLE (una integración) ==========
    integration_type = optional(string, "")
    lambda_arn       = optional(string, "")
    backend_url      = optional(string, "")
    vpc_link_id      = optional(string, "")
    vpc_link = optional(object({
      create     = optional(bool, false)
      name       = optional(string, "")
      target_arn = optional(string, "")
    }), { create = false })

    # ========== MODO RUTAS (múltiples integraciones) ==========
    routes = optional(map(object({
      methods = optional(list(string), ["ANY"])
      type    = string # LAMBDA, VPC_LINK, MOCK, HTTP

      # Para LAMBDA
      lambda_arn = optional(string, "")

      # Para VPC_LINK
      backend_url = optional(string, "")
      vpc_link_id = optional(string, "")

      # Para MOCK
      mock_response = optional(object({
        status_code = optional(number, 200)
        body        = optional(string, "{\"status\":\"ok\"}")
      }), null)

      # Para HTTP
      http_url = optional(string, "")

      # Auth override por ruta
      auth = optional(object({
        type                           = optional(string, "")
        cognito_user_pool_arns         = optional(list(string), [])
        authorizer_uri                 = optional(string, "")
        authorizer_credentials         = optional(string, "")
        authorizer_result_ttl          = optional(number, 300)
        identity_source                = optional(string, "method.request.header.Authorization")
        identity_validation_expression = optional(string, "")
      }), null)
    })), {})

    # ========== AUTENTICACIÓN (nivel API) ==========
    auth = optional(object({
      type                           = optional(string, "NONE")
      cognito_user_pool_arns         = optional(list(string), [])
      authorizer_uri                 = optional(string, "")
      authorizer_credentials         = optional(string, "")
      authorizer_result_ttl          = optional(number, 300)
      identity_source                = optional(string, "method.request.header.Authorization")
      identity_validation_expression = optional(string, "")
    }), { type = "NONE" })

    # ========== CORS ==========
    cors = optional(object({
      enabled         = optional(bool, false)
      allowed_origins = optional(list(string), ["*"])
      allowed_methods = optional(list(string), ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"])
      allowed_headers = optional(list(string), ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token"])
      expose_headers  = optional(list(string), [])
      max_age         = optional(number, 86400)
    }), { enabled = false })

    # ========== CUSTOM DOMAIN ==========
    custom_domain_name = optional(string, "")
    certificate_arn    = optional(string, "")
    base_path          = optional(string, "")
  }))

  default = {}

  # Validaciones
  validation {
    condition = alltrue([
      for key, config in var.api_config :
      contains(["REGIONAL", "EDGE", "PRIVATE"], config.endpoint_type)
    ])
    error_message = "endpoint_type debe ser REGIONAL, EDGE o PRIVATE."
  }

  validation {
    condition = alltrue([
      for key, config in var.api_config :
      config.endpoint_type != "PRIVATE" || length(config.vpc_endpoint_ids) > 0
    ])
    error_message = "vpc_endpoint_ids es requerido cuando endpoint_type es PRIVATE."
  }

  validation {
    condition = alltrue([
      for key, config in var.api_config :
      contains(["NONE", "API_KEY", "IAM", "COGNITO", "LAMBDA_TOKEN", "LAMBDA_REQUEST"], config.auth.type)
    ])
    error_message = "auth.type debe ser NONE, API_KEY, IAM, COGNITO, LAMBDA_TOKEN o LAMBDA_REQUEST."
  }
}
