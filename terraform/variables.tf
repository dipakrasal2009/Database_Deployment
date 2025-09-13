# variable "whitebox_subscription_id" {
#   description = "The subscription ID where resources will be deployed."
#   type        = string
# }

# # variable "whitebox_aad_tenant" {
# #   description = "The Azure Active Directory Tenant ID which should be used. This can also be sourced from the ARM_TENANT_ID or AZURE_TENANT_ID Environment Variables."
# #   type        = string
# # }

# variable "whitebox_client_id" {
#   description = "The Client ID which should be used. This can also be sourced from the ARM_CLIENT_ID or AZURE_CLIENT_ID Environment Variables."
#   type        = string
# }

# variable "whitebox_client_secret" {
#   description = "The Client Secret which should be used. For use when authenticating as a Service Principal using a Client Secret. This can also be sourced from the ARM_CLIENT_SECRET or AZURE_CLIENT_SECRET Environment Variables."
#   type        = string
#   sensitive   = true
# }

variable "tags" {
  description = "A map of tags to apply to the resources."
  type        = map(string)
  default = {
    "Owner "    = "Globallogic"
    project     = "velocityai"
    environment = "whitebox"
  }
}

# variable "devops_agents_subnet_name" {
#   description = "The name of the subnet where Azure DevOps agents will be deployed."
#   type        = string
#   default     = "devops_agents_subnet"
# }

# variable "whitebox_resource_group_name" {
#   description = "The name of the resource group where whitebox resources will be deployed."
#   type        = string
# }

# variable "whitebox_arc_name" {
#   description = "The name of the Azure Container Registry where whitebox images will be stored."
#   type        = string
# }

# variable "whitebox_vnet_name" {
#   description = "The name of the virtual network where whitebox resources will be deployed."
#   type        = string
# }

# variable "whitebox_aks_name" {
#   description = "The name of the Azure Kubernetes Service cluster where whitebox services will be deployed."
#   type        = string
# }

# variable "whitebox_aks_private_fqdn" {
#   description = "The private FQDN of the Azure Kubernetes Service cluster where whitebox services will be deployed."
#   type        = string
# }

variable "infrastructure" {
  description = "List of infrastructure names for which separate resources will be created."
  type        = list(string)
  default     = [] // e.g. ["postgresql"] if you want to install PostgreSQL
}

# variable "client_storage_account_conn_str" {
#   description = "The connection string for the client storage account."
#   type        = string
# }

# variable "report_blob_container_name" {
#   description = "The name of the blob container where the report will be uploaded."
#   type        = string
#   default     = "reports"
# }

# variable "applicationinsights_connection_string" {
#   description = "The connection string for the Application Insights instance."
#   type        = string
# }

variable "create_namespace" {
  description = "Create namespace even if var.infrasctruture is empty. If infrasctruture is not empty and this variable is set to false namespace will be created anyway"
  type        = bool
  default     = "true"
}

#############################
# Target OpenShift project/namespace
#############################
variable "openshift_project_name" {
  description = "Target OpenShift namespace/project where resources will be deployed"
  type        = string
  default     = "devops-openshift"
}

# variable "postgresql_database" {
#   description = "Default database name for PostgreSQL"
#   type        = string
#   default     = "mydatabase"
# }

# #############################
# # Persistent storage settings
# #############################
# variable "persistence_storage_class" {
#   description = "Storage class to use for PostgreSQL persistence"
#   type        = string
#   default     = "managed-csi"
# }

variable "persistence_storage_size" {
  description = "Persistent volume size for PostgreSQL"
  type        = string
  default     = "5Gi"
}
