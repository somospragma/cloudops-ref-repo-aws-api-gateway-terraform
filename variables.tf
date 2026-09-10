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

variable "region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

############################################################################
# Variable de Configuración Principal - API Gateway (PC-IAC-002, PC-IAC-010)
############################################################################

variable "api_config" {
  description = <<-EOT
    Mapa de configuración de API Gateway REST APIs (Terraform nativo, sin OpenAPI).
    Cada key representa una API única.
    
    CARACTERÍSTICAS:
    - Soporta combinación de API Key + Cognito en el mismo endpoint
    - Usa recursos nativos de Terraform (no OpenAPI body)
    - Permite configuración granular por ruta
    
    RUTAS:
    - routes: Mapa de rutas con configuración individual
    - Cada ruta puede tener su propia configuración de auth
    
    AUTENTICACIÓN POR RUTA:
    - authorization: NONE, COGNITO_USER_POOLS, CUSTOM, AWS_IAM
    - api_key_required: true/false (independiente del authorization)
    - authorizer_id: ID del authorizer (si usa COGNITO o CUSTOM)
    
    AUTHORIZERS:
    - authorizers: Mapa de authorizers (Cognito o Lambda)
    
    API KEYS Y USAGE PLANS:
    - api_keys: Mapa de API Keys con configuración de throttling/quota
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

    # ========== AUTHORIZERS ==========
    authorizers = optional(map(object({
      type                             = string # COGNITO_USER_POOLS, TOKEN, REQUEST
      provider_arns                    = optional(list(string), [])
      authorizer_uri                   = optional(string, "")
      authorizer_credentials           = optional(string, "")
      authorizer_result_ttl_in_seconds = optional(number, 300)
      identity_source                  = optional(string, "method.request.header.Authorization")
      identity_validation_expression   = optional(string, "")
    })), {})

    # ========== RUTAS ==========
    routes = map(object({
      methods          = optional(list(string), ["GET"])
      integration_type = string # LAMBDA, VPC_LINK, MOCK, HTTP

      # Autenticación por ruta (CLAVE: permite API Key + Cognito)
      authorization    = optional(string, "NONE") # NONE, COGNITO_USER_POOLS, CUSTOM, AWS_IAM
      authorizer_key   = optional(string, "")     # Key del authorizer en authorizers map
      api_key_required = optional(bool, false)

      # Para LAMBDA - ARN de la función Lambda
      # NOTA: Los permisos Lambda se gestionan con el módulo separado
      # cloudops-ref-repo-aws-lambda-permission-terraform
      lambda_arn = optional(string, "") # ARN de la función Lambda

      # Para VPC_LINK
      backend_url = optional(string, "")
      vpc_link_id = optional(string, "")

      # Para MOCK
      mock_status_code = optional(number, 200)
      mock_response    = optional(string, "{\"status\":\"ok\"}")

      # Para HTTP
      http_url    = optional(string, "")
      http_method = optional(string, "ANY")

      # Request parameters (path variables)
      request_parameters = optional(map(bool), {})

      # CORS por ruta
      cors_enabled = optional(bool, false)
    }))

    # ========== API KEYS Y USAGE PLANS ==========
    api_keys = optional(map(object({
      description  = optional(string, "API Key managed by Terraform")
      enabled      = optional(bool, true)
      rate_limit   = optional(number, 100)
      burst_limit  = optional(number, 50)
      quota_limit  = optional(number, 10000)
      quota_period = optional(string, "MONTH") # DAY, WEEK, MONTH
    })), {})

    # ========== VPC LINK (crear nuevo) ==========
    vpc_link = optional(object({
      create     = optional(bool, false)
      name       = optional(string, "")
      target_arn = optional(string, "")
    }), { create = false })

    # ========== CORS GLOBAL ==========
    cors = optional(object({
      enabled         = optional(bool, false)
      allowed_origins = optional(list(string), ["*"])
      allowed_methods = optional(list(string), ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"])
      allowed_headers = optional(list(string), ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token"])
      max_age         = optional(number, 86400)
    }), { enabled = false })

    # ========== CUSTOM DOMAIN ==========
    custom_domain_name = optional(string, "")
    certificate_arn    = optional(string, "")
    base_path          = optional(string, "")

    # ========== CLOUDWATCH LOGS ==========
    logs = optional(object({
      enabled           = optional(bool, true)
      retention_in_days = optional(number, 14)
      kms_key_id        = optional(string, null) # Si null, usa cifrado por defecto (aws/logs)
    }), { enabled = true, retention_in_days = 14, kms_key_id = null })

    # ========== WAF INTEGRATION ==========
    waf_web_acl_arn = optional(string, "") # ARN de Web ACL existente (si vacío, no asocia WAF)

    # ========== RESOURCE POLICY ==========
    resource_policy = optional(object({
      enabled         = optional(bool, false)
      policy_document = optional(string, "") # JSON policy personalizado (si vacío y enabled=true, usa policy permisivo por defecto)
    }), { enabled = false, policy_document = "" })
  }))

  default = {}

  # Validaciones (PC-IAC-002)
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
      alltrue([
        for route_path, route in config.routes :
        contains(["NONE", "COGNITO_USER_POOLS", "CUSTOM", "AWS_IAM"], route.authorization)
      ])
    ])
    error_message = "authorization debe ser NONE, COGNITO_USER_POOLS, CUSTOM o AWS_IAM."
  }

  validation {
    condition = alltrue([
      for key, config in var.api_config :
      alltrue([
        for route_path, route in config.routes :
        contains(["LAMBDA", "VPC_LINK", "MOCK", "HTTP"], route.integration_type)
      ])
    ])
    error_message = "integration_type debe ser LAMBDA, VPC_LINK, MOCK o HTTP."
  }
}
