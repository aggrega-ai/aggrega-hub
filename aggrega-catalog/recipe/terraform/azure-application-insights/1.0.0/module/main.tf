# required_providers pins hashicorp/azurerm so the engine installs a provider
# whose resource schema this module was written against. It is a range rather
# than an exact version because every Azure module in one root configuration
# shares one installed provider, and two exact pins that differ fail init. The
# constraint string is the one the Aggrega catalog conventions' "One Azure
# provider constraint for every Azure body" section states; this file repeats
# it deliberately, because a vendored module is copied byte for byte and imports
# nothing.
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.14"
    }
  }
}

# One workspace-based Application Insights component, and nothing else: no
# Log Analytics workspace, role assignment, private link scope, diagnostic
# setting or resource group, each of which belongs to the operator.
#
# The component stores its telemetry in the operator's workspace that
# workspace_id names, and the service masks the client IP address of the
# telemetry it ingests rather than storing it. The provider writes the
# component's kind as its application type.
resource "azurerm_application_insights" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  workspace_id                 = var.workspace_id
  application_type             = var.application_type
  sampling_percentage          = var.sampling_percentage
  local_authentication_enabled = var.local_authentication_enabled
  ip_masking_enabled           = true
  retention_in_days            = 90
  tags                         = var.tags
}

# The component's connection string, as the service reports it. The provider
# marks the attribute sensitive, so Terraform requires the output to be
# marked sensitive too.
output "connection_string" {
  value     = azurerm_application_insights.this.connection_string
  sensitive = true
}
