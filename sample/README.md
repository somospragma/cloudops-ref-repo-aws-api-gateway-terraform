# Sample - API Gateway Module

Este directorio contiene un ejemplo completo de cómo consumir el módulo `cloudops-ref-repo-aws-api-terraform-v2`.

## Estructura

```
sample/
├── README.md           # Este archivo
├── data.tf             # Data sources del consumidor
├── locals.tf           # Transformación de variables a api_config
├── main.tf             # Invocación del módulo
├── outputs.tf          # Outputs del consumidor
├── providers.tf        # Configuración de providers
├── terraform.tfvars    # Valores de ejemplo
└── variables.tf        # Variables del consumidor
```

## Patrón de Transformación (PC-IAC-026)

El consumidor define sus APIs en un formato simple y `locals.tf` las transforma al formato `api_config` que espera el módulo:

```hcl
# variables.tf - Formato simple del consumidor
variable "apis" {
  type = map(object({
    lambda_key  = string
    description = optional(string, "")
  }))
}

# locals.tf - Transformación
locals {
  api_config = {
    for key, api in var.apis : key => {
      lambda_arn  = var.lambda_arns[api.lambda_key]
      description = api.description
    }
  }
}

# main.tf - Invocación
module "api" {
  source     = "../"
  api_config = local.api_config
}
```

## Uso

```bash
cd sample/
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

## Requisitos

- Terraform >= 1.0.0
- AWS Provider >= 5.0.0
- Lambda(s) ya desplegada(s) con sus ARNs disponibles
