############################################################################
# Outputs Granulares (PC-IAC-010)
############################################################################

output "rest_api_ids" {
  description = "Mapa de IDs de las REST APIs creadas"
  value = {
    for key, api in aws_api_gateway_rest_api.this : key => api.id
  }
}

output "rest_api_arns" {
  description = "Mapa de ARNs de las REST APIs creadas"
  value = {
    for key, api in aws_api_gateway_rest_api.this : key => api.arn
  }
}

output "execution_arns" {
  description = "Mapa de Execution ARNs de las REST APIs"
  value = {
    for key, api in aws_api_gateway_rest_api.this : key => api.execution_arn
  }
}

output "root_resource_ids" {
  description = "Mapa de Root Resource IDs de las REST APIs"
  value = {
    for key, api in aws_api_gateway_rest_api.this : key => api.root_resource_id
  }
}

output "invoke_urls" {
  description = "Mapa de URLs de invocación de las APIs"
  value = {
    for key, stage in aws_api_gateway_stage.this : key => stage.invoke_url
  }
}

output "stage_arns" {
  description = "Mapa de ARNs de los stages"
  value = {
    for key, stage in aws_api_gateway_stage.this : key => stage.arn
  }
}

output "stage_names" {
  description = "Mapa de nombres de los stages"
  value = {
    for key, stage in aws_api_gateway_stage.this : key => stage.stage_name
  }
}

output "deployment_ids" {
  description = "Mapa de IDs de los deployments"
  value = {
    for key, deployment in aws_api_gateway_deployment.this : key => deployment.id
  }
}

output "vpc_link_ids" {
  description = "Mapa de IDs de VPC Links creados"
  value = {
    for key, vpc_link in aws_api_gateway_vpc_link.this : key => vpc_link.id
  }
}

output "vpc_link_arns" {
  description = "Mapa de ARNs de VPC Links creados"
  value = {
    for key, vpc_link in aws_api_gateway_vpc_link.this : key => vpc_link.arn
  }
}

output "custom_domain_names" {
  description = "Mapa de nombres de dominio personalizados"
  value = {
    for key, domain in aws_api_gateway_domain_name.this : key => {
      domain_name            = domain.domain_name
      regional_domain_name   = domain.regional_domain_name
      regional_zone_id       = domain.regional_zone_id
      cloudfront_domain_name = domain.cloudfront_domain_name
      cloudfront_zone_id     = domain.cloudfront_zone_id
    }
  }
}

output "apis" {
  description = "Mapa consolidado con toda la información de las APIs"
  value = {
    for key in keys(var.api_config) : key => {
      rest_api_id      = aws_api_gateway_rest_api.this[key].id
      rest_api_arn     = aws_api_gateway_rest_api.this[key].arn
      execution_arn    = aws_api_gateway_rest_api.this[key].execution_arn
      root_resource_id = aws_api_gateway_rest_api.this[key].root_resource_id
      invoke_url       = aws_api_gateway_stage.this[key].invoke_url
      stage_arn        = aws_api_gateway_stage.this[key].arn
      stage_name       = aws_api_gateway_stage.this[key].stage_name
      deployment_id    = aws_api_gateway_deployment.this[key].id
      mode             = local.api_resources[key].mode
    }
  }
}
