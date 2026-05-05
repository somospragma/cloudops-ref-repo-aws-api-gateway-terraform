############################################################################
# Locals - Nomenclatura y Transformaciones (PC-IAC-003, PC-IAC-004)
############################################################################

locals {
  name_prefix = "${var.client}-${var.project}-${var.environment}"

  # Determinar modo de cada API (simple vs rutas)
  api_modes = {
    for key, config in var.api_config : key => (
      length(config.routes) > 0 ? "ROUTES" : "SIMPLE"
    )
  }

  # Transformación base de api_config
  api_resources = {
    for key, config in var.api_config : key => {
      name        = "${local.name_prefix}-api-${key}"
      description = config.description
      mode        = local.api_modes[key]

      # Endpoint
      endpoint_type                = config.endpoint_type
      vpc_endpoint_ids             = config.vpc_endpoint_ids
      disable_execute_api_endpoint = config.disable_execute_api_endpoint

      # Stage
      stage_name           = config.stage_name
      xray_tracing_enabled = config.xray_tracing_enabled

      # Logs
      access_log_destination_arn = config.access_log_destination_arn
      access_log_format = config.access_log_format != "" ? config.access_log_format : jsonencode({
        requestId      = "$context.requestId"
        ip             = "$context.identity.sourceIp"
        requestTime    = "$context.requestTime"
        httpMethod     = "$context.httpMethod"
        resourcePath   = "$context.resourcePath"
        status         = "$context.status"
        responseLength = "$context.responseLength"
      })

      # Compresión y media types
      minimum_compression_size = config.minimum_compression_size
      binary_media_types       = config.binary_media_types

      # Custom domain
      custom_domain_name = config.custom_domain_name
      certificate_arn    = config.certificate_arn
      base_path          = config.base_path

      # CORS
      cors_enabled         = config.cors.enabled
      cors_allowed_origins = join(",", config.cors.allowed_origins)
      cors_allowed_methods = join(",", config.cors.allowed_methods)
      cors_allowed_headers = join(",", config.cors.allowed_headers)
      cors_max_age         = config.cors.max_age

      # Auth a nivel API
      auth_type                = config.auth.type
      auth_cognito_arns        = config.auth.cognito_user_pool_arns
      auth_authorizer_uri      = config.auth.authorizer_uri
      auth_authorizer_creds    = config.auth.authorizer_credentials
      auth_authorizer_ttl      = config.auth.authorizer_result_ttl
      auth_identity_source     = config.auth.identity_source
      auth_identity_validation = config.auth.identity_validation_expression

      # Modo simple
      simple_integration_type = config.integration_type
      simple_lambda_arn       = config.lambda_arn
      simple_backend_url      = config.backend_url
      simple_vpc_link_id      = config.vpc_link_id
      simple_vpc_link_create  = config.vpc_link.create
      simple_vpc_link_name    = config.vpc_link.name != "" ? config.vpc_link.name : "${local.name_prefix}-vpclink-${key}"
      simple_vpc_link_target  = config.vpc_link.target_arn

      # Rutas
      routes = config.routes

      # Tags
      tags = merge({
        Name = "${local.name_prefix}-api-${key}"
        Type = "api-gateway"
      }, config.additional_tags)
    }
  }

  # VPC Links a crear (modo simple)
  vpc_links_simple = {
    for key, api in local.api_resources : key => api
    if api.mode == "SIMPLE" && api.simple_integration_type == "VPC_LINK" && api.simple_vpc_link_create
  }

  # VPC Links a crear (modo rutas) - extraer de rutas que necesitan crear
  vpc_links_routes = merge([
    for api_key, api in local.api_resources : {
      for route_path, route in api.routes : "${api_key}-${replace(replace(route_path, "/", "-"), "{", "")}" => {
        name       = "${local.name_prefix}-vpclink-${api_key}${replace(replace(route_path, "/", "-"), "{", "")}"
        target_arn = "" # Se debe pasar vpc_link_id existente en modo rutas
        tags       = api.tags
      }
    } if api.mode == "ROUTES"
  ]...)

  # Lambdas que necesitan permisos (modo simple)
  lambda_permissions_simple = {
    for key, api in local.api_resources : key => {
      lambda_name   = api.simple_integration_type == "LAMBDA" ? regex("function:([^:]+)$", api.simple_lambda_arn)[0] : ""
      lambda_arn    = api.simple_lambda_arn
      execution_arn = "" # Se llena después
    } if api.mode == "SIMPLE" && api.simple_integration_type == "LAMBDA"
  }

  # Lambdas que necesitan permisos (modo rutas)
  lambda_permissions_routes = merge([
    for api_key, api in local.api_resources : {
      for route_path, route in api.routes : "${api_key}${replace(replace(replace(route_path, "/", "-"), "{", ""), "}", "")}" => {
        api_key       = api_key
        lambda_name   = route.type == "LAMBDA" ? regex("function:([^:]+)$", route.lambda_arn)[0] : ""
        lambda_arn    = route.lambda_arn
        execution_arn = ""
      } if route.type == "LAMBDA"
    } if api.mode == "ROUTES"
  ]...)

  # Authorizer Lambdas que necesitan permisos
  authorizer_lambda_permissions = {
    for key, api in local.api_resources : key => {
      lambda_arn = api.auth_authorizer_uri
    } if contains(["LAMBDA_TOKEN", "LAMBDA_REQUEST"], api.auth_type) && api.auth_authorizer_uri != ""
  }
}
