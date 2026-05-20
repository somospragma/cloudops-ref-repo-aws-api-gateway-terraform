# cloudops-ref-repo-aws-api-gateway-terraform

Módulo de Terraform para crear API Gateway REST APIs usando recursos nativos de Terraform (sin OpenAPI).

## Características Principales

- ✅ **Terraform Nativo**: Usa recursos individuales (`aws_api_gateway_method`, `aws_api_gateway_integration`) en lugar de OpenAPI body
- ✅ **API Key + Cognito**: Soporta combinación de `api_key_required = true` con `authorization = COGNITO_USER_POOLS` en el mismo endpoint
- ✅ **Integraciones**: LAMBDA, VPC_LINK, MOCK, HTTP
- ✅ **Autenticación**: NONE, COGNITO_USER_POOLS, CUSTOM (Lambda Authorizer), AWS_IAM
- ✅ **API Keys y Usage Plans**: Configuración completa de throttling y quotas
- ✅ **CORS**: Configurable por ruta
- ✅ **Custom Domain**: Con certificados ACM
- ✅ **VPC Link**: Crear nuevo o usar existente
- ✅ **Cumple PC-IAC**: Reglas 001-020 de Pragma CloudOps

## Uso Básico

### API con Lambda + API Key

```hcl
module "api" {
  source = "git::https://github.com/somospragma/cloudops-ref-repo-aws-api-gateway-terraform.git?ref=v2.0.0"

  providers = {
    aws.project = aws.principal
  }

  client      = "pragma"
  project     = "sopp"
  environment = "dev"

  api_config = {
    hub = {
      stage_name = "v1"
      
      routes = {
        "/health" = {
          methods          = ["GET"]
          integration_type = "LAMBDA"
          lambda_arn       = "arn:aws:lambda:us-east-1:123456789012:function:health-check"
          api_key_required = true
          authorization    = "NONE"
        }
      }

      api_keys = {
        main = {
          rate_limit  = 100
          burst_limit = 50
        }
      }
    }
  }
}
```

### API Key + Cognito (Caso Principal)

```hcl
api_config = {
  hub = {
    stage_name = "v1"
    
    # Definir authorizers
    authorizers = {
      cognito = {
        type          = "COGNITO_USER_POOLS"
        provider_arns = ["arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_ABC123"]
      }
    }
    
    routes = {
      # Solo API Key (sin Cognito)
      "/auth/login" = {
        methods          = ["GET"]
        integration_type = "LAMBDA"
        lambda_arn       = "arn:aws:lambda:...:function:auth"
        api_key_required = true
        authorization    = "NONE"
      }
      
      # API Key + Cognito (CLAVE: ambos funcionan juntos)
      "/accounts" = {
        methods          = ["GET"]
        integration_type = "LAMBDA"
        lambda_arn       = "arn:aws:lambda:...:function:accounts"
        api_key_required = true           # Requiere x-api-key header
        authorization    = "COGNITO_USER_POOLS"  # Requiere Authorization header
        authorizer_key   = "cognito"      # Referencia al authorizer
      }
      
      "/sync" = {
        methods          = ["POST"]
        integration_type = "LAMBDA"
        lambda_arn       = "arn:aws:lambda:...:function:sync"
        api_key_required = true
        authorization    = "COGNITO_USER_POOLS"
        authorizer_key   = "cognito"
      }
    }

    api_keys = {
      hub = {
        rate_limit   = 100
        burst_limit  = 50
        quota_limit  = 10000
        quota_period = "MONTH"
      }
    }
  }
}
```

### VPC Link

```hcl
api_config = {
  backend = {
    stage_name = "v1"
    
    routes = {
      "/api/{proxy+}" = {
        methods          = ["ANY"]
        integration_type = "VPC_LINK"
        backend_url      = "http://internal-nlb-xxx.elb.amazonaws.com/api/{proxy}"
        vpc_link_id      = "abc123"
        api_key_required = true
        request_parameters = {
          "method.request.path.proxy" = true
        }
      }
    }
  }
}
```

### Mock con CORS

```hcl
api_config = {
  mock = {
    stage_name = "v1"
    
    cors = {
      enabled         = true
      allowed_origins = ["https://example.com"]
    }
    
    routes = {
      "/health" = {
        methods          = ["GET"]
        integration_type = "MOCK"
        mock_status_code = 200
        mock_response    = "{\"status\":\"healthy\"}"
        cors_enabled     = true
      }
    }
  }
}
```

### Lambda Authorizer

```hcl
api_config = {
  secure = {
    stage_name = "v1"
    
    authorizers = {
      custom = {
        type           = "TOKEN"
        authorizer_uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:authorizer/invocations"
        authorizer_result_ttl_in_seconds = 300
      }
    }
    
    routes = {
      "/protected" = {
        methods          = ["GET"]
        integration_type = "LAMBDA"
        lambda_arn       = "arn:aws:lambda:...:function:protected"
        authorization    = "CUSTOM"
        authorizer_key   = "custom"
      }
    }
  }
}
```

## Variables

### Gobernanza (Obligatorias)

| Variable | Descripción | Tipo |
|----------|-------------|------|
| `client` | Nombre del cliente (máx 10 chars) | string |
| `project` | Nombre del proyecto (máx 15 chars) | string |
| `environment` | Ambiente: dev, qa, stg, pdn, prod | string |

### api_config

| Atributo | Descripción | Tipo | Default |
|----------|-------------|------|---------|
| `description` | Descripción de la API | string | "API Gateway REST API" |
| `endpoint_type` | REGIONAL, EDGE, PRIVATE | string | "REGIONAL" |
| `stage_name` | Nombre del stage | string | "v1" |
| `authorizers` | Mapa de authorizers (Cognito/Lambda) | map | {} |
| `routes` | Mapa de rutas con configuración | map | (requerido) |
| `api_keys` | Mapa de API Keys | map | {} |
| `cors` | Configuración CORS global | object | { enabled = false } |
| `custom_domain_name` | Dominio personalizado | string | "" |
| `certificate_arn` | ARN del certificado ACM | string | "" |

### routes (por ruta)

| Atributo | Descripción | Tipo | Default |
|----------|-------------|------|---------|
| `methods` | Métodos HTTP | list(string) | ["GET"] |
| `integration_type` | LAMBDA, VPC_LINK, MOCK, HTTP | string | (requerido) |
| `authorization` | NONE, COGNITO_USER_POOLS, CUSTOM, AWS_IAM | string | "NONE" |
| `authorizer_key` | Key del authorizer en el mapa | string | "" |
| `api_key_required` | Requiere API Key | bool | false |
| `lambda_arn` | ARN de Lambda (si LAMBDA) | string | "" |
| `backend_url` | URL backend (si VPC_LINK/HTTP) | string | "" |
| `vpc_link_id` | ID de VPC Link | string | "" |
| `cors_enabled` | Habilitar CORS para esta ruta | bool | false |

## Outputs

| Output | Descripción |
|--------|-------------|
| `rest_api_ids` | IDs de las REST APIs |
| `rest_api_arns` | ARNs de las REST APIs |
| `execution_arns` | Execution ARNs |
| `invoke_urls` | URLs de invocación |
| `api_key_ids` | IDs de las API Keys |
| `api_key_values` | Valores de las API Keys (sensitive) |
| `usage_plan_ids` | IDs de los Usage Plans |
| `authorizer_ids` | IDs de los Authorizers |
| `apis` | Mapa consolidado |

## Diferencia con OpenAPI

| Característica | OpenAPI Body | Terraform Nativo (este módulo) |
|----------------|--------------|-------------------------------|
| API Key + Cognito | ❌ No soportado | ✅ Soportado |
| Flexibilidad por ruta | Limitada | Total |
| Debugging | Difícil | Fácil (recursos individuales) |
| State management | Un solo recurso | Recursos granulares |

## Cumplimiento PC-IAC

- ✅ PC-IAC-001: Estructura de archivos
- ✅ PC-IAC-002: Variables con validaciones
- ✅ PC-IAC-003: Nomenclatura `{client}-{project}-{environment}-{type}-{key}`
- ✅ PC-IAC-004: Tags con merge
- ✅ PC-IAC-005: Provider alias `aws.project`
- ✅ PC-IAC-006: Versions en versions.tf
- ✅ PC-IAC-007: Outputs granulares con description
- ✅ PC-IAC-010: for_each obligatorio (no count)
- ✅ PC-IAC-012: Lógica centralizada en locals.tf
- ✅ PC-IAC-014: Dynamic blocks donde aplica

## Licencia

Copyright © Pragma S.A. Todos los derechos reservados.
