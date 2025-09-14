# Target OpenShift project/namespace
variable "openshift_project_name" {
  type        = string
  description = "Namespace to deploy Helm charts"
}

# List of infrastructure components to deploy
variable "infrastructure" {
  type        = list(string)
  description = "List of infrastructure components to deploy"
  default     = []
}

# PostgreSQL configuration
variable "postgresql_username" {
  type        = string
  description = "PostgreSQL username"
}

variable "postgresql_database" {
  type        = string
  description = "PostgreSQL database name"
}

# Persistent storage settings
variable "persistence_storage_class" {
  type        = string
  description = "StorageClass for persistent volumes"
}

variable "persistence_storage_size" {
  type        = string
  description = "Storage size for persistent volumes"
}

