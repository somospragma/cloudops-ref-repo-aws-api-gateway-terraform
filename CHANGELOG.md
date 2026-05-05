# Changelog

Todos los cambios notables de este módulo serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-XX-XX

### Added

- Creación inicial del módulo API Gateway v2
- Soporte para múltiples APIs mediante `api_config` map
- Integración Lambda Proxy usando OpenAPI 3.0 spec
- Soporte para endpoints REGIONAL, EDGE y PRIVATE
- Configuración de X-Ray tracing
- Configuración de access logs con formato personalizable
- Soporte para compresión de respuestas
- Soporte para binary media types
- Dominios personalizados con certificados ACM
- Base path mapping para dominios personalizados
- Permisos Lambda automáticos para API Gateway
- Outputs granulares y consolidados
- Documentación completa en README.md
- Ejemplo de uso en directorio sample/

### Compliance

- PC-IAC-001: Estructura de 18 archivos
- PC-IAC-002: Variables de gobernanza (client, project, environment)
- PC-IAC-003: Nomenclatura estándar
- PC-IAC-004: Tags comunes
- PC-IAC-005: Provider alias aws.project
- PC-IAC-006: Versiones de Terraform y providers
- PC-IAC-009: Variable de configuración tipo map(object)
- PC-IAC-010: Outputs granulares
- PC-IAC-011: Data sources documentados
- PC-IAC-023: Responsabilidad única (solo API Gateway)
- PC-IAC-026: Patrón de transformación en sample/
