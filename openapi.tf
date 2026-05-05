############################################################################
# OpenAPI Spec Generation - Simplificado
############################################################################

locals {
  # CORS OPTIONS response headers
  cors_response_params = {
    for key, api in local.api_resources : key => {
      "method.response.header.Access-Control-Allow-Headers" = "'${api.cors_allowed_headers}'"
      "method.response.header.Access-Control-Allow-Methods" = "'${api.cors_allowed_methods}'"
      "method.response.header.Access-Control-Allow-Origin"  = "'${api.cors_allowed_origins}'"
      "method.response.header.Access-Control-Max-Age"       = "'${api.cors_max_age}'"
    }
  }

  # Generar OpenAPI spec para MODO SIMPLE
  openapi_simple = {
    for key, api in local.api_resources : key => {
      openapi = "3.0.1"
      info = {
        title   = api.name
        version = "1.0"
      }
      components = api.auth_type != "NONE" ? {
        securitySchemes = (
          api.auth_type == "API_KEY" ? {
            api_key = {
              type = "apiKey"
              name = "x-api-key"
              in   = "header"
            }
            } : api.auth_type == "IAM" ? {
            sigv4 = {
              type                           = "apiKey"
              name                           = "Authorization"
              in                             = "header"
              "x-amazon-apigateway-authtype" = "awsSigv4"
            }
            } : api.auth_type == "COGNITO" ? {
            cognito = {
              type                           = "apiKey"
              name                           = "Authorization"
              in                             = "header"
              "x-amazon-apigateway-authtype" = "cognito_user_pools"
              "x-amazon-apigateway-authorizer" = {
                type         = "cognito_user_pools"
                providerARNs = api.auth_cognito_arns
              }
            }
            } : api.auth_type == "LAMBDA_TOKEN" ? {
            lambda_auth = {
              type                           = "apiKey"
              name                           = "Authorization"
              in                             = "header"
              "x-amazon-apigateway-authtype" = "custom"
              "x-amazon-apigateway-authorizer" = {
                type                         = "token"
                authorizerUri                = api.auth_authorizer_uri
                authorizerResultTtlInSeconds = api.auth_authorizer_ttl
              }
            }
            } : api.auth_type == "LAMBDA_REQUEST" ? {
            lambda_auth = {
              type                           = "apiKey"
              name                           = "Unused"
              in                             = "header"
              "x-amazon-apigateway-authtype" = "custom"
              "x-amazon-apigateway-authorizer" = {
                type                         = "request"
                authorizerUri                = api.auth_authorizer_uri
                authorizerResultTtlInSeconds = api.auth_authorizer_ttl
                identitySource               = api.auth_identity_source
              }
            }
          } : {}
        )
      } : {}
      paths = {
        "/" = merge(
          api.cors_enabled ? {
            options = {
              responses = {
                "200" = {
                  description = "CORS preflight"
                  headers = {
                    "Access-Control-Allow-Origin"  = { schema = { type = "string" } }
                    "Access-Control-Allow-Methods" = { schema = { type = "string" } }
                    "Access-Control-Allow-Headers" = { schema = { type = "string" } }
                    "Access-Control-Max-Age"       = { schema = { type = "string" } }
                  }
                }
              }
              "x-amazon-apigateway-integration" = {
                type             = "mock"
                requestTemplates = { "application/json" = "{\"statusCode\": 200}" }
                responses = {
                  default = {
                    statusCode         = "200"
                    responseParameters = local.cors_response_params[key]
                    responseTemplates  = { "application/json" = "" }
                  }
                }
              }
            }
          } : {},
          {
            "x-amazon-apigateway-any-method" = merge(
              {
                responses = { "200" = { description = "Success" } }
                "x-amazon-apigateway-integration" = (
                  api.simple_integration_type == "LAMBDA" ? {
                    httpMethod          = "POST"
                    type                = "aws_proxy"
                    uri                 = "arn:aws:apigateway:${data.aws_region.current.id}:lambda:path/2015-03-31/functions/${api.simple_lambda_arn}/invocations"
                    passthroughBehavior = "when_no_match"
                    timeoutInMillis     = 29000
                    } : api.simple_integration_type == "VPC_LINK" ? {
                    httpMethod          = "ANY"
                    type                = "http_proxy"
                    uri                 = "${api.simple_backend_url}/"
                    connectionType      = "VPC_LINK"
                    connectionId        = "$${stageVariables.vpcLinkId}"
                    passthroughBehavior = "when_no_match"
                    timeoutInMillis     = 29000
                  } : {}
                )
              },
              api.auth_type == "API_KEY" ? { security = [{ api_key = [] }] } :
              api.auth_type == "IAM" ? { security = [{ sigv4 = [] }] } :
              api.auth_type == "COGNITO" ? { security = [{ cognito = [] }] } :
              contains(["LAMBDA_TOKEN", "LAMBDA_REQUEST"], api.auth_type) ? { security = [{ lambda_auth = [] }] } :
              {}
            )
          }
        )
        "/{proxy+}" = merge(
          api.cors_enabled ? {
            options = {
              parameters = [{ name = "proxy", in = "path", required = true, schema = { type = "string" } }]
              responses = {
                "200" = {
                  description = "CORS preflight"
                  headers = {
                    "Access-Control-Allow-Origin"  = { schema = { type = "string" } }
                    "Access-Control-Allow-Methods" = { schema = { type = "string" } }
                    "Access-Control-Allow-Headers" = { schema = { type = "string" } }
                    "Access-Control-Max-Age"       = { schema = { type = "string" } }
                  }
                }
              }
              "x-amazon-apigateway-integration" = {
                type             = "mock"
                requestTemplates = { "application/json" = "{\"statusCode\": 200}" }
                responses = {
                  default = {
                    statusCode         = "200"
                    responseParameters = local.cors_response_params[key]
                    responseTemplates  = { "application/json" = "" }
                  }
                }
              }
            }
          } : {},
          {
            "x-amazon-apigateway-any-method" = merge(
              {
                parameters = [{ name = "proxy", in = "path", required = true, schema = { type = "string" } }]
                responses  = { "200" = { description = "Success" } }
                "x-amazon-apigateway-integration" = (
                  api.simple_integration_type == "LAMBDA" ? {
                    httpMethod          = "POST"
                    type                = "aws_proxy"
                    uri                 = "arn:aws:apigateway:${data.aws_region.current.id}:lambda:path/2015-03-31/functions/${api.simple_lambda_arn}/invocations"
                    passthroughBehavior = "when_no_match"
                    timeoutInMillis     = 29000
                    } : api.simple_integration_type == "VPC_LINK" ? {
                    httpMethod          = "ANY"
                    type                = "http_proxy"
                    uri                 = "${api.simple_backend_url}/{proxy}"
                    connectionType      = "VPC_LINK"
                    connectionId        = "$${stageVariables.vpcLinkId}"
                    passthroughBehavior = "when_no_match"
                    timeoutInMillis     = 29000
                    requestParameters   = { "integration.request.path.proxy" = "method.request.path.proxy" }
                  } : {}
                )
              },
              api.auth_type == "API_KEY" ? { security = [{ api_key = [] }] } :
              api.auth_type == "IAM" ? { security = [{ sigv4 = [] }] } :
              api.auth_type == "COGNITO" ? { security = [{ cognito = [] }] } :
              contains(["LAMBDA_TOKEN", "LAMBDA_REQUEST"], api.auth_type) ? { security = [{ lambda_auth = [] }] } :
              {}
            )
          }
        )
      }
    } if api.mode == "SIMPLE"
  }

  # Generar OpenAPI spec para MODO RUTAS
  openapi_routes = {
    for key, api in local.api_resources : key => {
      openapi = "3.0.1"
      info = {
        title   = api.name
        version = "1.0"
      }
      components = api.auth_type != "NONE" ? {
        securitySchemes = (
          api.auth_type == "API_KEY" ? {
            api_key = { type = "apiKey", name = "x-api-key", in = "header" }
            } : api.auth_type == "IAM" ? {
            sigv4 = { type = "apiKey", name = "Authorization", in = "header", "x-amazon-apigateway-authtype" = "awsSigv4" }
            } : api.auth_type == "COGNITO" ? {
            cognito = {
              type                             = "apiKey"
              name                             = "Authorization"
              in                               = "header"
              "x-amazon-apigateway-authtype"   = "cognito_user_pools"
              "x-amazon-apigateway-authorizer" = { type = "cognito_user_pools", providerARNs = api.auth_cognito_arns }
            }
            } : contains(["LAMBDA_TOKEN", "LAMBDA_REQUEST"], api.auth_type) ? {
            lambda_auth = {
              type                           = "apiKey"
              name                           = api.auth_type == "LAMBDA_TOKEN" ? "Authorization" : "Unused"
              in                             = "header"
              "x-amazon-apigateway-authtype" = "custom"
              "x-amazon-apigateway-authorizer" = {
                type                         = api.auth_type == "LAMBDA_TOKEN" ? "token" : "request"
                authorizerUri                = api.auth_authorizer_uri
                authorizerResultTtlInSeconds = api.auth_authorizer_ttl
                identitySource               = api.auth_type == "LAMBDA_REQUEST" ? api.auth_identity_source : null
              }
            }
          } : {}
        )
      } : {}
      paths = {
        for route_path, route in api.routes : route_path => merge(
          # CORS OPTIONS
          api.cors_enabled ? {
            options = {
              responses = {
                "200" = {
                  description = "CORS"
                  headers = {
                    "Access-Control-Allow-Origin"  = { schema = { type = "string" } }
                    "Access-Control-Allow-Methods" = { schema = { type = "string" } }
                    "Access-Control-Allow-Headers" = { schema = { type = "string" } }
                    "Access-Control-Max-Age"       = { schema = { type = "string" } }
                  }
                }
              }
              "x-amazon-apigateway-integration" = {
                type             = "mock"
                requestTemplates = { "application/json" = "{\"statusCode\": 200}" }
                responses = {
                  default = {
                    statusCode         = "200"
                    responseParameters = local.cors_response_params[key]
                    responseTemplates  = { "application/json" = "" }
                  }
                }
              }
            }
          } : {},
          # Métodos de la ruta
          {
            for method in route.methods : (lower(method) == "any" ? "x-amazon-apigateway-any-method" : lower(method)) => merge(
              {
                responses = { "200" = { description = "Success" } }
                "x-amazon-apigateway-integration" = (
                  route.type == "LAMBDA" ? {
                    httpMethod          = "POST"
                    type                = "aws_proxy"
                    uri                 = "arn:aws:apigateway:${data.aws_region.current.id}:lambda:path/2015-03-31/functions/${route.lambda_arn}/invocations"
                    passthroughBehavior = "when_no_match"
                    timeoutInMillis     = 29000
                    } : route.type == "VPC_LINK" ? {
                    httpMethod          = "ANY"
                    type                = "http_proxy"
                    uri                 = route.backend_url
                    connectionType      = "VPC_LINK"
                    connectionId        = route.vpc_link_id
                    passthroughBehavior = "when_no_match"
                    timeoutInMillis     = 29000
                    } : route.type == "MOCK" ? {
                    type             = "mock"
                    requestTemplates = { "application/json" = "{\"statusCode\": ${route.mock_response != null ? route.mock_response.status_code : 200}}" }
                    responses = {
                      default = {
                        statusCode        = tostring(route.mock_response != null ? route.mock_response.status_code : 200)
                        responseTemplates = { "application/json" = route.mock_response != null ? route.mock_response.body : "{\"status\":\"ok\"}" }
                      }
                    }
                    } : route.type == "HTTP" ? {
                    httpMethod          = "ANY"
                    type                = "http_proxy"
                    uri                 = route.http_url
                    passthroughBehavior = "when_no_match"
                    timeoutInMillis     = 29000
                  } : {}
                )
              },
              # Security: usar override de ruta si existe, sino heredar de API
              (route.auth != null && route.auth.type != "") ? (
                route.auth.type == "NONE" ? {} :
                route.auth.type == "API_KEY" ? { security = [{ api_key = [] }] } :
                route.auth.type == "IAM" ? { security = [{ sigv4 = [] }] } :
                route.auth.type == "COGNITO" ? { security = [{ cognito = [] }] } :
                { security = [{ lambda_auth = [] }] }
                ) : (
                api.auth_type == "NONE" ? {} :
                api.auth_type == "API_KEY" ? { security = [{ api_key = [] }] } :
                api.auth_type == "IAM" ? { security = [{ sigv4 = [] }] } :
                api.auth_type == "COGNITO" ? { security = [{ cognito = [] }] } :
                { security = [{ lambda_auth = [] }] }
              )
            )
          }
        )
      }
    } if api.mode == "ROUTES"
  }

  # Combinar specs
  openapi_specs = {
    for key, api in local.api_resources : key => jsonencode(
      api.mode == "SIMPLE" ? local.openapi_simple[key] : local.openapi_routes[key]
    )
  }
}
