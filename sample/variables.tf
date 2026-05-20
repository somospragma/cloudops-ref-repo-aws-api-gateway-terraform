############################################################################
# Variables del Ejemplo (PC-IAC-002)
############################################################################

variable "client" {
  description = "Nombre del cliente"
  type        = string

  validation {
    condition     = length(var.client) > 0
    error_message = "El cliente es requerido."
  }
}

variable "project" {
  description = "Nombre del proyecto"
  type        = string

  validation {
    condition     = length(var.project) > 0
    error_message = "El proyecto es requerido."
  }
}

variable "environment" {
  description = "Ambiente de despliegue"
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

variable "deploy_role_arn" {
  description = "ARN del rol para despliegue"
  type        = string
}

variable "cognito_user_pool_name" {
  description = "Nombre del Cognito User Pool"
  type        = string
}

variable "lambda_auth_name" {
  description = "Nombre de la Lambda de autenticación"
  type        = string
}

variable "lambda_sync_name" {
  description = "Nombre de la Lambda de sincronización"
  type        = string
}

variable "lambda_webhook_name" {
  description = "Nombre de la Lambda de webhook"
  type        = string
}

variable "common_tags" {
  description = "Tags comunes para todos los recursos"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}
