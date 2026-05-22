############################################################################
# API Gateway REST API - Terraform Nativo (PC-IAC-010: for_each obligatorio)
# Soporta hasta 5 niveles de profundidad en paths
############################################################################

# ========================================================================
# VPC LINK (Opcional)
# ========================================================================
resource "aws_api_gateway_vpc_link" "this" {
  provider = aws.project
  for_each = local.vpc_links_to_create

  name        = each.value.name
  description = "VPC Link for API Gateway"
  target_arns = [each.value.target_arn]

  tags = each.value.tags
}

# ========================================================================
# REST API
# ========================================================================
resource "aws_api_gateway_rest_api" "this" {
  provider = aws.project
  for_each = local.api_resources

  name        = each.value.name
  description = each.value.description

  endpoint_configuration {
    types            = [each.value.endpoint_type]
    vpc_endpoint_ids = each.value.endpoint_type == "PRIVATE" ? each.value.vpc_endpoint_ids : null
  }

  disable_execute_api_endpoint = each.value.disable_execute_api_endpoint
  minimum_compression_size     = each.value.minimum_compression_size >= 0 ? each.value.minimum_compression_size : null
  binary_media_types           = length(each.value.binary_media_types) > 0 ? each.value.binary_media_types : null

  tags = each.value.tags

  lifecycle {
    create_before_destroy = true
  }
}

# ========================================================================
# AUTHORIZERS (Cognito o Lambda)
# ========================================================================
resource "aws_api_gateway_authorizer" "this" {
  provider = aws.project
  for_each = local.authorizers_map

  name        = each.value.name
  rest_api_id = aws_api_gateway_rest_api.this[each.value.api_key].id
  type        = each.value.type

  # Para Cognito
  provider_arns = each.value.type == "COGNITO_USER_POOLS" ? each.value.provider_arns : null

  # Para Lambda Authorizer
  authorizer_uri                   = contains(["TOKEN", "REQUEST"], each.value.type) ? each.value.authorizer_uri : null
  authorizer_credentials           = each.value.authorizer_credentials != "" ? each.value.authorizer_credentials : null
  authorizer_result_ttl_in_seconds = each.value.authorizer_result_ttl_in_seconds
  identity_source                  = each.value.identity_source
  identity_validation_expression   = each.value.identity_validation_expression != "" ? each.value.identity_validation_expression : null
}

# ========================================================================
# API GATEWAY RESOURCES (Paths) - 5 Niveles de Profundidad
# ========================================================================

# Nivel 0: /resource (directamente bajo root)
resource "aws_api_gateway_resource" "level_0" {
  provider = aws.project
  for_each = { for key, res in local.path_resources : key => res if res.depth == 0 }

  rest_api_id = aws_api_gateway_rest_api.this[each.value.api_key].id
  parent_id   = aws_api_gateway_rest_api.this[each.value.api_key].root_resource_id
  path_part   = each.value.segment
}

# Nivel 1: /resource/child
resource "aws_api_gateway_resource" "level_1" {
  provider = aws.project
  for_each = { for key, res in local.path_resources : key => res if res.depth == 1 }

  rest_api_id = aws_api_gateway_rest_api.this[each.value.api_key].id
  parent_id   = aws_api_gateway_resource.level_0["${each.value.api_key}:${each.value.parent_path}"].id
  path_part   = each.value.segment

  depends_on = [aws_api_gateway_resource.level_0]
}

# Nivel 2: /resource/child/grandchild
resource "aws_api_gateway_resource" "level_2" {
  provider = aws.project
  for_each = { for key, res in local.path_resources : key => res if res.depth == 2 }

  rest_api_id = aws_api_gateway_rest_api.this[each.value.api_key].id
  parent_id   = aws_api_gateway_resource.level_1["${each.value.api_key}:${each.value.parent_path}"].id
  path_part   = each.value.segment

  depends_on = [aws_api_gateway_resource.level_1]
}

# Nivel 3: /resource/child/grandchild/great
resource "aws_api_gateway_resource" "level_3" {
  provider = aws.project
  for_each = { for key, res in local.path_resources : key => res if res.depth == 3 }

  rest_api_id = aws_api_gateway_rest_api.this[each.value.api_key].id
  parent_id   = aws_api_gateway_resource.level_2["${each.value.api_key}:${each.value.parent_path}"].id
  path_part   = each.value.segment

  depends_on = [aws_api_gateway_resource.level_2]
}

# Nivel 4: /resource/child/grandchild/great/greatest
resource "aws_api_gateway_resource" "level_4" {
  provider = aws.project
  for_each = { for key, res in local.path_resources : key => res if res.depth == 4 }

  rest_api_id = aws_api_gateway_rest_api.this[each.value.api_key].id
  parent_id   = aws_api_gateway_resource.level_3["${each.value.api_key}:${each.value.parent_path}"].id
  path_part   = each.value.segment

  depends_on = [aws_api_gateway_resource.level_3]
}

# ========================================================================
# API GATEWAY METHODS
# ========================================================================
resource "aws_api_gateway_method" "this" {
  provider = aws.project
  for_each = local.methods_map

  rest_api_id = aws_api_gateway_rest_api.this[each.value.api_key].id
  resource_id = (
    each.value.path_depth == 0 ? aws_api_gateway_resource.level_0["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 1 ? aws_api_gateway_resource.level_1["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 2 ? aws_api_gateway_resource.level_2["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 3 ? aws_api_gateway_resource.level_3["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    aws_api_gateway_resource.level_4["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id
  )
  http_method = each.value.http_method

  authorization = each.value.authorization
  authorizer_id = each.value.authorization != "NONE" && each.value.authorizer_key != "" ? (
    aws_api_gateway_authorizer.this["${each.value.api_key}:${each.value.authorizer_key}"].id
  ) : null
  api_key_required = each.value.api_key_required

  request_parameters = length(each.value.request_parameters) > 0 ? each.value.request_parameters : null

  depends_on = [
    aws_api_gateway_resource.level_0,
    aws_api_gateway_resource.level_1,
    aws_api_gateway_resource.level_2,
    aws_api_gateway_resource.level_3,
    aws_api_gateway_resource.level_4,
  ]
}

# ========================================================================
# API GATEWAY INTEGRATIONS
# ========================================================================
resource "aws_api_gateway_integration" "this" {
  provider = aws.project
  for_each = local.methods_map

  rest_api_id = aws_api_gateway_rest_api.this[each.value.api_key].id
  resource_id = (
    each.value.path_depth == 0 ? aws_api_gateway_resource.level_0["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 1 ? aws_api_gateway_resource.level_1["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 2 ? aws_api_gateway_resource.level_2["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 3 ? aws_api_gateway_resource.level_3["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    aws_api_gateway_resource.level_4["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id
  )
  http_method = aws_api_gateway_method.this[each.key].http_method

  type = each.value.integration_type == "LAMBDA" ? "AWS_PROXY" : (
    each.value.integration_type == "VPC_LINK" ? "HTTP_PROXY" : (
      each.value.integration_type == "HTTP" ? "HTTP_PROXY" : "MOCK"
    )
  )

  integration_http_method = each.value.integration_type == "LAMBDA" ? "POST" : (
    each.value.integration_type == "MOCK" ? null : each.value.http_method_integration
  )
  uri = each.value.integration_type == "LAMBDA" ? (
    can(regex("^arn:aws:apigateway:", each.value.lambda_arn)) ? each.value.lambda_arn : (
      "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${each.value.lambda_arn}/invocations"
    )
  ) : (
    each.value.integration_type == "VPC_LINK" ? each.value.backend_url : (
      each.value.integration_type == "HTTP" ? each.value.http_url : null
    )
  )

  connection_type = each.value.integration_type == "VPC_LINK" ? "VPC_LINK" : null
  connection_id   = each.value.integration_type == "VPC_LINK" ? each.value.vpc_link_id : null

  request_templates = each.value.integration_type == "MOCK" ? {
    "application/json" = "{\"statusCode\": ${each.value.mock_status_code}}"
  } : null

  timeout_milliseconds = 29000

  depends_on = [aws_api_gateway_method.this]
}

# ========================================================================
# MOCK INTEGRATION RESPONSE
# ========================================================================
resource "aws_api_gateway_method_response" "mock" {
  provider = aws.project
  for_each = { for key, method in local.methods_map : key => method if method.integration_type == "MOCK" }

  rest_api_id = aws_api_gateway_rest_api.this[each.value.api_key].id
  resource_id = (
    each.value.path_depth == 0 ? aws_api_gateway_resource.level_0["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 1 ? aws_api_gateway_resource.level_1["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 2 ? aws_api_gateway_resource.level_2["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 3 ? aws_api_gateway_resource.level_3["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    aws_api_gateway_resource.level_4["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id
  )
  http_method = aws_api_gateway_method.this[each.key].http_method
  status_code = tostring(each.value.mock_status_code)

  depends_on = [aws_api_gateway_method.this]
}

resource "aws_api_gateway_integration_response" "mock" {
  provider = aws.project
  for_each = { for key, method in local.methods_map : key => method if method.integration_type == "MOCK" }

  rest_api_id = aws_api_gateway_rest_api.this[each.value.api_key].id
  resource_id = (
    each.value.path_depth == 0 ? aws_api_gateway_resource.level_0["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 1 ? aws_api_gateway_resource.level_1["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 2 ? aws_api_gateway_resource.level_2["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 3 ? aws_api_gateway_resource.level_3["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    aws_api_gateway_resource.level_4["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id
  )
  http_method = aws_api_gateway_method.this[each.key].http_method
  status_code = aws_api_gateway_method_response.mock[each.key].status_code

  response_templates = {
    "application/json" = each.value.mock_response
  }

  depends_on = [aws_api_gateway_integration.this]
}

# ========================================================================
# CORS OPTIONS METHODS
# ========================================================================
resource "aws_api_gateway_method" "cors" {
  provider = aws.project
  for_each = local.cors_options_methods

  rest_api_id = aws_api_gateway_rest_api.this[each.value.api_key].id
  resource_id = (
    each.value.path_depth == 0 ? aws_api_gateway_resource.level_0["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 1 ? aws_api_gateway_resource.level_1["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 2 ? aws_api_gateway_resource.level_2["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 3 ? aws_api_gateway_resource.level_3["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    aws_api_gateway_resource.level_4["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id
  )
  http_method   = "OPTIONS"
  authorization = "NONE"

  depends_on = [
    aws_api_gateway_resource.level_0,
    aws_api_gateway_resource.level_1,
    aws_api_gateway_resource.level_2,
    aws_api_gateway_resource.level_3,
    aws_api_gateway_resource.level_4,
  ]
}

resource "aws_api_gateway_integration" "cors" {
  provider = aws.project
  for_each = local.cors_options_methods

  rest_api_id = aws_api_gateway_rest_api.this[each.value.api_key].id
  resource_id = (
    each.value.path_depth == 0 ? aws_api_gateway_resource.level_0["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 1 ? aws_api_gateway_resource.level_1["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 2 ? aws_api_gateway_resource.level_2["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 3 ? aws_api_gateway_resource.level_3["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    aws_api_gateway_resource.level_4["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id
  )
  http_method = aws_api_gateway_method.cors[each.key].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }

  depends_on = [aws_api_gateway_method.cors]
}

resource "aws_api_gateway_method_response" "cors" {
  provider = aws.project
  for_each = local.cors_options_methods

  rest_api_id = aws_api_gateway_rest_api.this[each.value.api_key].id
  resource_id = (
    each.value.path_depth == 0 ? aws_api_gateway_resource.level_0["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 1 ? aws_api_gateway_resource.level_1["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 2 ? aws_api_gateway_resource.level_2["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 3 ? aws_api_gateway_resource.level_3["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    aws_api_gateway_resource.level_4["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id
  )
  http_method = aws_api_gateway_method.cors[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Max-Age"       = true
  }

  depends_on = [aws_api_gateway_method.cors]
}

resource "aws_api_gateway_integration_response" "cors" {
  provider = aws.project
  for_each = local.cors_options_methods

  rest_api_id = aws_api_gateway_rest_api.this[each.value.api_key].id
  resource_id = (
    each.value.path_depth == 0 ? aws_api_gateway_resource.level_0["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 1 ? aws_api_gateway_resource.level_1["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 2 ? aws_api_gateway_resource.level_2["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    each.value.path_depth == 3 ? aws_api_gateway_resource.level_3["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id :
    aws_api_gateway_resource.level_4["${each.value.api_key}:${trimprefix(each.value.route_path, "/")}"].id
  )
  http_method = aws_api_gateway_method.cors[each.key].http_method
  status_code = aws_api_gateway_method_response.cors[each.key].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'${join(",", each.value.cors_config.allowed_headers)}'"
    "method.response.header.Access-Control-Allow-Methods" = "'${join(",", each.value.cors_config.allowed_methods)}'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${join(",", each.value.cors_config.allowed_origins)}'"
    "method.response.header.Access-Control-Max-Age"       = "'${each.value.cors_config.max_age}'"
  }

  depends_on = [aws_api_gateway_integration.cors]
}

# ========================================================================
# DEPLOYMENT
# ========================================================================
resource "aws_api_gateway_deployment" "this" {
  provider = aws.project
  for_each = local.api_resources

  rest_api_id = aws_api_gateway_rest_api.this[each.key].id

  triggers = {
    redeployment = sha1(jsonencode([
      [for k, v in aws_api_gateway_resource.level_0 : v.id if startswith(k, "${each.key}:")],
      [for k, v in aws_api_gateway_resource.level_1 : v.id if startswith(k, "${each.key}:")],
      [for k, v in aws_api_gateway_resource.level_2 : v.id if startswith(k, "${each.key}:")],
      [for k, v in aws_api_gateway_resource.level_3 : v.id if startswith(k, "${each.key}:")],
      [for k, v in aws_api_gateway_resource.level_4 : v.id if startswith(k, "${each.key}:")],
      [for k, v in aws_api_gateway_method.this : v.id if startswith(k, "${each.key}:")],
      [for k, v in aws_api_gateway_integration.this : v.id if startswith(k, "${each.key}:")],
      [for k, v in aws_api_gateway_authorizer.this : v.id if startswith(k, "${each.key}:")],
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.this,
    aws_api_gateway_integration_response.mock,
    aws_api_gateway_integration_response.cors,
  ]
}

# ========================================================================
# STAGE
# ========================================================================
resource "aws_api_gateway_stage" "this" {
  provider = aws.project
  for_each = local.api_resources

  deployment_id = aws_api_gateway_deployment.this[each.key].id
  rest_api_id   = aws_api_gateway_rest_api.this[each.key].id
  stage_name    = each.value.stage_name

  xray_tracing_enabled = each.value.xray_tracing_enabled

  dynamic "access_log_settings" {
    for_each = each.value.access_log_destination_arn != "" ? [1] : []
    content {
      destination_arn = each.value.access_log_destination_arn
      format          = each.value.access_log_format
    }
  }

  tags = each.value.tags
}

# ========================================================================
# API KEYS
# ========================================================================
resource "aws_api_gateway_api_key" "this" {
  provider = aws.project
  for_each = local.api_keys_map

  name        = each.value.name
  description = each.value.description
  enabled     = each.value.enabled

  tags = local.api_resources[each.value.api_key].tags
}

# ========================================================================
# USAGE PLANS
# ========================================================================
resource "aws_api_gateway_usage_plan" "this" {
  provider = aws.project
  for_each = local.api_keys_map

  name = "${local.governance_prefix}-usageplan-${each.value.key_name}"

  api_stages {
    api_id = aws_api_gateway_rest_api.this[each.value.api_key].id
    stage  = aws_api_gateway_stage.this[each.value.api_key].stage_name
  }

  throttle_settings {
    rate_limit  = each.value.rate_limit
    burst_limit = each.value.burst_limit
  }

  quota_settings {
    limit  = each.value.quota_limit
    period = each.value.quota_period
  }

  tags = local.api_resources[each.value.api_key].tags

  depends_on = [aws_api_gateway_stage.this]
}

# ========================================================================
# USAGE PLAN KEY
# ========================================================================
resource "aws_api_gateway_usage_plan_key" "this" {
  provider = aws.project
  for_each = local.api_keys_map

  key_id        = aws_api_gateway_api_key.this[each.key].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.this[each.key].id
}

# ========================================================================
# NOTA: Los permisos Lambda se gestionan con el módulo separado
# cloudops-ref-repo-aws-lambda-permission-terraform
# Esto evita el error "for_each map includes keys derived from resource attributes"
# ========================================================================

# ========================================================================
# CUSTOM DOMAIN NAME (Opcional)
# ========================================================================
resource "aws_api_gateway_domain_name" "this" {
  provider = aws.project
  for_each = {
    for key, api in local.api_resources : key => api
    if api.custom_domain_name != "" && api.certificate_arn != ""
  }

  domain_name              = each.value.custom_domain_name
  regional_certificate_arn = each.value.endpoint_type == "REGIONAL" ? each.value.certificate_arn : null
  certificate_arn          = each.value.endpoint_type == "EDGE" ? each.value.certificate_arn : null

  endpoint_configuration {
    types = [each.value.endpoint_type]
  }

  tags = each.value.tags
}

# ========================================================================
# BASE PATH MAPPING
# ========================================================================
resource "aws_api_gateway_base_path_mapping" "this" {
  provider = aws.project
  for_each = {
    for key, api in local.api_resources : key => api
    if api.custom_domain_name != "" && api.certificate_arn != ""
  }

  api_id      = aws_api_gateway_rest_api.this[each.key].id
  stage_name  = aws_api_gateway_stage.this[each.key].stage_name
  domain_name = aws_api_gateway_domain_name.this[each.key].domain_name
  base_path   = each.value.base_path != "" ? each.value.base_path : null
}
