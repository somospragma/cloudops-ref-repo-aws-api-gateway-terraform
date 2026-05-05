############################################################################
# VPC Link (Opcional - modo simple con vpc_link.create = true)
############################################################################

resource "aws_api_gateway_vpc_link" "this" {
  provider = aws.project
  for_each = local.vpc_links_simple

  name        = each.value.simple_vpc_link_name
  description = "VPC Link for ${each.value.name}"
  target_arns = [each.value.simple_vpc_link_target]

  tags = each.value.tags
}

############################################################################
# API Gateway REST API
############################################################################

resource "aws_api_gateway_rest_api" "this" {
  provider = aws.project
  for_each = local.api_resources

  name        = each.value.name
  description = each.value.description
  body        = local.openapi_specs[each.key]

  endpoint_configuration {
    types            = [each.value.endpoint_type]
    vpc_endpoint_ids = each.value.endpoint_type == "PRIVATE" ? each.value.vpc_endpoint_ids : null
  }

  disable_execute_api_endpoint = each.value.disable_execute_api_endpoint
  minimum_compression_size     = each.value.minimum_compression_size >= 0 ? each.value.minimum_compression_size : null
  binary_media_types           = length(each.value.binary_media_types) > 0 ? each.value.binary_media_types : null

  tags = each.value.tags
}

############################################################################
# API Gateway Deployment
############################################################################

resource "aws_api_gateway_deployment" "this" {
  provider = aws.project
  for_each = local.api_resources

  rest_api_id = aws_api_gateway_rest_api.this[each.key].id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.this[each.key].body,
      each.value.mode == "SIMPLE" && each.value.simple_integration_type == "VPC_LINK" ? (
        each.value.simple_vpc_link_create ? aws_api_gateway_vpc_link.this[each.key].id : each.value.simple_vpc_link_id
      ) : ""
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_vpc_link.this]
}

############################################################################
# API Gateway Stage
############################################################################

resource "aws_api_gateway_stage" "this" {
  provider = aws.project
  for_each = local.api_resources

  deployment_id = aws_api_gateway_deployment.this[each.key].id
  rest_api_id   = aws_api_gateway_rest_api.this[each.key].id
  stage_name    = each.value.stage_name

  xray_tracing_enabled = each.value.xray_tracing_enabled

  # Stage variables para VPC Link (modo simple)
  variables = each.value.mode == "SIMPLE" && each.value.simple_integration_type == "VPC_LINK" ? {
    vpcLinkId = each.value.simple_vpc_link_create ? aws_api_gateway_vpc_link.this[each.key].id : each.value.simple_vpc_link_id
  } : {}

  dynamic "access_log_settings" {
    for_each = each.value.access_log_destination_arn != "" ? [1] : []
    content {
      destination_arn = each.value.access_log_destination_arn
      format          = each.value.access_log_format
    }
  }

  tags = each.value.tags

  depends_on = [aws_api_gateway_vpc_link.this]
}

############################################################################
# Lambda Permissions - Modo Simple
############################################################################

resource "aws_lambda_permission" "simple" {
  provider = aws.project
  for_each = local.lambda_permissions_simple

  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this[each.key].execution_arn}/*/*"
}

############################################################################
# Lambda Permissions - Modo Rutas
############################################################################

resource "aws_lambda_permission" "routes" {
  provider = aws.project
  for_each = local.lambda_permissions_routes

  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this[each.value.api_key].execution_arn}/*/*"
}

############################################################################
# Lambda Permissions - Authorizers
############################################################################

resource "aws_lambda_permission" "authorizer" {
  provider = aws.project
  for_each = local.authorizer_lambda_permissions

  statement_id  = "AllowAPIGatewayAuthorizer-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = regex("function:([^:/]+)", each.value.lambda_arn)[0]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this[each.key].execution_arn}/authorizers/*"
}

############################################################################
# Custom Domain Name (Opcional)
############################################################################

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

############################################################################
# Base Path Mapping (para Custom Domain)
############################################################################

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
