############################################################################
# Data Sources del Ejemplo (PC-IAC-011)
############################################################################

# Cognito User Pool
data "aws_cognito_user_pools" "main" {
  provider = aws.principal
  name     = var.cognito_user_pool_name
}

# Lambda Functions
data "aws_lambda_function" "auth" {
  provider      = aws.principal
  function_name = var.lambda_auth_name
}

data "aws_lambda_function" "sync" {
  provider      = aws.principal
  function_name = var.lambda_sync_name
}

data "aws_lambda_function" "webhook" {
  provider      = aws.principal
  function_name = var.lambda_webhook_name
}
