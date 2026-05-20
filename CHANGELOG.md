# Changelog

Todos los cambios notables en este módulo serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-05-19

### Added
- Versión inicial del módulo API Gateway con Terraform nativo (sin OpenAPI)
- Soporte para combinar `api_key_required = true` con `authorization = COGNITO_USER_POOLS` en el mismo endpoint
- Recursos nativos de Terraform: `aws_api_gateway_resource`, `aws_api_gateway_method`, `aws_api_gateway_integration`
- Authorizers configurables por API (Cognito y Lambda)
- API Keys y Usage Plans con throttling y quotas
- CORS configurable global y por ruta
- Integraciones soportadas: LAMBDA, VPC_LINK, MOCK, HTTP
- Custom Domain con certificados ACM
- VPC Link (crear nuevo o usar existente)
- Cumplimiento completo de reglas PC-IAC (001-026)

### Características principales
- **Autenticación mixta por ruta**: Cada ruta puede tener configuración independiente de `authorization` y `api_key_required`
- **for_each obligatorio**: Uso de `map(object)` para todas las colecciones (PC-IAC-010)
- **Nomenclatura estándar**: `{client}-{project}-{environment}-{type}-{key}` (PC-IAC-003)
- **Provider alias**: Todos los recursos usan `aws.project` (PC-IAC-005)
