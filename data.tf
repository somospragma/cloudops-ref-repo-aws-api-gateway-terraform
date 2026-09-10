############################################################################
# Data Sources (PC-IAC-011)
############################################################################

# Obtener información de la región actual
data "aws_region" "current" {
  provider = aws.project
}

# Obtener información de la cuenta actual
data "aws_caller_identity" "current" {
  provider = aws.project
}
