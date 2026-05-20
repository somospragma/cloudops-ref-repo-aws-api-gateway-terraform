# Ejemplo de Uso del Módulo API Gateway

Este ejemplo demuestra cómo usar el módulo de API Gateway con:
- API Key + Cognito en el mismo endpoint
- Múltiples rutas con diferentes configuraciones de autenticación
- Usage Plans con throttling y quotas

## Requisitos Previos

1. Cognito User Pool existente
2. Lambda Functions existentes (auth, sync, webhook)
3. Rol IAM para despliegue

## Configuración de Seguridad por Endpoint

| Endpoint | API Key | Cognito | Descripción |
|----------|---------|---------|-------------|
| `/auth/login` | ✅ | ❌ | Login sin token Cognito |
| `/auth/refresh` | ✅ | ❌ | Refresh sin token Cognito |
| `/health` | ✅ | ❌ | Health check público |
| `/webhook/github` | ✅ | ❌ | Webhook externo |
| `/accounts` | ✅ | ✅ | Requiere ambos |
| `/sync` | ✅ | ✅ | Requiere ambos |
| `/taxonomy` | ✅ | ✅ | Requiere ambos |
| `/config` | ✅ | ✅ | Requiere ambos |

## Uso

1. Configurar las variables en `terraform.tfvars`
2. Inicializar Terraform:
   ```bash
   terraform init
   ```
3. Planificar:
   ```bash
   terraform plan
   ```
4. Aplicar:
   ```bash
   terraform apply
   ```

## Outputs

- `api_invoke_url`: URL base de la API
- `api_key_value`: Valor de la API Key (sensible)
- `authorizer_id`: ID del authorizer Cognito

## Ejemplo de Llamada

```bash
# Endpoint solo con API Key
curl -H "x-api-key: YOUR_API_KEY" \
  https://xxx.execute-api.us-east-1.amazonaws.com/v1/health

# Endpoint con API Key + Cognito
curl -H "x-api-key: YOUR_API_KEY" \
     -H "Authorization: Bearer YOUR_COGNITO_TOKEN" \
  https://xxx.execute-api.us-east-1.amazonaws.com/v1/accounts
```
