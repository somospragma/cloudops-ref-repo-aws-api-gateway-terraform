############################################################################
# Locals - Nomenclatura y Transformaciones (PC-IAC-003, PC-IAC-012)
############################################################################

locals {
  # ========================================================================
  # 1. PREFIJO DE GOBERNANZA (PC-IAC-003)
  # ========================================================================
  governance_prefix = "${var.client}-${var.project}-${var.environment}"

  # ========================================================================
  # 2. TRANSFORMACIÓN DE API CONFIG
  # ========================================================================
  api_resources = {
    for key, config in var.api_config : key => {
      # Nombres (PC-IAC-003)
      name        = "${local.governance_prefix}-api-${key}"
      description = config.description

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

      # CORS global
      cors = config.cors

      # VPC Link
      vpc_link = config.vpc_link

      # Authorizers
      authorizers = config.authorizers

      # Routes
      routes = config.routes

      # API Keys
      api_keys = config.api_keys

      # Tags (PC-IAC-004)
      tags = merge(
        { Name = "${local.governance_prefix}-api-${key}" },
        config.additional_tags
      )
    }
  }

  # ========================================================================
  # 3. FLATTEN DE RUTAS PARA for_each (PC-IAC-012)
  # ========================================================================
  routes_flat = flatten([
    for api_key, api in local.api_resources : [
      for route_path, route in api.routes : {
        api_key            = api_key
        route_path         = route_path
        route_key          = "${api_key}:${replace(replace(replace(route_path, "/", "-"), "{", ""), "}", "")}"
        methods            = route.methods
        integration_type   = route.integration_type
        authorization      = route.authorization
        authorizer_key     = route.authorizer_key
        api_key_required   = route.api_key_required
        lambda_arn         = route.lambda_arn
        backend_url        = route.backend_url
        vpc_link_id        = route.vpc_link_id
        mock_status_code   = route.mock_status_code
        mock_response      = route.mock_response
        http_url           = route.http_url
        http_method        = route.http_method
        request_parameters = route.request_parameters
        cors_enabled       = route.cors_enabled
        cors_config        = api.cors
      }
    ]
  ])

  # Mapa de rutas para for_each
  routes_map = {
    for route in local.routes_flat : route.route_key => merge(route, {
      path_depth = length(split("/", trimprefix(route.route_path, "/"))) - 1
    })
  }

  # ========================================================================
  # 4. FLATTEN DE MÉTODOS (cada ruta puede tener múltiples métodos)
  # ========================================================================
  methods_flat = flatten([
    for route_key, route in local.routes_map : [
      for method in route.methods : {
        api_key                 = route.api_key
        route_key               = route_key
        route_path              = route.route_path
        method_key              = "${route_key}:${method}"
        http_method             = method
        integration_type        = route.integration_type
        authorization           = route.authorization
        authorizer_key          = route.authorizer_key
        api_key_required        = route.api_key_required
        lambda_arn              = route.lambda_arn
        backend_url             = route.backend_url
        vpc_link_id             = route.vpc_link_id
        mock_status_code        = route.mock_status_code
        mock_response           = route.mock_response
        http_url                = route.http_url
        http_method_integration = route.http_method
        request_parameters      = route.request_parameters
        # Calcular depth del path para lookup de recursos
        path_depth              = length(split("/", trimprefix(route.route_path, "/"))) - 1
      }
    ]
  ])

  # Mapa de métodos para for_each
  methods_map = {
    for method in local.methods_flat : method.method_key => method
  }

  # ========================================================================
  # 5. FLATTEN DE AUTHORIZERS
  # ========================================================================
  authorizers_flat = flatten([
    for api_key, api in local.api_resources : [
      for auth_key, auth in api.authorizers : {
        api_key                          = api_key
        auth_key                         = auth_key
        authorizer_key                   = "${api_key}:${auth_key}"
        name                             = "${local.governance_prefix}-authorizer-${auth_key}"
        type                             = auth.type
        provider_arns                    = auth.provider_arns
        authorizer_uri                   = auth.authorizer_uri
        authorizer_credentials           = auth.authorizer_credentials
        authorizer_result_ttl_in_seconds = auth.authorizer_result_ttl_in_seconds
        identity_source                  = auth.identity_source
        identity_validation_expression   = auth.identity_validation_expression
      }
    ]
  ])

  authorizers_map = {
    for auth in local.authorizers_flat : auth.authorizer_key => auth
  }

  # ========================================================================
  # 6. FLATTEN DE API KEYS Y USAGE PLANS
  # ========================================================================
  api_keys_flat = flatten([
    for api_key, api in local.api_resources : [
      for key_name, key_config in api.api_keys : {
        api_key      = api_key
        key_name     = key_name
        key_key      = "${api_key}:${key_name}"
        name         = "${local.governance_prefix}-apikey-${key_name}"
        description  = key_config.description
        enabled      = key_config.enabled
        rate_limit   = key_config.rate_limit
        burst_limit  = key_config.burst_limit
        quota_limit  = key_config.quota_limit
        quota_period = key_config.quota_period
      }
    ]
  ])

  api_keys_map = {
    for key in local.api_keys_flat : key.key_key => key
  }

  # ========================================================================
  # 7. VPC LINKS A CREAR
  # ========================================================================
  vpc_links_to_create = {
    for api_key, api in local.api_resources : api_key => {
      name       = api.vpc_link.name != "" ? api.vpc_link.name : "${local.governance_prefix}-vpclink-${api_key}"
      target_arn = api.vpc_link.target_arn
      tags       = api.tags
    } if api.vpc_link.create
  }

  # ========================================================================
  # 8. LAMBDAS QUE NECESITAN PERMISOS
  # ========================================================================
  lambda_permissions = {
    for method_key, method in local.methods_map : method_key => {
      api_key = method.api_key
      # Extraer nombre de función - soporta ambos formatos:
      # - ARN Lambda: arn:aws:lambda:region:account:function:name
      # - URI integración: arn:aws:apigateway:region:lambda:path/.../functions/arn:aws:lambda:.../invocations
      lambda_name = can(regex("function:([^:/]+)", method.lambda_arn)) ? regex("function:([^:/]+)", method.lambda_arn)[0] : ""
      lambda_arn = can(regex("^arn:aws:apigateway:", method.lambda_arn)) ? (
        # Extraer ARN de Lambda del URI de integración
        regex("functions/(arn:aws:lambda:[^/]+)/invocations", method.lambda_arn)[0]
      ) : method.lambda_arn
    } if method.integration_type == "LAMBDA" && method.lambda_arn != ""
  }

  # ========================================================================
  # 9. CORS OPTIONS METHODS (para rutas con CORS habilitado)
  # ========================================================================
  cors_options_methods = {
    for route_key, route in local.routes_map : route_key => route
    if route.cors_enabled || (route.cors_config != null && route.cors_config.enabled)
  }

  # ========================================================================
  # 10. RECURSOS DE PATH (extraer paths únicos)
  # ========================================================================
  # Extraer todos los segmentos de path necesarios
  path_segments = flatten([
    for route_key, route in local.routes_map : [
      for i, segment in split("/", trimprefix(route.route_path, "/")) : {
        api_key      = route.api_key
        full_path    = route.route_path
        segment      = segment
        depth        = i
        parent_path  = i == 0 ? "" : join("/", slice(split("/", trimprefix(route.route_path, "/")), 0, i))
        resource_key = "${route.api_key}:${join("/", slice(split("/", trimprefix(route.route_path, "/")), 0, i + 1))}"
      } if segment != ""
    ]
  ])

  # Mapa único de recursos de path
  path_resources_map = {
    for segment in local.path_segments : segment.resource_key => segment...
  }

  # Aplanar a un solo elemento por key
  path_resources = {
    for key, segments in local.path_resources_map : key => segments[0]
  }

  # ========================================================================
  # 11. SEPARAR PATHS POR NIVEL DE PROFUNDIDAD
  # ========================================================================
  path_resources_level_0 = {
    for key, res in local.path_resources : key => res if res.depth == 0
  }
  path_resources_level_1 = {
    for key, res in local.path_resources : key => res if res.depth == 1
  }
  path_resources_level_2 = {
    for key, res in local.path_resources : key => res if res.depth == 2
  }

  # ========================================================================
  # 12. HELPER: Depth de cada ruta para lookup de recursos
  # ========================================================================
  # (Ya incluido en routes_map y methods_map como path_depth)
}
