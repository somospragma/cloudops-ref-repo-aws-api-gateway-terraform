############################################################################
# Variables de Gobernanza
############################################################################

variable "client" {
  description = "Nombre del cliente o unidad de negocio"
  type        = string
}

variable "project" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
}

variable "region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

############################################################################
# Variables del Consumidor (Formato Simple)
############################################################################

variable "lambda_arns" {
  description = "Mapa de ARNs de Lambdas disponibles para integrar"
  type        = map(string)
  default     = {}
}

variable "apis" {
  description = <<-EOT
    Mapa de APIs a crear. Soporta dos modos:
    
    MODO SIMPLE (una integración para toda la API):
    - integration_type: LAMBDA o VPC_LINK
    - lambda_key: Key del lambda_arns (si LAMBDA)
    - backend_url + vpc_link_id: URL y VPC Link (si VPC_LINK)
    
    MODO RUTAS (múltiples integraciones):
    - routes: Mapa de rutas con configuración individual
    
    Ambos modos soportan:
    - stage_name: Nombre del stage
    - cors: Configuración de CORS
    - auth: Autenticación (NONE, API_KEY, IAM, COGNITO, LAMBDA_TOKEN, LAMBDA_REQUEST)
  EOT

  type = map(object({
    # Modo simple
    integration_type = optional(string, "")
    lambda_key       = optional(string, "")
    backend_url      = optional(string, "")
    vpc_link_id      = optional(string, "")

    # Modo rutas
    routes = optional(map(object({
      methods     = optional(list(string), ["ANY"])
      type        = string
      lambda_key  = optional(string, "")
      backend_url = optional(string, "")
      vpc_link_id = optional(string, "")
      http_url    = optional(string, "")
      mock_response = optional(object({
        status_code = optional(number, 200)
        body        = optional(string, "{\"status\":\"ok\"}")
      }), null)
      auth = optional(object({
        type = optional(string, "")
      }), null)
    })), {})

    # Comunes
    stage_name = optional(string, "v1")
    cors = optional(object({
      enabled         = optional(bool, false)
      allowed_origins = optional(list(string), ["*"])
      allowed_methods = optional(list(string), ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"])
      allowed_headers = optional(list(string), ["Content-Type", "Authorization", "X-Api-Key"])
    }), { enabled = false })
    auth = optional(object({
      type                   = optional(string, "NONE")
      cognito_user_pool_arns = optional(list(string), [])
      authorizer_uri         = optional(string, "")
    }), { type = "NONE" })
  }))

  default = {}
}
