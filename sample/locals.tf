############################################################################
# Locals del Ejemplo (PC-IAC-012)
############################################################################

locals {
  # Prefijo de gobernanza para referencia
  governance_prefix = "${var.client}-${var.project}-${var.environment}"
}
