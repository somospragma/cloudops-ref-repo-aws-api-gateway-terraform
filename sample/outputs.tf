############################################################################
# Outputs del Ejemplo (PC-IAC-007)
############################################################################

output "api_invoke_url" {
  description = "URL de invocación de la API Hub"
  value       = module.api_gateway.invoke_urls["hub"]
}

output "api_id" {
  description = "ID de la API Hub"
  value       = module.api_gateway.rest_api_ids["hub"]
}

output "api_key_id" {
  description = "ID de la API Key"
  value       = module.api_gateway.api_key_ids["hub:hub"]
}

output "api_key_value" {
  description = "Valor de la API Key (sensible)"
  value       = module.api_gateway.api_key_values["hub:hub"]
  sensitive   = true
}

output "usage_plan_id" {
  description = "ID del Usage Plan"
  value       = module.api_gateway.usage_plan_ids["hub:hub"]
}

output "authorizer_id" {
  description = "ID del Authorizer Cognito"
  value       = module.api_gateway.authorizer_ids["hub:cognito"]
}

output "consolidated_api_info" {
  description = "Información consolidada de la API"
  value       = module.api_gateway.apis["hub"]
}
