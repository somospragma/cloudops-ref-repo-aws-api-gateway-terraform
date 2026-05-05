# cloudops-ref-repo-aws-api-terraform-v2

Módulo de Terraform para crear API Gateway REST APIs con soporte completo para múltiples integraciones, autenticación y CORS.

## Características

- ✅ **Modo Simple**: Una integración (Lambda o VPC Link) para toda la API
- ✅ **Modo Rutas**: Múltiples rutas con diferentes integraciones
- ✅ **Integraciones**: LAMBDA, VPC_LINK, MOCK, HTTP
- ✅ **Autenticación**: NONE, API_KEY, IAM, COGNITO, LAMBDA_TOKEN, LAMBDA_REQUEST
- ✅ **CORS**: Configurable por API
- ✅ **Custom Domain**: Con certificados ACM
- ✅ **VPC Link**: Crear nuevo o usar existente
- ✅ **Redeployment automático**: Detecta cambios en configuración

## Uso

### Modo Simple - Lambda Proxy

```hcl
module "api" {
  source = "git::https://github.com/somospragma/cloudops-ref-repo-aws-api-terraform-v2.git?ref=v1.0.0"

  providers = {
    aws.project = aws.main
  }

  client      = "pragma"
  project     = "myproject"
  environment = "dev"

  api_config = {
    main = {
      integration_type = "LAMBDA"
      lambda_arn       = "arn:aws:lambda:us-east-1:123456789012:function:my-lambda"
      stage_name       = "dev"
      cors             = { enabled = true }
    }
  }
}
```

### Modo Simple - VPC Link

```hcl
api_config = {
  backend = {
    integration_type = "VPC_LINK"
    backend_url      = "http://internal-nlb-xxx.elb.amazonaws.com"
    vpc_link_id      = "abc123"  # VPC Link existente
    stage_name       = "dev"
  }
}
```

### Modo Simple - VPC Link (crear nuevo)

```hcl
api_config = {
  backend = {
    integration_type = "VPC_LINK"
    backend_url      = "http://internal-nlb-xxx.elb.amazonaws.com"
    vpc_link = {
      create     = true
      target_arn = "arn:aws:elasticloadbalancing:...:loadbalancer/net/my-nlb/..."
    }
    stage_name = "dev"
  }
}
```

### Modo Rutas - Múltiples Integraciones

```hcl
api_config = {
  multi = {
    stage_name = "dev"
    cors       = { enabled = true }
    
    # Auth por defecto para todas las rutas
    auth = { type = "API_KEY" }
    
    routes = {
      # Lambda para usuarios
      "/users/{proxy+}" = {
        methods    = ["GET", "POST", "PUT", "DELETE"]
        type       = "LAMBDA"
        lambda_arn = "arn:aws:lambda:...:function:users-api"
      }
      
      # VPC Link para órdenes
      "/orders/{proxy+}" = {
        methods     = ["GET", "POST"]
        type        = "VPC_LINK"
        backend_url = "http://internal-nlb.../orders"
        vpc_link_id = "abc123"
      }
      
      # Mock para health (sin auth)
      "/health" = {
        methods = ["GET"]
        type    = "MOCK"
        mock_response = {
          status_code = 200
          body        = "{\"status\":\"healthy\"}"
        }
        auth = { type = "NONE" }  # Override
      }
      
      # HTTP externo
      "/external/{proxy+}" = {
        methods  = ["GET"]
        type     = "HTTP"
        http_url = "https://api.external.com"
      }
    }
  }
}
```

### Autenticación Cognito

```hcl
api_config = {
  secure = {
    integration_type = "LAMBDA"
    lambda_arn       = "arn:aws:lambda:...:function:my-api"
    auth = {
      type                   = "COGNITO"
      cognito_user_pool_arns = ["arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_ABC123"]
    }
  }
}
```

### Autenticación Lambda Authorizer

```hcl
api_config = {
  custom-auth = {
    integration_type = "LAMBDA"
    lambda_arn       = "arn:aws:lambda:...:function:my-api"
    auth = {
      type             = "LAMBDA_TOKEN"  # o LAMBDA_REQUEST
      authorizer_uri   = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:my-authorizer/invocations"
      authorizer_result_ttl = 300
    }
  }
}
```

### Custom Domain

```hcl
api_config = {
  main = {
    integration_type   = "LAMBDA"
    lambda_arn         = "arn:aws:lambda:...:function:my-api"
    custom_domain_name = "api.example.com"
    certificate_arn    = "arn:aws:acm:us-east-1:123456789012:certificate/..."
    base_path          = "v1"
  }
}
```

## Variables

### Gobernanza

| Variable | Descripción | Tipo | Requerido |
|----------|-------------|------|-----------|
| client | Nombre del cliente | string | Sí |
| project | Nombre del proyecto | string | Sí |
| environment | Ambiente (dev, qa, stg, pdn, prod) | string | Sí |

### api_config

| Atributo | Descripción | Tipo | Default |
|----------|-------------|------|---------|
| description | Descripción de la API | string | "API Gateway REST API" |
| endpoint_type | REGIONAL, EDGE, PRIVATE | string | "REGIONAL" |
| stage_name | Nombre del stage | string | "v1" |
| integration_type | LAMBDA o VPC_LINK (modo simple) | string | "" |
| lambda_arn | ARN de Lambda (modo simple) | string | "" |
| backend_url | URL del backend (VPC_LINK) | string | "" |
| vpc_link_id | ID de VPC Link existente | string | "" |
| vpc_link.create | Crear nuevo VPC Link | bool | false |
| vpc_link.target_arn | ARN del NLB | string | "" |
| routes | Mapa de rutas (modo rutas) | map | {} |
| auth.type | NONE, API_KEY, IAM, COGNITO, LAMBDA_TOKEN, LAMBDA_REQUEST | string | "NONE" |
| cors.enabled | Habilitar CORS | bool | false |
| custom_domain_name | Dominio personalizado | string | "" |
| certificate_arn | ARN del certificado ACM | string | "" |

## Outputs

| Output | Descripción |
|--------|-------------|
| rest_api_ids | IDs de las REST APIs |
| rest_api_arns | ARNs de las REST APIs |
| execution_arns | Execution ARNs |
| invoke_urls | URLs de invocación |
| stage_arns | ARNs de los stages |
| vpc_link_ids | IDs de VPC Links creados |
| custom_domain_names | Información de dominios personalizados |
| apis | Mapa consolidado |

## Tipos de Autenticación

| Tipo | Descripción |
|------|-------------|
| NONE | Sin autenticación |
| API_KEY | Requiere header x-api-key |
| IAM | AWS IAM Signature v4 |
| COGNITO | Amazon Cognito User Pool |
| LAMBDA_TOKEN | Lambda Authorizer (token en header) |
| LAMBDA_REQUEST | Lambda Authorizer (request parameters) |

## Tipos de Integración (Modo Rutas)

| Tipo | Descripción |
|------|-------------|
| LAMBDA | Lambda Proxy Integration |
| VPC_LINK | HTTP Proxy via VPC Link |
| MOCK | Mock Integration |
| HTTP | HTTP Proxy directo |

## Licencia

Copyright © Pragma S.A. Todos los derechos reservados.
