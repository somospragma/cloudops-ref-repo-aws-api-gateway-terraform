############################################################################
# Outputs del Consumidor
############################################################################

output "api_invoke_urls" {
  description = "URLs de invocación de las APIs"
  value       = module.api.invoke_urls
}

output "api_ids" {
  description = "IDs de las REST APIs"
  value       = module.api.rest_api_ids
}

output "api_execution_arns" {
  description = "Execution ARNs de las APIs (para permisos)"
  value       = module.api.execution_arns
}

output "api_stage_arns" {
  description = "ARNs de los stages"
  value       = module.api.stage_arns
}

output "apis" {
  description = "Información consolidada de todas las APIs"
  value       = module.api.apis
}
