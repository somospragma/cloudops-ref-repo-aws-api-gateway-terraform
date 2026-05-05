############################################################################
# Data Sources del Consumidor
############################################################################

# Información de la cuenta actual
data "aws_caller_identity" "current" {}

# Información de la región actual
data "aws_region" "current" {}
